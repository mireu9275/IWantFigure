import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/aim_engine.dart';
import 'package:iwantfigure/scene3d/projection.dart';
import 'package:iwantfigure/scene3d/scene_painter.dart';
import 'package:iwantfigure/scene3d/scene_view.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SceneLabels defaults keep the previous texts and compare by value', () {
    const d = SceneLabels.defaults;
    expect(d.dropHole, '落とし口');
    expect(d.front, '手前');
    expect(d.resetView, 'Reset view');
    expect(d.playMotion, 'Play motion');
    expect(d.pauseMotion, 'Pause motion');
    expect(const SceneLabels(dropHole: 'a'), const SceneLabels(dropHole: 'a'));
    expect(const SceneLabels(dropHole: 'a'), isNot(const SceneLabels(dropHole: 'b')));
    expect(const SceneLabels(dropHole: 'a').hashCode, const SceneLabels(dropHole: 'a').hashCode);
  });

  test('ScenePainter repaints when the labels change', () {
    final scene = const AimEngine().plan(sampleAnalysis()).scene;
    final camera = OrbitCamera.fromHint(scene.camera);
    const light = ColorScheme.light();
    final a = ScenePainter(scene: scene, camera: camera, colors: light);
    expect(a.labels, SceneLabels.defaults);
    expect(a.shouldRepaint(ScenePainter(scene: scene, camera: camera, colors: light)), isFalse);
    expect(
      a.shouldRepaint(ScenePainter(
        scene: scene,
        camera: camera,
        colors: light,
        labels: const SceneLabels(dropHole: '낙하구'),
      )),
      isTrue,
    );
  });

  testWidgets('SceneView uses the given labels for its tooltips', (tester) async {
    final scene = const AimEngine().plan(sampleAnalysis()).scene;
    const labels = SceneLabels(
      dropHole: '낙하구',
      front: '앞',
      resetView: '시점 초기화',
      playMotion: '재생',
      pauseMotion: '일시정지',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SceneView(scene: scene, labels: labels)),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('시점 초기화'), findsOneWidget);
    expect(find.byTooltip('일시정지'), findsOneWidget);
    await tester.tap(find.byTooltip('일시정지'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('재생'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Default labels still show the English tooltips.
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SceneView(scene: scene))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Reset view'), findsOneWidget);
  });
}
