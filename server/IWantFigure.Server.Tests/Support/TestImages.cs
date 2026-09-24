using System.Buffers.Binary;
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
    public static byte[] Jpeg(int width, int height, ushort? exifOrientation = null, int quality = 90)
    {
        using var image = new Image<Rgb24>(width, height, new Rgb24(80, 120, 200));
        if (exifOrientation is ushort orientation)
        {
            var exif = new ExifProfile();
            exif.SetValue(ExifTag.Orientation, orientation);
            image.Metadata.ExifProfile = exif;
        }
        using var ms = new MemoryStream();
        image.SaveAsJpeg(ms, new JpegEncoder { Quality = quality });
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

    /// <summary>
    /// A syntactically valid PNG that declares width x height in its IHDR but carries no pixel data.
    /// Enough for Image.DetectFormat / Image.Identify (header-only), which is exactly what the
    /// pixel-budget guard must rely on - the server must reject it before ever decoding.
    /// </summary>
    public static byte[] PngHeaderOnly(int width, int height)
    {
        using var ms = new MemoryStream();
        ms.Write(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A });

        var ihdr = new byte[13];
        BinaryPrimitives.WriteInt32BigEndian(ihdr.AsSpan(0, 4), width);
        BinaryPrimitives.WriteInt32BigEndian(ihdr.AsSpan(4, 4), height);
        ihdr[8] = 8;  // bit depth
        ihdr[9] = 2;  // colour type: truecolour
        WriteChunk(ms, "IHDR", ihdr);
        WriteChunk(ms, "IEND", Array.Empty<byte>());
        return ms.ToArray();
    }

    private static void WriteChunk(Stream stream, string type, byte[] data)
    {
        byte[] typeBytes = System.Text.Encoding.ASCII.GetBytes(type);
        Span<byte> length = stackalloc byte[4];
        BinaryPrimitives.WriteInt32BigEndian(length, data.Length);
        stream.Write(length);
        stream.Write(typeBytes);
        stream.Write(data);
        Span<byte> crc = stackalloc byte[4];
        BinaryPrimitives.WriteUInt32BigEndian(crc, Crc32(typeBytes, data));
        stream.Write(crc);
    }

    /// <summary>Standard PNG CRC-32 (polynomial 0xEDB88320) over chunk type + data.</summary>
    private static uint Crc32(byte[] first, byte[] second)
    {
        uint crc = 0xFFFFFFFF;
        foreach (byte b in first.Concat(second))
        {
            crc ^= b;
            for (int i = 0; i < 8; i++)
            {
                crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
            }
        }
        return crc ^ 0xFFFFFFFF;
    }
}
