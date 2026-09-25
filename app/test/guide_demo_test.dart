import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/guide/guide_demo.dart';
import 'package:iwantfigure/guide/guide_demos.dart';
import 'package:iwantfigure/l10n/guide_content.dart';
import 'package:iwantfigure/l10n/strings.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/models/scene.dart';
import 'package:iwantfigure/scene3d/timeline.dart';

/// World point [p] in the local frame of a box at [pose] (inverse of
/// [Rotation.apply]: undo yaw, then pitch, then roll).
Vec3 _toLocal(Pose pose, Vec3 p) {
  final r = pose.rotation;
  var v = p - pose.position;
  v = Rotation(yawDeg: -r.yawDeg).apply(v);
  v = Rotation(pitchDeg: -r.pitchDeg).apply(v);
  v = Rotation(rollDeg: -r.rollDeg).apply(v);
  return v;
}

/// How deep [p] is inside [box] grown by [margin] on every side (0 = outside).
double _depthInside(SceneBox box, Vec3 p, double margin) {
  final l = _toLocal(box.pose, p);
  final dx = box.size.x / 2 + margin - l.x.abs();
  final dy = box.size.y / 2 + margin - l.y.abs();
  final dz = box.size.z / 2 + margin - l.z.abs();
  if (dx <= 0 || dy <= 0 || dz <= 0) return 0;
  return math.min(dx, math.min(dy, dz));
}

/// Deepest overlap between the actors' boxes / balls and the still stage
/// (bars and platforms) in [scene], in mm.
(double, String) _penetration(Scene3D stage, Scene3D scene) {
  final stageCylinders = stage.cylinders.map((c) => c.id).toSet();
  final stageBoxes = stage.boxes.map((b) => b.id).toSet();
  final movingBoxes = scene.boxes.where((b) => !stageBoxes.contains(b.id)).toList();
  final movingSpheres = scene.spheres.where((s) => !stage.spheres.any((t) => t.id == s.id)).toList();
  var worst = 0.0;
  var what = '';
  void note(double d, String w) {
    if (d > worst) {
      worst = d;
      what = w;
    }
  }

  for (final c in scene.cylinders.where((c) => stageCylinders.contains(c.id))) {
    final len = (c.p1 - c.p0).length;
    final n = math.max(1, (len / 4).ceil());
    for (var i = 0; i <= n; i++) {
      final p = c.p0.lerp(c.p1, i / n);
      for (final b in movingBoxes) {
        note(_depthInside(b, p, c.radius), '${b.id} × ${c.id}');
      }
      for (final s in movingSpheres) {
        note(s.radius + c.radius - (s.center - p).length, '${s.id} × ${c.id}');
      }
    }
  }
  for (final platform in scene.boxes.where((b) => stageBoxes.contains(b.id))) {
    for (final b in movingBoxes) {
      for (final corner in b.corners()) {
        note(_depthInside(platform, corner, 0), '${b.id} × ${platform.id}');
      }
    }
    for (final s in movingSpheres) {
      // Lowest point of the ball against the platform.
      note(_depthInside(platform, s.center - Vec3(0, 0, s.radius), 0), '${s.id} × ${platform.id}');
    }
  }
  return (worst, what);
}

void main() {
  const s = S(AppLocale.ko);
  final demos = [for (final type in LayoutType.values) ?guideDemoFor(type, s)];

  test('unknown has no demo; the bridge reference demo exists', () {
    expect(guideDemoFor(LayoutType.unknown, s), isNull);
    expect(guideDemoFor(LayoutType.bridgeParallel, s), isNotNull);
  });

  test('timeline interpolates between keys and holds hidden actors until the loop', () {
    const box = SceneBox(id: 'b', pose: Pose(Vec3.zero), size: Vec3(10, 10, 10));
    const actor = SceneActor(id: 'a', pose: Pose(Vec3(0, 0, 0)), boxes: [box]);
    final tl = SceneTimeline(
      stage: const Scene3D(),
      actors: const [actor],
      claw: const ClawState(Vec3(0, 0, 300)),
      keys: const [
        SceneKey(ms: 1000, poses: {'a': Pose(Vec3(100, 0, 0))}, step: 1, curve: Curves.linear),
        SceneKey(ms: 0, hide: {'a'}),
        SceneKey(ms: 500, claw: ClawState(Vec3(0, 0, 100), openWidthMm: 60), step: 2),
      ],
    );
    expect(tl.totalMs, 1500);
    expect(tl.keyTimes, [0, 1000, 1000, 1500]);
    expect(tl.frameAt(500).poses['a']!.position.x, closeTo(50, 1e-9));
    expect(tl.frameAt(500).step, 1);
    expect(tl.frameAt(500).hidden, isEmpty);
    expect(tl.frameAt(1200).hidden, {'a'});
    expect(tl.frameAt(1200).step, 2);
    expect(tl.frameAt(1500).claw.openWidthMm, 60);
    expect(tl.sceneAt(1200).boxes, isEmpty);
    expect(tl.sceneAt(0).boxes.single.pose.position, Vec3.zero);
    expect(tl.steps, [1, 2]);
    expect(tl.startOfStep(2), 1000);
    expect(tl.startOfStep(7), isNull);
    // The zero-length hide key does not split step 2's stretch.
    expect(tl.rangeOfStep(1), (0, 1000));
    expect(tl.rangeOfStep(2), (1000, 1500));
    expect(tl.rangeOfStep(7), isNull);
  });

  test('actor parts follow the actor pose', () {
    const actor = SceneActor(
      id: 'a',
      pose: Pose(Vec3.zero),
      boxes: [SceneBox(id: 'b', pose: Pose(Vec3(0, 50, 0)), size: Vec3(10, 10, 10))],
      cylinders: [SceneCylinder(id: 'c', p0: Vec3(0, 0, 0), p1: Vec3(0, 0, 20))],
      spheres: [SceneSphere(id: 's', center: Vec3(10, 0, 0), radius: 5)],
    );
    // Turned 90° clockwise seen from above and moved up.
    const at = Pose(Vec3(0, 0, 100), Rotation(yawDeg: 90));
    final b = actor.boxesAt(at).single;
    expect(b.pose.position.x, closeTo(-50, 1e-9));
    expect(b.pose.position.z, closeTo(100, 1e-9));
    expect(b.pose.rotation.yawDeg, 90);
    expect(actor.cylindersAt(at).single.p1.z, closeTo(120, 1e-9));
    expect(actor.spheresAt(at).single.center.y, closeTo(10, 1e-9));
  });

  test('tiltAbout keeps the pivot fixed', () {
    const pose = Pose(Vec3(0, -15, 201));
    const pivot = Vec3(0, 65, 156);
    final tilted = tiltAbout(pose, pivot, pitchDeg: -20);
    // The distance to the pivot is unchanged and the back end went up.
    expect((tilted.position - pivot).length, closeTo((pose.position - pivot).length, 1e-9));
    expect(tilted.position.z, greaterThan(pose.position.z));
  });

  for (final demo in demos) {
    final type = demo.type;
    group('${type.wire} demo', () {
      final tl = demo.timeline;
      final howTo = [for (final code in ['ko', 'ja', 'en']) guideFor(type, S(AppLocale.fromCode(code))).howTo.length];

      test('is the demo of its own type in every language', () {
        for (final code in ['ko', 'ja', 'en']) {
          final d = guideDemoFor(type, S(AppLocale.fromCode(code)));
          expect(d, isNotNull);
          expect(d!.type, type);
          expect(d.timeline.totalMs, tl.totalMs, reason: 'same timing in $code');
        }
      });

      test('lasts 8–40 s and every step points at a How-to item', () {
        expect(tl.totalMs, inInclusiveRange(8000, 40000));
        expect(tl.steps, isNotEmpty);
        for (final step in tl.steps) {
          expect(step, inInclusiveRange(0, howTo.reduce(math.min) - 1), reason: 'step $step');
          expect(tl.startOfStep(step), isNotNull);
        }
      });

      test('the claw and the prizes stay in the cabinet', () {
        final hw = tl.stage.fieldWidthMm / 2, hd = tl.stage.fieldDepthMm / 2;
        for (var t = 0.0; t <= tl.totalMs; t += 50) {
          final f = tl.frameAt(t);
          final tip = f.claw.tip;
          expect(tip.x.abs(), lessThanOrEqualTo(hw + 20), reason: 'claw x at $t ms');
          expect(tip.y.abs(), lessThanOrEqualTo(hd + 20), reason: 'claw y at $t ms');
          expect(tip.z, inInclusiveRange(0, tl.clawRestHeightMm - 60), reason: 'claw z at $t ms');
          expect(f.claw.openWidthMm, inInclusiveRange(0, 260), reason: 'claw width at $t ms');
          for (final entry in f.poses.entries) {
            if (f.hidden.contains(entry.key)) continue;
            final p = entry.value.position;
            expect(p.x.abs(), lessThanOrEqualTo(hw + 160), reason: '${entry.key} x at $t ms');
            expect(p.y.abs(), lessThanOrEqualTo(hd + 160), reason: '${entry.key} y at $t ms');
            expect(p.z, inInclusiveRange(-250, 700), reason: '${entry.key} z at $t ms');
            expect(p.x.isFinite && p.y.isFinite && p.z.isFinite, isTrue);
          }
        }
      });

      test('prizes do not sink into bars or platforms', () {
        // At rest (every key) the overlap must be negligible; in between,
        // interpolation may clip a little.
        for (final key in tl.keyTimes) {
          final (depth, what) = _penetration(tl.stage, tl.sceneAt(key.toDouble()));
          expect(depth, lessThanOrEqualTo(3), reason: '$what overlaps ${depth.toStringAsFixed(1)} mm at key $key ms');
        }
        for (var t = 0.0; t <= tl.totalMs; t += 50) {
          final (depth, what) = _penetration(tl.stage, tl.sceneAt(t));
          expect(depth, lessThanOrEqualTo(15), reason: '$what overlaps ${depth.toStringAsFixed(1)} mm at $t ms');
        }
      });

      test('ends with a prize dropped into the hole', () {
        final end = tl.frameAt(tl.totalMs.toDouble());
        expect(end.hidden, isNotEmpty);
      });
    });
  }
}
