import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/aim_engine.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/models/scene.dart';
import 'package:iwantfigure/scene3d/projection.dart';
import 'package:iwantfigure/scene3d/scene_painter.dart';
import 'package:iwantfigure/scene3d/scene_view.dart';

AnalysisResult _sample() {
  final json = jsonDecode(File('assets/samples/bridge_parallel.json').readAsStringSync())
      as Map<String, dynamic>;
  return AnalysisResult.fromJson(json);
}

final Finder _scenePaint = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ScenePainter);

ScenePainter _painter(WidgetTester tester) => tester.widget<CustomPaint>(_scenePaint).painter! as ScenePainter;

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(theme: theme, home: Scaffold(body: child));

/// Two taps close enough in time to count as a double tap.
Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  const engine = AimEngine();

  testWidgets('renders the bridge sample, animates and survives gestures', (tester) async {
    final scene = engine.plan(_sample()).scene;
    expect(scene.motion, isNotNull);
    expect(scene.claw, isNotNull);
    expect(scene.markers, isNotEmpty);

    await tester.pumpWidget(_host(SceneView(scene: scene, caption: 'aim here')));
    expect(_scenePaint, findsOneWidget);
    expect(find.text('aim here'), findsOneWidget);
    expect(find.text(scene.motion!.description), findsOneWidget);

    // The animation repeats forever, so pump explicit durations only.
    expect(_painter(tester).t, 0);
    await tester.pump(const Duration(milliseconds: 800));
    final mid = _painter(tester).t;
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    await tester.pump(const Duration(milliseconds: 1000)); // 1.8 s: inside the hold
    expect(_painter(tester).t, closeTo(1, 1e-9));
    await tester.pump(const Duration(milliseconds: 700)); // 2.5 s: wrapped around
    expect(_painter(tester).t, lessThan(0.5));
    expect(tester.takeException(), isNull);

    // Initial camera comes from the scene hint.
    final initial = _painter(tester).camera;
    expect(initial, OrbitCamera.fromHint(scene.camera));

    // Drag orbits the camera.
    await tester.drag(find.byType(SceneView), const Offset(80, -40));
    await tester.pump();
    final orbited = _painter(tester).camera;
    expect(orbited.yawDeg, isNot(closeTo(initial.yawDeg, 1e-6)));
    expect(orbited.pitchDeg, isNot(closeTo(initial.pitchDeg, 1e-6)));
    expect(orbited.distanceMm, initial.distanceMm);

    // Double-tap resets it.
    await _doubleTap(tester, find.byType(SceneView));
    expect(_painter(tester).camera, initial);
    expect(tester.takeException(), isNull);

    // Overlay buttons: pause / play and reset.
    await tester.drag(find.byType(SceneView), const Offset(-30, 10));
    await tester.pump();
    expect(_painter(tester).camera, isNot(initial));
    await tester.tap(find.byIcon(Icons.center_focus_weak));
    await tester.pump();
    expect(_painter(tester).camera, initial);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    final frozen = _painter(tester).t;
    await tester.pump(const Duration(milliseconds: 500));
    expect(_painter(tester).t, frozen);
    await tester.tap(find.byIcon(Icons.play_arrow));
    // A ticker started outside a frame records its start time on its first
    // tick, so pump one frame before advancing the clock.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_painter(tester).t, isNot(frozen));
    expect(tester.takeException(), isNull);
  });

  testWidgets('animateMotion: false keeps the prize at its current pose', (tester) async {
    final scene = engine.plan(_sample()).scene;
    await tester.pumpWidget(_host(SceneView(scene: scene, animateMotion: false)));
    expect(_scenePaint, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));
    expect(_painter(tester).t, 0);
    // The play button is available and starts the animation.
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_painter(tester).t, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a scene without motion, claw or markers renders', (tester) async {
    const scene = Scene3D(
      boxes: [
        SceneBox(id: 'prize', pose: Pose(Vec3(0, 0, 50)), size: Vec3(150, 200, 100), label: 'figure'),
      ],
      dropHole: SceneDropHole(xMin: -100, xMax: 100, yMin: 150, yMax: 250),
    );
    await tester.pumpWidget(_host(const SceneView(scene: scene, caption: 'static')));
    expect(_scenePaint, findsOneWidget);
    expect(find.byIcon(Icons.pause), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_painter(tester).t, 0);
    await tester.drag(find.byType(SceneView), const Offset(0, 120));
    await tester.pump();
    await _doubleTap(tester, find.byType(SceneView));
    expect(tester.takeException(), isNull);

    // Completely empty scene, dark theme, no caption.
    await tester.pumpWidget(_host(const SceneView(scene: Scene3D()), theme: ThemeData.dark()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_scenePaint, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('didUpdateWidget resets the camera on a new hint and restarts on a new motion',
      (tester) async {
    final scene = engine.plan(_sample()).scene;
    await tester.pumpWidget(_host(SceneView(scene: scene)));
    await tester.drag(find.byType(SceneView), const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 700));
    final moved = _painter(tester).camera;
    expect(moved, isNot(OrbitCamera.fromHint(scene.camera)));
    expect(_painter(tester).t, greaterThan(0));

    // Same camera hint and an equal-valued motion: nothing is reset.
    final sameAgain = scene.copyWith(markers: const []);
    await tester.pumpWidget(_host(SceneView(scene: sameAgain)));
    expect(_painter(tester).camera, moved);
    expect(_painter(tester).t, greaterThan(0));

    // New hint → camera reset; new motion → animation restarted from 0.
    const hint = CameraHint(yawDeg: -60, pitchDeg: 50, distanceMm: 900);
    final next = scene.copyWith(
      camera: hint,
      motion: SceneMotion(
        boxId: scene.motion!.boxId,
        from: scene.motion!.from,
        to: Pose(scene.motion!.to.position + const Vec3(0, 40, 0)),
        description: 'moved',
      ),
    );
    await tester.pumpWidget(_host(SceneView(scene: next)));
    expect(_painter(tester).camera, OrbitCamera.fromHint(hint));
    expect(_painter(tester).t, 0);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).t, greaterThan(0));
    expect(find.text('moved'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('works with an unbounded height (inside a scrolling list)', (tester) async {
    final scene = engine.plan(_sample()).scene;
    await tester.pumpWidget(_host(ListView(children: [SceneView(scene: scene)])));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_scenePaint, findsOneWidget);
    final box = tester.getSize(find.byType(SceneView));
    expect(box.height, greaterThan(0));
    expect(box.height.isFinite, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('painter draws bridge, platform and 3-claw scenes in both themes', (tester) async {
    final bridge = engine.plan(_sample()).scene;
    final platform = engine
        .plan(_sample().copyWith(
          layoutType: LayoutType.frontDrop,
          strategy: const Strategy(technique: Technique.yose, targetObjectId: 'box1'),
          machine: const MachineInfo(clawCount: 3, exitSide: ExitSide.front),
        ))
        .scene;
    expect(platform.boxes.any((b) => b.material == SceneMaterial.acrylic), isTrue);
    expect(platform.claw?.clawCount, 3);
    final tube = engine.plan(_sample().copyWith(layoutType: LayoutType.bridgeStep)).scene;
    expect(tube.cylinders.every((c) => c.material == SceneMaterial.rubberTube), isTrue);

    for (final scene in [bridge, platform, tube]) {
      for (final colors in [const ColorScheme.light(), const ColorScheme.dark()]) {
        for (final t in [0.0, 0.5, 1.0]) {
          for (final camera in [
            OrbitCamera.fromHint(scene.camera),
            OrbitCamera(yawDeg: 180, pitchDeg: 85, distanceMm: 400),
            OrbitCamera(yawDeg: -90, pitchDeg: 5, distanceMm: 4000),
            OrbitCamera(yawDeg: 45, pitchDeg: 5, distanceMm: 400, target: const Vec3(0, 0, 500)),
          ]) {
            final recorder = ui.PictureRecorder();
            final canvas = Canvas(recorder);
            ScenePainter(scene: scene, camera: camera, colors: colors, t: t).paint(canvas, const Size(320, 240));
            recorder.endRecording().dispose();
          }
        }
      }
    }
    // Degenerate sizes are ignored, not crashed on.
    ScenePainter(scene: bridge, camera: OrbitCamera(), colors: const ColorScheme.light())
        .paint(Canvas(ui.PictureRecorder()), Size.zero);
    expect(tester.takeException(), isNull);
  });

  test('shouldRepaint reacts to scene, camera, t and theme changes', () {
    final scene = engine.plan(_sample()).scene;
    final camera = OrbitCamera.fromHint(scene.camera);
    const light = ColorScheme.light();
    final a = ScenePainter(scene: scene, camera: camera, colors: light, t: 0.2);
    expect(a.shouldRepaint(ScenePainter(scene: scene, camera: camera.copyWith(), colors: light, t: 0.2)), isFalse);
    expect(a.shouldRepaint(ScenePainter(scene: scene, camera: camera.copyWith(yawDeg: 1), colors: light, t: 0.2)), isTrue);
    expect(a.shouldRepaint(ScenePainter(scene: scene, camera: camera, colors: light, t: 0.3)), isTrue);
    expect(a.shouldRepaint(ScenePainter(scene: scene, camera: camera, colors: const ColorScheme.dark(), t: 0.2)), isTrue);
    expect(a.shouldRepaint(ScenePainter(scene: scene.copyWith(), camera: camera, colors: light, t: 0.2)), isTrue);
  });
}
