// Screenshot generator — not part of the regular test suite.
//
// Renders the real app (mock analysis service, synthetic machine photo) at a
// phone size and writes PNGs to docs/images/. Run from app/:
//
//   flutter test tool/screenshots_test.dart
//
// Fonts: Roboto + Material icons from the Flutter SDK cache, Noto Sans KR/JP
// for Korean/Japanese. The Noto path comes from IWF_NOTO_FONT when set,
// otherwise tool/fonts/NotoSansKR.ttf (relative to app/, gitignored). The JP
// font is looked up next to it by replacing "NotoSansKR" with "NotoSansJP" in
// the path, so keep both files in the same folder with matching names.
// Missing fonts are skipped silently (Korean/Japanese then render as boxes).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:iwantfigure/app/app.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/screens/analyzing_screen.dart';
import 'package:iwantfigure/screens/guide_screen.dart';
import 'package:iwantfigure/screens/result_screen.dart';
import 'package:iwantfigure/screens/settings_screen.dart';
import 'package:iwantfigure/services/face_blur.dart';
import 'package:iwantfigure/services/history_store.dart';
import 'package:iwantfigure/services/image_prep.dart';
import 'package:iwantfigure/services/mock_api.dart';
import 'package:iwantfigure/services/session_controller.dart';

import '../test/helpers.dart';

final _outDir = Directory('../docs/images');
final _flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
final _notoPath = Platform.environment['IWF_NOTO_FONT'] ?? 'tool/fonts/NotoSansKR.ttf';

Future<void> _loadFonts() async {
  final cache = '$_flutterRoot/bin/cache/artifacts/material_fonts';
  Future<ByteData> bytes(String path) async {
    final b = await File(path).readAsBytes();
    return ByteData.sublistView(b);
  }
  final roboto = FontLoader('Roboto')
    ..addFont(bytes('$cache/Roboto-Regular.ttf'))
    ..addFont(bytes('$cache/Roboto-Medium.ttf'))
    ..addFont(bytes('$cache/Roboto-Bold.ttf'));
  await roboto.load();
  final icons = FontLoader('MaterialIcons')..addFont(bytes('$cache/MaterialIcons-Regular.otf'));
  await icons.load();
  if (File(_notoPath).existsSync()) {
    final noto = FontLoader('NotoSansKR')..addFont(bytes(_notoPath));
    await noto.load();
  }
  final jp = _notoPath.replaceAll('NotoSansKR', 'NotoSansJP');
  if (File(jp).existsSync()) {
    final noto = FontLoader('NotoSansJP')..addFont(bytes(jp));
    await noto.load();
  }
}

/// A synthetic "front view of a bridge setup" photo whose geometry matches
/// the bundled sample analysis (box at 0.36–0.64 × 0.42–0.74, bars at
/// y≈0.515 and 0.715, claw at the top centre).
Uint8List _machinePhoto({int w = 1456, int h = 1092, bool midBar = false}) {
  final im = img.Image(width: w, height: h);
  // Background gradient (cabinet interior).
  for (var y = 0; y < h; y++) {
    final t = y / h;
    final c = img.ColorRgb8((235 - 60 * t).round(), (236 - 70 * t).round(), (240 - 80 * t).round());
    for (var x = 0; x < w; x++) {
      im.setPixel(x, y, c);
    }
  }
  // Floor / drop area.
  img.fillRect(im, x1: 0, y1: (h * 0.76).round(), x2: w, y2: h, color: img.ColorRgb8(150, 60, 70));
  // Bars.
  for (final cy in [0.515, if (midBar) 0.615, 0.715]) {
    final y = (h * cy).round();
    img.fillRect(im, x1: (w * 0.12).round(), y1: y - 12, x2: (w * 0.88).round(), y2: y + 12, color: img.ColorRgb8(170, 175, 185));
    img.fillRect(im, x1: (w * 0.12).round(), y1: y - 12, x2: (w * 0.88).round(), y2: y - 6, color: img.ColorRgb8(230, 232, 236));
  }
  // Box: top face then front face.
  final x1 = (w * 0.36).round(), x2 = (w * 0.64).round();
  final yTop = (h * 0.42).round(), yMid = (h * 0.53).round(), yBot = (h * 0.74).round();
  img.fillRect(im, x1: x1 + 16, y1: yTop, x2: x2 - 16, y2: yMid, color: img.ColorRgb8(240, 200, 90));
  img.fillRect(im, x1: x1, y1: yMid, x2: x2, y2: yBot, color: img.ColorRgb8(225, 165, 60));
  img.fillRect(im, x1: x1 + 30, y1: yMid + 30, x2: x2 - 30, y2: yBot - 30, color: img.ColorRgb8(90, 120, 200));
  img.fillRect(im, x1: x1 + 50, y1: yMid + 50, x2: x2 - 50, y2: yBot - 50, color: img.ColorRgb8(250, 240, 220));
  // Claw unit.
  final cx = (w * 0.51).round();
  img.fillRect(im, x1: cx - 60, y1: (h * 0.05).round(), x2: cx + 60, y2: (h * 0.16).round(), color: img.ColorRgb8(60, 60, 70));
  img.fillRect(im, x1: cx - 4, y1: 0, x2: cx + 4, y2: (h * 0.06).round(), color: img.ColorRgb8(90, 90, 100));
  for (final s in [-1, 1]) {
    for (var i = 0; i < 90; i++) {
      final yy = (h * 0.16).round() + i * 2;
      final xx = cx + s * (20 + i);
      img.fillRect(im, x1: xx - 5, y1: yy, x2: xx + 5, y2: yy + 3, color: img.ColorRgb8(120, 120, 130));
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 88));
}

Future<void> _shoot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    _outDir.createSync(recursive: true);
    File('${_outDir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _app({
  required GlobalKey key,
  required dynamic settings,
  required HistoryStore history,
  PhotoPicker? picker,
  Widget? home,
}) =>
    RepaintBoundary(
      key: key,
      child: IWantFigureApp(
        settings: settings,
        history: history,
        home: home,
        picker: picker ?? PhotoPicker(picker: FakeImagePicker()),
        faceDetector: const NoopFaceRegionDetector(),
        serviceOverride: const MockAnalyzeApi(delay: Duration(milliseconds: 200)),
        fontFamily: 'Roboto',
        fontFamilyFallback: const ['NotoSansKR', 'NotoSansJP'],
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFonts();
  });

  testWidgets('consent dialog', (tester) async {
    _phone(tester);
    final key = GlobalKey();
    final dir = tempHistoryDir('shot_consent');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final settings = await loadedSettings(initial: {'consent_given': false});
    await tester.pumpWidget(_app(key: key, settings: settings, history: history));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _shoot(tester, key, 'consent_ko');
  });

  testWidgets('home', (tester) async {
    _phone(tester);
    final key = GlobalKey();
    final dir = tempHistoryDir('shot_home');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final settings = await loadedSettings();
    await tester.pumpWidget(_app(key: key, settings: settings, history: history));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await _shoot(tester, key, 'home_ko');
  });

  testWidgets('guide screens', (tester) async {
    _phone(tester);
    final key = GlobalKey();
    final dir = tempHistoryDir('shot_guide');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final settings = await loadedSettings();
    await tester.pumpWidget(_app(key: key, settings: settings, history: history, home: const GuideScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _shoot(tester, key, 'guide_list_ko');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(_app(
      key: key,
      settings: settings,
      history: history,
      home: const GuideDetailScreen(type: LayoutType.bridgeParallel),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await _shoot(tester, key, 'guide_detail_ko');
  });

  for (final code in ['ko', 'ja', 'en']) {
    testWidgets('result screens ($code)', (tester) async {
      _phone(tester);
      final key = GlobalKey();
      final dir = tempHistoryDir('shot_result_$code');
      addTearDown(() => dir.deleteSync(recursive: true));
      final history = HistoryStore(directory: dir);
      await tester.runAsync(history.load);
      final settings = await loadedSettings(initial: {'locale': code});

      final threeBars = code == 'ko';
      final photoBytes = _machinePhoto(midBar: threeBars);
      final photoFile = File('${dir.path}/machine.jpg')..writeAsBytesSync(photoBytes);
      final picker = PhotoPicker(picker: FakeImagePicker(XFile(photoFile.path)));
      var analysis = sampleAnalysis();
      if (threeBars) {
        analysis = analysis.copyWith(objects: [
          ...analysis.objects,
          const DetectedObject(id: 'bar_mid', kind: ObjectKind.bar, bbox: NBox(0.12, 0.60, 0.88, 0.63)),
        ]);
      }
      final controller = SessionController(
        photo: PickedPhoto(bytes: photoBytes, width: 1456, height: 1092, path: photoFile.path),
        service: FakeAnalysisService(analysis),
        locale: code,
        history: history,
      );
      await tester.pumpWidget(_app(
        key: key,
        settings: settings,
        history: history,
        picker: picker,
        home: AnalyzingScreen(controller: controller),
      ));
      await tester.pump(); // post-frame: analyze() starts
      await tester.pump(); // fake service microtasks
      await tester.pump(const Duration(milliseconds: 400)); // zero-delay timer + navigation
      await tester.pump(const Duration(milliseconds: 400)); // route transition
      await settleRealIO(tester, rounds: 10); // image decode for the overlay
      expect(find.byType(ResultScreen), findsOneWidget, reason: 'analysis should have finished ($code)');
      final strings = stringsFor(code);
      await _shoot(tester, key, 'result_photo_$code');

      await tester.tap(find.text(strings.tab3d));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await _shoot(tester, key, 'result_3d_$code');

      await tester.tap(find.text(strings.tabExplain));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await _shoot(tester, key, 'result_explain_$code');

      if (code == 'ko') {
        // Claw twist observed → compensation shown on the photo and in 3D.
        await tester.dragUntilVisible(
          find.text(strings.clawRotationLabel(ClawRotation.clockwise)),
          find.byType(Scrollable).last,
          const Offset(0, -80),
        );
        await tester.tap(find.text(strings.clawRotationLabel(ClawRotation.clockwise)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text(strings.tabPhoto));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await _shoot(tester, key, 'result_rotation_ko');
        await tester.tap(find.text(strings.tab3d));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        await _shoot(tester, key, 'result_3d_rotation_ko');
        await tester.tap(find.text(strings.tabPhoto));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        // Correction mode on the photo tab.
        await tester.tap(find.text(strings.tabPhoto));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final editButton = find.byTooltip(strings.correct);
        if (editButton.evaluate().isNotEmpty) {
          await tester.tap(editButton);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await _shoot(tester, key, 'result_edit_ko');
        }
        // Settings (fresh tree with the real home).
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.pumpWidget(_app(key: key, settings: settings, history: history, picker: picker));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byIcon(Icons.settings_outlined).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(SettingsScreen), findsOneWidget);
        await _shoot(tester, key, 'settings_ko');
      }
    });
  }
}
