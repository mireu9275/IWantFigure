using IWantFigure.Server.Configuration;
using Microsoft.Extensions.Options;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Processing;

namespace IWantFigure.Server.Imaging;

/// <summary>The image as it is sent to the model. The normalized coordinates refer to Width x Height.</summary>
public sealed record PreparedImage(byte[] Bytes, string Mime, int Width, int Height)
{
    public string ToBase64() => Convert.ToBase64String(Bytes);
}

/// <summary>The client sent something we refuse to process. Mapped to HTTP 400.</summary>
public sealed class InvalidImageException : Exception
{
    public InvalidImageException(string code, string message, Exception? inner = null) : base(message, inner)
    {
        Code = code;
    }

    /// <summary>Machine-readable code returned in the "error" field.</summary>
    public string Code { get; }
}

/// <summary>
/// decode -> apply EXIF orientation -> downscale (long side &lt;= MaxImageLongSide, never upscale)
/// -> strip metadata -> JPEG quality 85.
///
/// Memory safety: the header is inspected first (cheap, no pixel buffers) and images over the
/// per-format pixel budget are rejected before decoding. Only JPEG can be decoded at reduced
/// resolution; PNG/WebP are always decoded in full (4 bytes/pixel), so they get a smaller
/// budget. A semaphore bounds how many decodes run at once. Thread-safe; register as a singleton.
/// </summary>
public sealed class ImagePipeline
{
    private const string JpegFormatName = "JPEG";

    // IImageFormat.Name values used by ImageSharp's built-in decoders.
    private static readonly HashSet<string> AllowedFormats = new(StringComparer.OrdinalIgnoreCase) { JpegFormatName, "PNG", "WEBP" };

    private readonly AnalysisOptions _options;
    private readonly SemaphoreSlim _decodeGate;

    public ImagePipeline(IOptions<AnalysisOptions> options)
    {
        _options = options.Value;
        int slots = Math.Max(1, _options.MaxConcurrentDecodes);
        _decodeGate = new SemaphoreSlim(slots, slots);
    }

    /// <summary>Number of decodes that may run concurrently (for diagnostics/tests).</summary>
    public int MaxConcurrentDecodes => Math.Max(1, _options.MaxConcurrentDecodes);

    /// <summary>
    /// Validates and prepares the image. Waits for a decode slot when <see cref="AnalysisOptions.MaxConcurrentDecodes"/>
    /// images are already in flight; the wait is cancelled with <paramref name="ct"/>.
    /// </summary>
    public async Task<PreparedImage> PrepareAsync(byte[] source, CancellationToken ct)
    {
        if (source is null || source.Length == 0)
        {
            throw new InvalidImageException("missing_image", "image data is empty");
        }

        // 1) Header-only checks: format, dimensions, pixel budget. No pixel buffers yet.
        (IImageFormat format, ImageInfo info) = Inspect(source);

        await _decodeGate.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            return DecodeAndEncode(source, format, info);
        }
        finally
        {
            _decodeGate.Release();
        }
    }

    /// <summary>Pixel budget for a format: JPEG can be decoded downscaled, everything else cannot.</summary>
    internal long PixelBudgetFor(IImageFormat format) =>
        format.Name.Equals(JpegFormatName, StringComparison.OrdinalIgnoreCase) ? _options.MaxImagePixels : _options.MaxImagePixelsNonJpeg;

    private (IImageFormat Format, ImageInfo Info) Inspect(byte[] source)
    {
        try
        {
            IImageFormat format = Image.DetectFormat(source);
            if (!AllowedFormats.Contains(format.Name))
            {
                throw new InvalidImageException("unsupported_image_format", $"image format '{format.Name}' is not supported; send JPEG, PNG or WebP");
            }

            ImageInfo info = Image.Identify(source);
            long pixels = (long)info.Width * info.Height;
            long budget = PixelBudgetFor(format);
            if (pixels > budget)
            {
                throw new InvalidImageException("image_too_large", $"{format.Name} image has {info.Width}x{info.Height} pixels, limit for this format is {budget}");
            }

            return (format, info);
        }
        catch (ImageFormatException ex)
        {
            // UnknownImageFormatException (not an image) and InvalidImageContentException (truncated/corrupt).
            throw new InvalidImageException("invalid_image", "the data is not a decodable JPEG/PNG/WebP image", ex);
        }
    }

    private PreparedImage DecodeAndEncode(byte[] source, IImageFormat format, ImageInfo info)
    {
        int maxSide = Math.Max(64, _options.MaxImageLongSide);

        try
        {
            // 2) Decode. For photos larger than the bound, TargetSize lets ImageSharp decode at a
            //    reduced resolution (the JPEG decoder skips IDCT work) - much cheaper than decoding
            //    12 MP and shrinking afterwards. It is a decode+resize, so it must NOT be set for
            //    small images (it would upscale them). The explicit Resize below still guarantees
            //    the exact bound.
            bool needsDownscale = Math.Max(info.Width, info.Height) > maxSide;
            var decoderOptions = new DecoderOptions
            {
                TargetSize = needsDownscale ? new Size(maxSide, maxSide) : null,
                MaxFrames = 1,
            };
            using Image image = Image.Load(decoderOptions, source);

            // 3) Bake the EXIF orientation into the pixels so the model and the app agree on "up".
            image.Mutate(ctx =>
            {
                ctx.AutoOrient();
                // PNG/WebP may carry alpha; JPEG cannot. Flatten on white instead of leaving black holes.
                ctx.BackgroundColor(Color.White);
            });

            // 4) Downscale only when needed - upscaling adds tokens without adding information.
            if (Math.Max(image.Width, image.Height) > maxSide)
            {
                image.Mutate(ctx => ctx.Resize(new ResizeOptions
                {
                    Mode = ResizeMode.Max,
                    Size = new Size(maxSide, maxSide),
                    Sampler = KnownResamplers.Lanczos3,
                }));
            }

            // 5) Strip every metadata block: privacy (GPS in EXIF) and payload size.
            image.Metadata.ExifProfile = null;
            image.Metadata.XmpProfile = null;
            image.Metadata.IptcProfile = null;
            image.Metadata.IccProfile = null;

            // 6) Re-encode as JPEG. Quality 85 is visually lossless for the model at a fraction of the bytes.
            var encoder = new JpegEncoder
            {
                Quality = Math.Clamp(_options.JpegQuality, 40, 100),
                SkipMetadata = true,
            };
            using var output = new MemoryStream();
            image.SaveAsJpeg(output, encoder);

            return new PreparedImage(output.ToArray(), "image/jpeg", image.Width, image.Height);
        }
        catch (ImageFormatException ex)
        {
            throw new InvalidImageException("invalid_image", $"the {format.Name} data is corrupt or truncated", ex);
        }
    }
}
