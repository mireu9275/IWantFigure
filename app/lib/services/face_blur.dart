/// On-device face anonymisation applied before a photo leaves the phone.
///
/// Arcades are crowded and other customers' faces are personal data (Japanese
/// APPI, GiGO's photo rules). The photo is passed through a
/// [FaceRegionDetector] (ML Kit on device, see `mlkit_face_detector.dart`) and
/// every detected face is pixelated by [FaceBlurrer] with pure Dart code, so
/// the bytes that are uploaded, displayed and stored never contain a
/// recognisable face.
library;

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Axis-aligned rectangle in normalized image coordinates (0..1, origin
/// top-left).
class NormRect {
  const NormRect(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  double get width => x2 - x1;
  double get height => y2 - y1;

  /// Grows the rectangle by [fraction] of its size on every side and clamps
  /// it to the image.
  NormRect padded(double fraction) {
    final dx = width * fraction;
    final dy = height * fraction;
    return NormRect(
      (x1 - dx).clamp(0.0, 1.0),
      (y1 - dy).clamp(0.0, 1.0),
      (x2 + dx).clamp(0.0, 1.0),
      (y2 + dy).clamp(0.0, 1.0),
    );
  }

  Map<String, dynamic> toJson() => {'x1': x1, 'y1': y1, 'x2': x2, 'y2': y2};

  @override
  String toString() =>
      'NormRect(${x1.toStringAsFixed(3)}, ${y1.toStringAsFixed(3)}, ${x2.toStringAsFixed(3)}, ${y2.toStringAsFixed(3)})';
}

/// Finds faces in a photo. Implementations must run entirely on the device.
abstract class FaceRegionDetector {
  /// Returns the faces found in the image as normalized rectangles.
  /// [path] is the file the bytes came from, when known (some detectors read
  /// files directly).
  Future<List<NormRect>> detectFaces(
    Uint8List imageBytes, {
    required int width,
    required int height,
    String? path,
  });
}

/// Detector that never finds faces (tests, or when the user disabled the
/// feature).
class NoopFaceRegionDetector implements FaceRegionDetector {
  const NoopFaceRegionDetector();

  @override
  Future<List<NormRect>> detectFaces(
    Uint8List imageBytes, {
    required int width,
    required int height,
    String? path,
  }) async =>
      const [];
}

/// Result of [FaceBlurrer.apply].
class FaceBlurResult {
  const FaceBlurResult({
    required this.bytes,
    required this.faceCount,
    required this.width,
    required this.height,
    required this.changed,
  });

  /// JPEG bytes to use from now on (identical to the input when nothing was
  /// blurred).
  final Uint8List bytes;
  final int faceCount;
  final int width;
  final int height;

  /// True when the bytes were re-encoded.
  final bool changed;
}

/// Pixelates rectangular regions of a JPEG/PNG image. Pure Dart, no platform
/// code, so it is unit-testable and can run in a background isolate.
class FaceBlurrer {
  const FaceBlurrer({
    this.padding = 0.3,
    this.jpegQuality = 88,
    this.minBlockPx = 10,
    this.blocksAcross = 6,
  });

  /// Extra margin around each detected face (fraction of its size) so hair,
  /// ears and detector jitter are covered too.
  final double padding;
  final int jpegQuality;

  /// Smallest mosaic block; larger blocks = stronger anonymisation.
  final int minBlockPx;

  /// Number of mosaic blocks across the shorter side of a face box.
  final int blocksAcross;

  /// Returns the input untouched when [faces] is empty or the image cannot
  /// be decoded; otherwise a re-encoded JPEG with every face pixelated.
  FaceBlurResult apply(
    Uint8List bytes,
    List<NormRect> faces, {
    int width = 0,
    int height = 0,
  }) {
    if (faces.isEmpty) {
      return FaceBlurResult(bytes: bytes, faceCount: 0, width: width, height: height, changed: false);
    }
    var image = img.decodeImage(bytes);
    if (image == null) {
      return FaceBlurResult(bytes: bytes, faceCount: 0, width: width, height: height, changed: false);
    }
    image = img.bakeOrientation(image);
    var blurred = 0;
    for (final face in faces) {
      final r = face.padded(padding);
      final x1 = (r.x1 * image.width).floor().clamp(0, image.width);
      final y1 = (r.y1 * image.height).floor().clamp(0, image.height);
      final x2 = (r.x2 * image.width).ceil().clamp(0, image.width);
      final y2 = (r.y2 * image.height).ceil().clamp(0, image.height);
      if (x2 - x1 < 2 || y2 - y1 < 2) continue;
      _pixelate(image, x1, y1, x2, y2);
      blurred++;
    }
    if (blurred == 0) {
      return FaceBlurResult(bytes: bytes, faceCount: 0, width: image.width, height: image.height, changed: false);
    }
    final out = Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
    return FaceBlurResult(bytes: out, faceCount: blurred, width: image.width, height: image.height, changed: true);
  }

  /// Same as [apply] but runs the CPU-heavy work in a background isolate so
  /// the UI thread stays responsive.
  Future<FaceBlurResult> applyInBackground(
    Uint8List bytes,
    List<NormRect> faces, {
    int width = 0,
    int height = 0,
  }) {
    if (faces.isEmpty) {
      return Future.value(
        FaceBlurResult(bytes: bytes, faceCount: 0, width: width, height: height, changed: false),
      );
    }
    final blurrer = this;
    return Isolate.run(() => blurrer.apply(bytes, faces, width: width, height: height));
  }

  void _pixelate(img.Image image, int x1, int y1, int x2, int y2) {
    final w = x2 - x1, h = y2 - y1;
    final block = math.max(minBlockPx, (math.min(w, h) / blocksAcross).round());
    for (var by = y1; by < y2; by += block) {
      final bh = math.min(block, y2 - by);
      for (var bx = x1; bx < x2; bx += block) {
        final bw = math.min(block, x2 - bx);
        var r = 0, g = 0, b = 0, n = 0;
        for (var y = by; y < by + bh; y++) {
          for (var x = bx; x < bx + bw; x++) {
            final p = image.getPixel(x, y);
            r += p.r.toInt();
            g += p.g.toInt();
            b += p.b.toInt();
            n++;
          }
        }
        if (n == 0) continue;
        final color = img.ColorRgb8(r ~/ n, g ~/ n, b ~/ n);
        for (var y = by; y < by + bh; y++) {
          for (var x = bx; x < bx + bw; x++) {
            image.setPixel(x, y, color);
          }
        }
      }
    }
  }
}

/// Detects and pixelates faces in one call: detection on the caller's
/// thread (platform detectors need it), pixelation in a background isolate.
Future<FaceBlurResult> anonymiseFaces({
  required Uint8List bytes,
  required int width,
  required int height,
  required FaceRegionDetector detector,
  String? path,
  FaceBlurrer blurrer = const FaceBlurrer(),
}) async {
  final faces = await detector.detectFaces(bytes, width: width, height: height, path: path);
  return blurrer.applyInBackground(bytes, faces, width: width, height: height);
}
