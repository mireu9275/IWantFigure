using System.Text;
using IWantFigure.Server.Configuration;
using IWantFigure.Server.Imaging;
using IWantFigure.Server.Tests.Support;
using Microsoft.Extensions.Options;
using SixLabors.ImageSharp;

namespace IWantFigure.Server.Tests;

public class ImagePipelineTests
{
    private static ImagePipeline Pipeline(int maxSide = 1456, long maxPixels = 50_000_000, long maxPixelsNonJpeg = 16_000_000, int concurrency = 4) =>
        new(Options.Create(new AnalysisOptions
        {
            MaxImageLongSide = maxSide,
            JpegQuality = 85,
            MaxImagePixels = maxPixels,
            MaxImagePixelsNonJpeg = maxPixelsNonJpeg,
            MaxConcurrentDecodes = concurrency,
        }));

    private static Task<PreparedImage> Prepare(ImagePipeline pipeline, byte[] bytes) => pipeline.PrepareAsync(bytes, CancellationToken.None);

    [Fact]
    public async Task Landscape_3000x2000_is_resized_to_long_side_1456()
    {
        PreparedImage result = await Prepare(Pipeline(), TestImages.Jpeg(3000, 2000));

        Assert.Equal(1456, result.Width);
        Assert.Equal(971, result.Height); // 2000 * 1456 / 3000 = 970.67 -> 971
        Assert.Equal("image/jpeg", result.Mime);

        ImageInfo info = Image.Identify(result.Bytes);
        Assert.Equal(1456, info.Width);
        Assert.Equal(971, info.Height);
        Assert.Equal("JPEG", info.Metadata.DecodedImageFormat?.Name);
    }

    [Fact]
    public async Task Portrait_2000x3000_is_resized_to_971x1456()
    {
        PreparedImage result = await Prepare(Pipeline(), TestImages.Jpeg(2000, 3000));

        Assert.Equal(971, result.Width);
        Assert.Equal(1456, result.Height);
    }

    [Fact]
    public async Task Small_images_are_never_upscaled()
    {
        PreparedImage result = await Prepare(Pipeline(), TestImages.Jpeg(640, 480));

        Assert.Equal(640, result.Width);
        Assert.Equal(480, result.Height);
    }

    [Fact]
    public async Task Exif_orientation_is_applied_and_metadata_is_stripped()
    {
        // Orientation 6 = "rotate 90° CW to display": a 3000x2000 sensor image is really portrait.
        byte[] source = TestImages.Jpeg(3000, 2000, exifOrientation: 6);
        Assert.NotNull(Image.Identify(source).Metadata.ExifProfile); // precondition

        PreparedImage result = await Prepare(Pipeline(), source);

        Assert.Equal(971, result.Width);
        Assert.Equal(1456, result.Height);
        Assert.Null(Image.Identify(result.Bytes).Metadata.ExifProfile);
    }

    [Fact]
    public async Task Png_input_is_reencoded_as_jpeg()
    {
        PreparedImage result = await Prepare(Pipeline(), TestImages.Png(800, 600));

        Assert.Equal("image/jpeg", result.Mime);
        Assert.Equal(800, result.Width);
        Assert.Equal(600, result.Height);
        Assert.Equal("JPEG", Image.Identify(result.Bytes).Metadata.DecodedImageFormat?.Name);
    }

    [Fact]
    public async Task Non_image_bytes_are_rejected_with_invalid_image()
    {
        var ex = await Assert.ThrowsAsync<InvalidImageException>(() => Prepare(Pipeline(), Encoding.UTF8.GetBytes("definitely not a picture")));

        Assert.Equal("invalid_image", ex.Code);
    }

    [Fact]
    public async Task Gif_is_rejected_as_unsupported_format()
    {
        var ex = await Assert.ThrowsAsync<InvalidImageException>(() => Prepare(Pipeline(), TestImages.Gif(50, 50)));

        Assert.Equal("unsupported_image_format", ex.Code);
    }

    [Fact]
    public async Task Images_over_the_pixel_budget_are_rejected_before_decoding()
    {
        var ex = await Assert.ThrowsAsync<InvalidImageException>(() => Prepare(Pipeline(maxPixels: 1000), TestImages.Jpeg(100, 100)));

        Assert.Equal("image_too_large", ex.Code);
    }

    [Fact]
    public async Task Png_7000x7000_is_rejected_by_the_non_jpeg_budget_without_decoding()
    {
        // 49 MP is under the JPEG budget (50 MP) but far over the PNG budget (16 MP). The bytes carry
        // no pixel data at all, so the only way to get image_too_large is the header check.
        byte[] headerOnly = TestImages.PngHeaderOnly(7000, 7000);
        Assert.True(headerOnly.Length < 100);

        var ex = await Assert.ThrowsAsync<InvalidImageException>(() => Prepare(Pipeline(), headerOnly));

        Assert.Equal("image_too_large", ex.Code);
        Assert.Contains("PNG", ex.Message);
        Assert.Contains("16000000", ex.Message);
    }

    [Fact]
    public async Task Jpeg_at_40_megapixels_is_still_accepted_and_downscaled()
    {
        byte[] big = TestImages.Jpeg(8000, 5000, quality: 60); // 40 MP, generated in memory

        PreparedImage result = await Prepare(Pipeline(), big);

        Assert.Equal(1456, result.Width);
        Assert.Equal(910, result.Height); // 5000 * 1456 / 8000
    }

    [Fact]
    public async Task Png_under_the_non_jpeg_budget_is_accepted()
    {
        PreparedImage result = await Prepare(Pipeline(maxPixelsNonJpeg: 2_000_000), TestImages.Png(1600, 1200));

        Assert.Equal(1456, result.Width);
        Assert.Equal(1092, result.Height);
    }

    [Fact]
    public async Task Max_long_side_is_configurable()
    {
        PreparedImage result = await Prepare(Pipeline(maxSide: 512), TestImages.Jpeg(3000, 2000));

        Assert.Equal(512, result.Width);
        Assert.Equal(341, result.Height);
    }

    [Fact]
    public async Task Concurrent_decodes_are_bounded_but_all_complete()
    {
        ImagePipeline pipeline = Pipeline(concurrency: 2);
        byte[] source = TestImages.Jpeg(2000, 1500);

        PreparedImage[] results = await Task.WhenAll(Enumerable.Range(0, 6).Select(_ => Prepare(pipeline, source)));

        Assert.Equal(2, pipeline.MaxConcurrentDecodes);
        Assert.All(results, r => Assert.Equal(1456, r.Width));
    }

    [Fact]
    public async Task Waiting_for_a_decode_slot_honours_cancellation()
    {
        using var cts = new CancellationTokenSource();
        cts.Cancel();

        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => Pipeline().PrepareAsync(TestImages.Jpeg(64, 64), cts.Token));
    }
}
