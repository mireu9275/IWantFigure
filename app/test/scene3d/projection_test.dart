import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/models/scene.dart';
import 'package:iwantfigure/scene3d/projection.dart';

void main() {
  const viewport = Size(400, 300);
  final centre = Offset(viewport.width / 2, viewport.height / 2);

  test('a point at the target projects to the viewport centre', () {
    for (final yaw in [0.0, 35.0, -120.0, 270.0]) {
      for (final pitch in [5.0, 28.0, 85.0]) {
        final cam = OrbitCamera(yawDeg: yaw, pitchDeg: pitch, target: const Vec3(50, -30, 120));
        final p = cam.project(cam.target, viewport);
        expect(p.visible, isTrue, reason: 'yaw $yaw pitch $pitch');
        expect(p.screen.dx, closeTo(centre.dx, 1e-6), reason: 'yaw $yaw pitch $pitch');
        expect(p.screen.dy, closeTo(centre.dy, 1e-6), reason: 'yaw $yaw pitch $pitch');
        expect(p.depth, closeTo(cam.distanceMm, 1e-6));
      }
    }
  });

  test('eye is at the configured distance and above the target', () {
    final cam = OrbitCamera(yawDeg: 0, pitchDeg: 30, distanceMm: 1000);
    expect((cam.eye - cam.target).length, closeTo(1000, 1e-6));
    expect(cam.eye.z, greaterThan(cam.target.z));
    // yaw 0 → camera on the player's side (+Y).
    expect(cam.eye.y, greaterThan(0));
    expect(cam.eye.x, closeTo(0, 1e-9));
  });

  test('at yaw 0, +X is screen-right, +Y is toward the bottom and +Z is up', () {
    final cam = OrbitCamera(yawDeg: 0, pitchDeg: 28, distanceMm: 1300);
    final right = cam.project(const Vec3(100, 0, 0), viewport).screen;
    final left = cam.project(const Vec3(-100, 0, 0), viewport).screen;
    final front = cam.project(const Vec3(0, 100, 0), viewport).screen;
    final back = cam.project(const Vec3(0, -100, 0), viewport).screen;
    final above = cam.project(const Vec3(0, 0, 100), viewport).screen;
    expect(right.dx, greaterThan(centre.dx));
    expect(left.dx, lessThan(centre.dx));
    expect(front.dy, greaterThan(centre.dy));
    expect(back.dy, lessThan(centre.dy));
    expect(above.dy, lessThan(centre.dy));
    expect(above.dx, closeTo(centre.dx, 1e-6));
  });

  test('points farther away get a smaller scale and a larger depth', () {
    final cam = OrbitCamera(yawDeg: 35, pitchDeg: 28, distanceMm: 1300);
    final near = cam.project(cam.target - cam.forward * 200, viewport);
    final at = cam.project(cam.target, viewport);
    final far = cam.project(cam.target + cam.forward * 400, viewport);
    expect(near.depth, lessThan(at.depth));
    expect(far.depth, greaterThan(at.depth));
    expect(cam.scaleAt(at.depth), closeTo(1, 1e-9));
    expect(cam.scaleAt(far.depth), lessThan(cam.scaleAt(at.depth)));
    expect(cam.scaleAt(near.depth), greaterThan(cam.scaleAt(at.depth)));
    expect(cam.pixelsPerMm(far.depth, viewport), lessThan(cam.pixelsPerMm(at.depth, viewport)));
    // Perspective: the same offset covers fewer pixels when farther away.
    final nearRight = cam.project(cam.target - cam.forward * 200 + cam.right * 50, viewport);
    final farRight = cam.project(cam.target + cam.forward * 400 + cam.right * 50, viewport);
    expect((farRight.screen - far.screen).distance, lessThan((nearRight.screen - near.screen).distance));
  });

  test('points behind the camera are not visible', () {
    final cam = OrbitCamera(yawDeg: 10, pitchDeg: 40, distanceMm: 800);
    final behind = cam.eye - cam.forward * 100;
    final p = cam.project(behind, viewport);
    expect(p.visible, isFalse);
    expect(p.depth, lessThan(0));
    expect(p.screen.dx.isFinite, isTrue);
    expect(p.screen.dy.isFinite, isTrue);
    // A point almost on the camera plane is also hidden.
    expect(cam.project(cam.eye + cam.forward * (OrbitCamera.nearMm / 2), viewport).visible, isFalse);
    expect(cam.project(cam.eye + cam.forward * (OrbitCamera.nearMm * 2), viewport).visible, isTrue);
  });

  test('fromHint copies the hint values', () {
    const hint = CameraHint(yawDeg: 12, pitchDeg: 33, distanceMm: 900, target: Vec3(10, 20, 30));
    final cam = OrbitCamera.fromHint(hint);
    expect(cam.yawDeg, 12);
    expect(cam.pitchDeg, 33);
    expect(cam.distanceMm, 900);
    expect(cam.target, const Vec3(10, 20, 30));
    expect(cam.fovDeg, 45);
    expect(cam, OrbitCamera(yawDeg: 12, pitchDeg: 33, distanceMm: 900, target: const Vec3(10, 20, 30)));
    expect(cam.hashCode, OrbitCamera.fromHint(hint).hashCode);
  });

  test('pitch, distance and fov are clamped, also through copyWith', () {
    final low = OrbitCamera(pitchDeg: -40, distanceMm: 10, fovDeg: 1);
    expect(low.pitchDeg, OrbitCamera.minPitchDeg);
    expect(low.distanceMm, OrbitCamera.minDistanceMm);
    expect(low.fovDeg, OrbitCamera.minFovDeg);

    final high = OrbitCamera(pitchDeg: 200, distanceMm: 99999, fovDeg: 500);
    expect(high.pitchDeg, OrbitCamera.maxPitchDeg);
    expect(high.distanceMm, OrbitCamera.maxDistanceMm);
    expect(high.fovDeg, OrbitCamera.maxFovDeg);

    final base = OrbitCamera(yawDeg: 20, pitchDeg: 30, distanceMm: 1000);
    final moved = base.copyWith(yawDeg: 400, pitchDeg: 90, distanceMm: 0);
    expect(moved.yawDeg, 400);
    expect(moved.pitchDeg, OrbitCamera.maxPitchDeg);
    expect(moved.distanceMm, OrbitCamera.minDistanceMm);
    expect(moved.target, base.target);
    expect(moved.fovDeg, base.fovDeg);
    expect(base.copyWith(), base);
    expect(OrbitCamera.fromHint(const CameraHint(pitchDeg: 0, distanceMm: 5000)).pitchDeg, OrbitCamera.minPitchDeg);
    expect(OrbitCamera.fromHint(const CameraHint(pitchDeg: 0, distanceMm: 5000)).distanceMm, OrbitCamera.maxDistanceMm);
  });

  test('view basis is orthonormal', () {
    final cam = OrbitCamera(yawDeg: 57, pitchDeg: 41, distanceMm: 1500);
    expect(cam.forward.length, closeTo(1, 1e-9));
    expect(cam.right.length, closeTo(1, 1e-9));
    expect(cam.up.length, closeTo(1, 1e-9));
    expect(cam.forward.dot(cam.right), closeTo(0, 1e-9));
    expect(cam.forward.dot(cam.up), closeTo(0, 1e-9));
    expect(cam.right.dot(cam.up), closeTo(0, 1e-9));
    expect(cam.up.z, greaterThan(0));
    expect(cam.right.z, closeTo(0, 1e-9));
  });

  test('focal length follows the shorter viewport side', () {
    final cam = OrbitCamera(fovDeg: 90);
    expect(cam.focalLength(const Size(400, 300)), closeTo(150, 1e-9));
    expect(cam.focalLength(const Size(300, 400)), closeTo(150, 1e-9));
    expect(cam.viewToScreen(const Vec3(0, 0, 500), viewport), centre);
  });
}
