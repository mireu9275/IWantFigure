import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/models/scene.dart';
import 'package:iwantfigure/scene3d/projection.dart';
import 'package:iwantfigure/scene3d/scene_painter.dart';

void main() {
  Scene3D scene(ClawRotation rotation) => Scene3D(
        claw: SceneClaw(center: const Vec3(0, 0, 140), rotation: rotation),
        boxes: const [SceneBox(id: 'prize', pose: Pose(Vec3(0, 0, 140)), size: Vec3(150, 200, 100))],
      );

  testWidgets('painter renders a twist arrow for known rotations without errors', (tester) async {
    for (final rotation in ClawRotation.values) {
      await tester.pumpWidget(MaterialApp(
        home: CustomPaint(
          size: const Size(300, 300),
          painter: ScenePainter(
            scene: scene(rotation),
            camera: OrbitCamera(),
            colors: const ColorScheme.light(),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$rotation');
    }
  });

  test('shouldRepaint reacts to a rotation change', () {
    final a = ScenePainter(scene: scene(ClawRotation.unknown), camera: OrbitCamera(), colors: const ColorScheme.light());
    final b = ScenePainter(scene: scene(ClawRotation.clockwise), camera: OrbitCamera(), colors: const ColorScheme.light());
    expect(b.shouldRepaint(a), isTrue);
  });
}
