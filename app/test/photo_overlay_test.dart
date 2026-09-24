import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/aim_engine.dart';
import 'package:iwantfigure/l10n/strings.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/widgets/photo_overlay.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OverlayMapper letterboxes and round-trips', () {
    final m = OverlayMapper(viewport: const Size(400, 400), imageWidth: 200, imageHeight: 100);
    expect(m.imageRect, const Rect.fromLTWH(0, 100, 400, 200));
    final w = m.toWidget(const Pt(0.5, 0.5));
    expect(w, const Offset(200, 200));
    final n = m.toNorm(const Offset(400, 300));
    expect(n.x, closeTo(1, 1e-9));
    expect(n.y, closeTo(1, 1e-9));

    final tall = OverlayMapper(viewport: const Size(100, 400), imageWidth: 100, imageHeight: 100);
    expect(tall.imageRect, const Rect.fromLTWH(0, 150, 100, 100));
  });

  Widget host(Widget child) => MaterialApp(
        home: LocaleScope(
          strings: const S(AppLocale.ko),
          child: Scaffold(
            body: Center(child: SizedBox(width: 320, height: 240, child: child)),
          ),
        ),
      );

  testWidgets('paints without a plan overlay and with one', (tester) async {
    final bytes = (await tester.runAsync(fakePngBytes))!;
    final analysis = sampleAnalysis();
    const engine = AimEngine();
    final plan = engine.plan(analysis);
    final noPlan = engine.plan(analysis.copyWith(layoutType: LayoutType.unknown));

    for (final p in [noPlan, plan]) {
      await tester.pumpWidget(host(PhotoOverlay(
        imageBytes: bytes,
        imageWidth: 64,
        imageHeight: 48,
        plan: p,
        corrections: SceneCorrections.none,
        editing: false,
        onCorrectionsChanged: (_) {},
        otherObjects: analysis.objects,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('dragging a corner in edit mode emits a new prize bbox', (tester) async {
    final bytes = (await tester.runAsync(fakePngBytes))!;
    final analysis = sampleAnalysis();
    final plan = const AimEngine().plan(analysis);
    final emitted = <SceneCorrections>[];

    await tester.pumpWidget(host(PhotoOverlay(
      imageBytes: bytes,
      imageWidth: 64,
      imageHeight: 48,
      plan: plan,
      corrections: SceneCorrections.none,
      editing: true,
      onCorrectionsChanged: emitted.add,
      throttle: Duration.zero,
    )));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(InteractiveViewer), findsNothing);

    final box = tester.getRect(find.byType(PhotoOverlay));
    final mapper = OverlayMapper(viewport: box.size, imageWidth: 64, imageHeight: 48);
    final bbox = plan.overlay!.prizeBbox;
    final corner = box.topLeft + mapper.toWidget(Pt(bbox.x2, bbox.y2));

    final gesture = await tester.startGesture(corner);
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(20, 15));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(10, 5));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 20));

    expect(emitted, isNotEmpty);
    final last = emitted.last;
    expect(last.prizeBbox, isNotNull);
    expect(last.prizeBbox!.x2, greaterThan(bbox.x2));
    expect(last.prizeBbox!.y2, greaterThan(bbox.y2));
    expect(last.prizeBbox!.x1, closeTo(bbox.x1, 1e-6));
    expect(last.topFaceRatio, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the front bar emits a frontBar correction', (tester) async {
    final bytes = (await tester.runAsync(fakePngBytes))!;
    final analysis = sampleAnalysis();
    final plan = const AimEngine().plan(analysis);
    final emitted = <SceneCorrections>[];

    await tester.pumpWidget(host(PhotoOverlay(
      imageBytes: bytes,
      imageWidth: 64,
      imageHeight: 48,
      plan: plan,
      corrections: SceneCorrections.none,
      editing: true,
      onCorrectionsChanged: emitted.add,
      throttle: Duration.zero,
    )));
    await tester.pump(const Duration(milliseconds: 50));

    final box = tester.getRect(find.byType(PhotoOverlay));
    final mapper = OverlayMapper(viewport: box.size, imageWidth: 64, imageHeight: 48);
    final front = plan.overlay!.frontBar!;
    // Grab the bar outside the prize bbox so the hit resolves to the bar.
    final grab = box.topLeft + mapper.toWidget(Pt(front[0].x + 0.05, front[0].y));

    final gesture = await tester.startGesture(grab);
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(0, 12));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 20));

    expect(emitted, isNotEmpty);
    final fb = emitted.last.frontBar;
    expect(fb, isNotNull);
    expect(fb!.cy, greaterThan(front[0].y));
    expect(emitted.last.prizeBbox, isNull);
  });

  testWidgets('pinch zoom reports onZoomChanged true, reset reports false', (tester) async {
    final bytes = (await tester.runAsync(fakePngBytes))!;
    final plan = const AimEngine().plan(sampleAnalysis());
    final zoomEvents = <bool>[];

    await tester.pumpWidget(host(PhotoOverlay(
      imageBytes: bytes,
      imageWidth: 64,
      imageHeight: 48,
      plan: plan,
      corrections: SceneCorrections.none,
      editing: false,
      onCorrectionsChanged: (_) {},
      onZoomChanged: zoomEvents.add,
    )));
    await tester.pump(const Duration(milliseconds: 50));
    expect(zoomEvents, isEmpty);

    await pinchZoom(tester, find.byType(PhotoOverlay));
    expect(zoomEvents, [true]);

    // Entering edit mode resets the viewer → zoom is reported off.
    await tester.pumpWidget(host(PhotoOverlay(
      imageBytes: bytes,
      imageWidth: 64,
      imageHeight: 48,
      plan: plan,
      corrections: SceneCorrections.none,
      editing: true,
      onCorrectionsChanged: (_) {},
      onZoomChanged: zoomEvents.add,
    )));
    await tester.pump(const Duration(milliseconds: 50));
    expect(zoomEvents, [true, false]);
  });

  /// The bundled sample plus a middle bar and a far front bar (4-bar setup).
  AnalysisResult fourBarAnalysis() {
    final a = sampleAnalysis();
    return a.copyWith(objects: [
      ...a.objects,
      const DetectedObject(id: 'bar_mid', kind: ObjectKind.bar, bbox: NBox(0.13, 0.60, 0.87, 0.63)),
      const DetectedObject(id: 'bar_far', kind: ObjectKind.bar, bbox: NBox(0.10, 0.90, 0.90, 0.93)),
    ]);
  }

  testWidgets('paints extra bars and a known claw rotation without exceptions', (tester) async {
    final bytes = (await tester.runAsync(fakePngBytes))!;
    final analysis = fourBarAnalysis();
    const engine = AimEngine();
    for (final rot in ClawRotation.values) {
      final corrections = SceneCorrections(clawRotation: rot);
      final plan = engine.plan(analysis, corrections: corrections);
      expect(plan.overlay!.extraBars.length, 2);
      expect(plan.barCount, 4);
      expect(plan.clawRotation, rot);
      for (final editing in [false, true]) {
        await tester.pumpWidget(host(PhotoOverlay(
          imageBytes: bytes,
          imageWidth: 64,
          imageHeight: 48,
          plan: plan,
          corrections: corrections,
          editing: editing,
          onCorrectionsChanged: (_) {},
          otherObjects: analysis.objects,
        )));
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(CustomPaint), findsWidgets);
        expect(tester.takeException(), isNull, reason: '$rot editing=$editing');
      }
    }
    // Also in Japanese and English, since the glyph/bar labels are localized.
    for (final locale in [AppLocale.ja, AppLocale.en]) {
      final plan = engine.plan(analysis, corrections: const SceneCorrections(clawRotation: ClawRotation.counterClockwise));
      await tester.pumpWidget(MaterialApp(
        home: LocaleScope(
          strings: S(locale),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              height: 240,
              child: PhotoOverlay(
                imageBytes: bytes,
                imageWidth: 64,
                imageHeight: 48,
                plan: plan,
                corrections: const SceneCorrections(clawRotation: ClawRotation.counterClockwise),
                editing: false,
                onCorrectionsChanged: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  testWidgets('dragging in edit mode keeps the claw rotation correction', (tester) async {
    final bytes = (await tester.runAsync(fakePngBytes))!;
    final analysis = sampleAnalysis();
    const corrections = SceneCorrections(clawRotation: ClawRotation.counterClockwise, yawDeg: 5);
    final plan = const AimEngine().plan(analysis, corrections: corrections);
    final emitted = <SceneCorrections>[];

    await tester.pumpWidget(host(PhotoOverlay(
      imageBytes: bytes,
      imageWidth: 64,
      imageHeight: 48,
      plan: plan,
      corrections: corrections,
      editing: true,
      onCorrectionsChanged: emitted.add,
      throttle: Duration.zero,
    )));
    await tester.pump(const Duration(milliseconds: 50));

    final box = tester.getRect(find.byType(PhotoOverlay));
    final mapper = OverlayMapper(viewport: box.size, imageWidth: 64, imageHeight: 48);
    final bbox = plan.overlay!.prizeBbox;
    final corner = box.topLeft + mapper.toWidget(Pt(bbox.x2, bbox.y2));

    final gesture = await tester.startGesture(corner);
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.moveBy(const Offset(15, 10));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 20));

    expect(emitted, isNotEmpty);
    expect(emitted.last.prizeBbox, isNotNull);
    expect(emitted.last.clawRotation, ClawRotation.counterClockwise);
    expect(emitted.last.yawDeg, 5);
    expect(tester.takeException(), isNull);
  });
}
