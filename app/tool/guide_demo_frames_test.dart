// Guide demo frame sheets — not part of the regular test suite.
//
// Renders every guide demo (lib/guide/) at each key of its timeline, from the
// demo camera and from the side, and writes one contact-sheet PNG per layout
// type so the motion can be checked by eye. Run from app/:
//
//   flutter test tool/guide_demo_frames_test.dart
//
// Environment:
//   IWF_DEMO_OUT    output folder (default build/guide_demo_frames)
//   IWF_DEMO_TYPES  comma-separated wire names to render (default: all demos)
//   IWF_DEMO_LOCALE ko / ja / en for the labels (default ko)
//   IWF_NOTO_FONT   Korean font file, as in tool/screenshots_test.dart
//                   (default tool/fonts/NotoSansKR.ttf; JP looked up next to it)
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/app/app.dart';
import 'package:iwantfigure/guide/guide_demos.dart';
import 'package:iwantfigure/l10n/guide_content.dart';
import 'package:iwantfigure/l10n/strings.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/models/scene.dart';
import 'package:iwantfigure/scene3d/projection.dart';
import 'package:iwantfigure/scene3d/scene_painter.dart';
import 'package:iwantfigure/scene3d/timeline.dart';

final _flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
final _notoPath = Platform.environment['IWF_NOTO_FONT'] ?? 'tool/fonts/NotoSansKR.ttf';
final _outDir = Directory(Platform.environment['IWF_DEMO_OUT'] ?? 'build/guide_demo_frames');

const _cell = Size(340, 250);
const _captionH = 34.0;
const _columns = 3;

Future<void> _loadFonts() async {
  final cache = '$_flutterRoot/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String path) async => ByteData.sublistView(await File(path).readAsBytes());
  final roboto = FontLoader('Roboto')
    ..addFont(bytes('$cache/Roboto-Regular.ttf'))
    ..addFont(bytes('$cache/Roboto-Medium.ttf'));
  await roboto.load();
  if (File(_notoPath).existsSync()) {
    await (FontLoader('NotoSansKR')..addFont(bytes(_notoPath))).load();
  }
  final jp = _notoPath.replaceAll('NotoSansKR', 'NotoSansJP');
  if (File(jp).existsSync()) {
    await (FontLoader('NotoSansJP')..addFont(bytes(jp))).load();
  }
}

/// Times worth looking at: every key where something changed, plus the
/// middle of segments that move an actor.
List<(double, SceneFrame)> _sampleTimes(SceneTimeline tl) {
  final times = tl.keyTimes;
  final out = <(double, SceneFrame)>[(0, tl.frameAt(0))];
  for (var i = 1; i < times.length; i++) {
    final a = times[i - 1].toDouble(), b = times[i].toDouble();
    if (b <= a) continue;
    final before = tl.frameAt(a), after = tl.frameAt(b);
    if (!_differs(before, after, actorsOnly: false)) continue;
    if (_differs(before, after, actorsOnly: true)) out.add(((a + b) / 2, tl.frameAt((a + b) / 2)));
    out.add((b, after));
  }
  return out;
}

bool _differs(SceneFrame a, SceneFrame b, {required bool actorsOnly}) {
  if (!actorsOnly &&
      ((a.claw.tip - b.claw.tip).length > 0.5 || (a.claw.openWidthMm - b.claw.openWidthMm).abs() > 0.5)) {
    return true;
  }
  if (a.hidden.length != b.hidden.length) return !actorsOnly;
  for (final id in a.poses.keys) {
    final p = a.poses[id]!, q = b.poses[id]!;
    if ((p.position - q.position).length > 0.5) return true;
    if ((p.rotation.pitchDeg - q.rotation.pitchDeg).abs() > 0.3 ||
        (p.rotation.rollDeg - q.rotation.rollDeg).abs() > 0.3 ||
        (p.rotation.yawDeg - q.rotation.yawDeg).abs() > 0.3) {
      return true;
    }
  }
  return false;
}

void _paintCaption(Canvas canvas, Offset at, String text, double width) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: 'Roboto',
        fontFamilyFallback: ['NotoSansKR', 'NotoSansJP'],
        fontSize: 11,
        color: Color(0xFF222222),
        height: 1.25,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 2,
    ellipsis: '…',
  )..layout(maxWidth: width - 8);
  tp.paint(canvas, at + const Offset(4, 3));
}

Future<void> _renderSheet(LayoutType type, S s) async {
  final demo = guideDemoFor(type, s);
  if (demo == null) return;
  final tl = demo.timeline;
  final guide = guideFor(type, s);
  final colors = ColorScheme.fromSeed(seedColor: IWantFigureApp.seedColor);
  const labelStyle = TextStyle(fontFamily: 'Roboto', fontFamilyFallback: ['NotoSansKR', 'NotoSansJP']);
  final labels = SceneLabels(dropHole: s.labelDropHole, front: s.sceneFront);
  final samples = _sampleTimes(tl);

  final views = [
    OrbitCamera.fromHint(tl.stage.camera),
    // Far away with a narrow lens: close to an orthographic side view.
    OrbitCamera.fromHint(
      CameraHint(yawDeg: 90, pitchDeg: 2, distanceMm: tl.stage.camera.distanceMm * 2.2, target: tl.stage.camera.target),
      fovDeg: 22,
    ),
  ];
  final cellW = _cell.width * views.length;
  final cellH = _cell.height + _captionH;
  final rows = (samples.length / _columns).ceil();
  final sheet = Size(cellW * _columns, cellH * rows + 30);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & sheet);
  canvas.drawRect(Offset.zero & sheet, Paint()..color = Colors.white);
  _paintCaption(
    canvas,
    Offset.zero,
    '${type.wire} — ${tl.totalMs} ms, ${samples.length} frames; left: demo camera, right: side view from +X (front 手前 = left)',
    sheet.width,
  );
  for (var i = 0; i < samples.length; i++) {
    final (ms, frame) = samples[i];
    final origin = Offset((i % _columns) * cellW, 30 + (i ~/ _columns) * cellH);
    for (var v = 0; v < views.length; v++) {
      final o = origin + Offset(v * _cell.width, 0);
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.clipRect(Offset.zero & _cell);
      canvas.drawRect(Offset.zero & _cell, Paint()..color = colors.surfaceContainerLow);
      ScenePainter(
        scene: tl.sceneFor(frame),
        camera: views[v],
        colors: colors,
        labels: labels,
        textStyle: labelStyle,
      ).paint(canvas, _cell);
      canvas.restore();
    }
    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, cellW, cellH),
      Paint()
        ..color = const Color(0xFFBBBBBB)
        ..style = PaintingStyle.stroke,
    );
    final stepText = frame.step >= 0 && frame.step < guide.howTo.length
        ? '${frame.step + 1}. ${guide.howTo[frame.step]}'
        : '(no step)';
    _paintCaption(canvas, origin + Offset(0, _cell.height), '#$i  ${ms.round()} ms  $stepText', cellW);
  }
  final image = await recorder.endRecording().toImage(sheet.width.round(), sheet.height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  _outDir.createSync(recursive: true);
  File('${_outDir.path}/${type.wire}.png').writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final wanted = (Platform.environment['IWF_DEMO_TYPES'] ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();
  final s = S(AppLocale.fromCode(Platform.environment['IWF_DEMO_LOCALE'] ?? 'ko'));

  setUpAll(_loadFonts);

  for (final type in LayoutType.values) {
    if (wanted.isNotEmpty && !wanted.contains(type.wire)) continue;
    test('frames ${type.wire}', () async {
      await _renderSheet(type, s);
    });
  }
}
