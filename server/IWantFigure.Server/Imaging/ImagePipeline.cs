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
/// -> strip metadata -> JPEG quality 85. Thread-safe; register as a singleton.
/// </summary>
public sealed class ImagePipeline
{
    // IImageFormat.Name values used by ImageSharp's built-in decoders.
    private static readonly HashSet<string> AllowedFormats = new(StringComparer.OrdinalIgnoreCase) { "JPEG", "PNG", "WEBP" };

    private readonly AnalysisOptions _options;

    public ImagePipeline(IOptions<AnalysisOptions> options)
    {
        _options = options.Value;
    }

    public PreparedImage Prepare(byte[] source)
    {
        if (source is null || source.Length == 0)
        {
            throw new InvalidImageException("missing_image", "image data is empty");
        }

        int maxSide = Math.Max(64, _options.MaxImageLongSide);

        try
        {
            // 1) Cheap header-only checks before allocating pixel buffers.
            IImageFormat format = Image.DetectFormat(source);
            if (!AllowedFormats.Contains(format.Name))
            {
                throw new InvalidImageException("unsupported_image_format", $"image format '{format.Name}' is not supported; send JPEG, PNG or WebP");
            }

            ImageInfo info = Image.Identify(source);
            if ((long)info.Width * info.Height > _options.MaxImagePixels)
            {
                throw new InvalidImageException("image_too_large", $"image has {info.Width}x{info.Height} pixels, limit is {_options.MaxImagePixels}");
            }

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
            // UnknownImageFormatException (not an image) and InvalidImageContentException (truncated/corrupt).
            throw new InvalidImageException("invalid_image", "the data is not a decodable JPEG/PNG/WebP image", ex);
        }
    }
}
