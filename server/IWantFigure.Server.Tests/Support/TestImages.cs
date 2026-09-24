using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Gif;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Metadata.Profiles.Exif;
using SixLabors.ImageSharp.PixelFormats;

namespace IWantFigure.Server.Tests.Support;

/// <summary>Generates small test images in memory so the tests never touch the file system or the network.</summary>
public static class TestImages
{
    public static byte[] Jpeg(int width, int height, ushort? exifOrientation = null)
    {
        using var image = new Image<Rgb24>(width, height, new Rgb24(80, 120, 200));
        if (exifOrientation is ushort orientation)
        {
            var exif = new ExifProfile();
            exif.SetValue(ExifTag.Orientation, orientation);
            image.Metadata.ExifProfile = exif;
        }
        using var ms = new MemoryStream();
        image.SaveAsJpeg(ms, new JpegEncoder { Quality = 90 });
        return ms.ToArray();
    }

    public static byte[] Png(int width, int height)
    {
        using var image = new Image<Rgba32>(width, height, new Rgba32(200, 40, 40, 255));
        using var ms = new MemoryStream();
        image.SaveAsPng(ms, new PngEncoder());
        return ms.ToArray();
    }

    public static byte[] Gif(int width, int height)
    {
        using var image = new Image<Rgba32>(width, height, new Rgba32(10, 200, 10, 255));
        using var ms = new MemoryStream();
        image.SaveAsGif(ms, new GifEncoder());
        return ms.ToArray();
    }
}
