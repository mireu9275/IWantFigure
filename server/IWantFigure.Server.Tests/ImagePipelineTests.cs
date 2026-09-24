using System.Text;
using IWantFigure.Server.Configuration;
using IWantFigure.Server.Imaging;
using IWantFigure.Server.Tests.Support;
using Microsoft.Extensions.Options;
using SixLabors.ImageSharp;

namespace IWantFigure.Server.Tests;

public class ImagePipelineTests
{
    private static ImagePipeline Pipeline(int maxSide = 1456, long maxPixels = 50_000_000) =>
        new(Options.Create(new AnalysisOptions { MaxImageLongSide = maxSide, JpegQuality = 85, MaxImagePixels = maxPixels }));

    [Fact]
    public void Landscape_3000x2000_is_resized_to_long_side_1456()
    {
        PreparedImage result = Pipeline().Prepare(TestImages.Jpeg(3000, 2000));

        Assert.Equal(1456, result.Width);
        Assert.Equal(971, result.Height); // 2000 * 1456 / 3000 = 970.67 -> 971
        Assert.Equal("image/jpeg", result.Mime);

        ImageInfo info = Image.Identify(result.Bytes);
        Assert.Equal(1456, info.Width);
        Assert.Equal(971, info.Height);
        Assert.Equal("JPEG", info.Metadata.DecodedImageFormat?.Name);
    }

    [Fact]
    public void Portrait_2000x3000_is_resized_to_971x1456()
    {
        PreparedImage result = Pipeline().Prepare(TestImages.Jpeg(2000, 3000));

        Assert.Equal(971, result.Width);
        Assert.Equal(1456, result.Height);
    }

    [Fact]
    public void Small_images_are_never_upscaled()
    {
        PreparedImage result = Pipeline().Prepare(TestImages.Jpeg(640, 480));

        Assert.Equal(640, result.Width);
        Assert.Equal(480, result.Height);
    }

    [Fact]
    public void Exif_orientation_is_applied_and_metadata_is_stripped()
    {
        // Orientation 6 = "rotate 90° CW to display": a 3000x2000 sensor image is really portrait.
        byte[] source = TestImages.Jpeg(3000, 2000, exifOrientation: 6);
        Assert.NotNull(Image.Identify(source).Metadata.ExifProfile); // precondition

        PreparedImage result = Pipeline().Prepare(source);

        Assert.Equal(971, result.Width);
        Assert.Equal(1456, result.Height);
        Assert.Null(Image.Identify(result.Bytes).Metadata.ExifProfile);
    }

    [Fact]
    public void Png_input_is_reencoded_as_jpeg()
    {
        PreparedImage result = Pipeline().Prepare(TestImages.Png(800, 600));

        Assert.Equal("image/jpeg", result.Mime);
        Assert.Equal(800, result.Width);
        Assert.Equal(600, result.Height);
        Assert.Equal("JPEG", Image.Identify(result.Bytes).Metadata.DecodedImageFormat?.Name);
    }

    [Fact]
    public void Non_image_bytes_are_rejected_with_invalid_image()
    {
        var ex = Assert.Throws<InvalidImageException>(() => Pipeline().Prepare(Encoding.UTF8.GetBytes("definitely not a picture")));

        Assert.Equal("invalid_image", ex.Code);
    }

    [Fact]
    public void Gif_is_rejected_as_unsupported_format()
    {
        var ex = Assert.Throws<InvalidImageException>(() => Pipeline().Prepare(TestImages.Gif(50, 50)));

        Assert.Equal("unsupported_image_format", ex.Code);
    }

    [Fact]
    public void Images_over_the_pixel_budget_are_rejected_before_decoding()
    {
        var ex = Assert.Throws<InvalidImageException>(() => Pipeline(maxPixels: 1000).Prepare(TestImages.Jpeg(100, 100)));

        Assert.Equal("image_too_large", ex.Code);
    }

    [Fact]
    public void Max_long_side_is_configurable()
    {
        PreparedImage result = Pipeline(maxSide: 512).Prepare(TestImages.Jpeg(3000, 2000));

        Assert.Equal(512, result.Width);
        Assert.Equal(341, result.Height);
    }
}
