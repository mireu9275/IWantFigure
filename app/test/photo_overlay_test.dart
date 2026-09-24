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

  Widget host(Widget child, {bool wide = true}) => MaterialApp(
        home: LocaleScope(
          strings: const S(AppLocale.ko),
          child: Scaffold(
            body: Center(child: SizedBox(width: 320, height: 240, child: child)),
          ),
        ),
      );

  testWidgets('paints without a plan overlay and with one', (tester) async {
    final bytes = await fakePngBytes();
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
    final bytes = await fakePngBytes();
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
    final bytes = await fakePngBytes();
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
}
