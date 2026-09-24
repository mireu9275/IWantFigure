import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iwantfigure/services/face_blur.dart';
import 'package:iwantfigure/services/image_prep.dart';
import 'package:iwantfigure/services/session_controller.dart';

import 'helpers.dart';

/// A 200×120 JPEG with a red "face" square on a blue background.
Uint8List _photo() {
  final image = img.Image(width: 200, height: 120);
  img.fill(image, color: img.ColorRgb8(30, 60, 200));
  img.fillRect(image, x1: 80, y1: 30, x2: 120, y2: 70, color: img.ColorRgb8(220, 40, 40));
  // A sharp checkerboard inside the face so pixelation is measurable.
  for (var y = 30; y < 70; y++) {
    for (var x = 80; x < 120; x++) {
      if ((x + y).isEven) image.setPixel(x, y, img.ColorRgb8(250, 250, 250));
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

class _FakeDetector implements FaceRegionDetector {
  _FakeDetector(this.rects);
  final List<NormRect> rects;
  int calls = 0;
  @override
  Future<List<NormRect>> detectFaces(Uint8List imageBytes, {required int width, required int height, String? path}) async {
    calls++;
    return rects;
  }
}

void main() {
  const face = NormRect(0.4, 0.25, 0.6, 0.58);

  test('empty face list returns the same bytes without decoding', () {
    final bytes = _photo();
    final r = const FaceBlurrer().apply(bytes, const [], width: 200, height: 120);
    expect(r.changed, isFalse);
    expect(r.faceCount, 0);
    expect(identical(r.bytes, bytes), isTrue);
    expect(r.width, 200);
  });

  test('pixelates the face region and leaves the rest untouched', () {
    final bytes = _photo();
    final r = const FaceBlurrer(padding: 0).apply(bytes, const [face]);
    expect(r.changed, isTrue);
    expect(r.faceCount, 1);
    expect(r.width, 200);
    expect(r.height, 120);
    final out = img.decodeImage(r.bytes)!;
    // Inside the face: the checkerboard is gone — neighbouring pixels are (almost) equal.
    final a = out.getPixel(100, 50), b = out.getPixel(101, 50);
    expect((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs(), lessThan(40));
    // Average of red and white ≈ pinkish, i.e. neither pure red nor pure white.
    expect(a.r, greaterThan(200));
    expect(a.g, inInclusiveRange(90, 200));
    // Outside the face: still blue.
    final c = out.getPixel(20, 20);
    expect(c.b, greaterThan(150));
    expect(c.r, lessThan(80));
    // Output is a JPEG.
    expect(r.bytes[0], 0xFF);
    expect(r.bytes[1], 0xD8);
  });

  test('padding grows the region and rectangles are clamped to the image', () {
    final bytes = _photo();
    final r = const FaceBlurrer(padding: 0.5).apply(bytes, const [NormRect(0.9, 0.9, 1.4, 1.5)]);
    expect(r.changed, isTrue);
    expect(r.faceCount, 1);
    expect(const NormRect(0.9, 0.9, 1.4, 1.5).padded(0.5).x2, 1.0);
    // Degenerate rectangles are skipped.
    final none = const FaceBlurrer().apply(bytes, const [NormRect(0.5, 0.5, 0.5, 0.5)]);
    expect(none.changed, isFalse);
  });

  test('undecodable input is passed through', () {
    final junk = Uint8List.fromList(List.filled(64, 7));
    final r = const FaceBlurrer().apply(junk, const [face], width: 1, height: 1);
    expect(r.changed, isFalse);
    expect(identical(r.bytes, junk), isTrue);
  });

  test('anonymiseFaces runs detection then pixelation in the background', () async {
    final bytes = _photo();
    final det = _FakeDetector(const [face]);
    final r = await anonymiseFaces(bytes: bytes, width: 200, height: 120, detector: det, path: null);
    expect(det.calls, 1);
    expect(r.faceCount, 1);
    expect(r.changed, isTrue);
    expect(r.bytes, isNot(equals(bytes)));
  });

  test('SessionController replaces the photo with the anonymised version', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final original = _photo();
    final det = _FakeDetector(const [face]);
    final stages = <AnalyzeStage>[];
    final c = SessionController(
      photo: PickedPhoto(bytes: original, width: 200, height: 120),
      service: FakeAnalysisService(sampleAnalysis()),
      faceDetector: det,
    );
    c.addListener(() => stages.add(c.stage));
    await c.analyze();
    expect(c.state, SessionState.ready);
    expect(c.blurredFaces, 1);
    expect(c.photo.bytes, isNot(equals(original)));
    expect(c.photo.width, 200);
    expect(stages, contains(AnalyzeStage.blur));

    // Disabled → untouched, no detection.
    final det2 = _FakeDetector(const [face]);
    final c2 = SessionController(
      photo: PickedPhoto(bytes: original, width: 200, height: 120),
      service: FakeAnalysisService(sampleAnalysis()),
      faceDetector: det2,
      blurFaces: false,
    );
    await c2.analyze();
    expect(det2.calls, 0);
    expect(identical(c2.photo.bytes, original), isTrue);
    expect(c2.blurredFaces, 0);
  });
}
