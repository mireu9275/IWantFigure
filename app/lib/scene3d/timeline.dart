/// Keyframed animation of a [Scene3D], used by the guide demos: rigid
/// [SceneActor]s (a prize with its ring, a ball ...) and the claw move from
/// key to key while the rest of the stage (bars, platforms, drop hole) stays
/// still. [SceneTimeline.sceneAt] turns a time into a plain [Scene3D] that
/// the existing [ScenePainter] draws.
library;

import 'package:flutter/animation.dart' show Curve, Curves;

import '../models/scene.dart';

/// A rigid group of parts moved by one [Pose].
///
/// Parts are given in the actor's local frame (origin = the actor's pose
/// position) and must be axis-aligned in it: a box's own `pose.rotation`
/// must be the identity, because the actor's rotation is applied to every
/// part.
class SceneActor {
  const SceneActor({
    required this.id,
    required this.pose,
    this.boxes = const [],
    this.cylinders = const [],
    this.spheres = const [],
  });

  final String id;

  /// Pose at the start of the timeline.
  final Pose pose;

  /// Boxes; `pose.position` is the local offset of the box centre.
  final List<SceneBox> boxes;

  /// Cylinders; `p0`/`p1` are local points.
  final List<SceneCylinder> cylinders;

  /// Spheres; `center` is a local point.
  final List<SceneSphere> spheres;

  /// The parts in the field frame when the actor is at [at].
  List<SceneBox> boxesAt(Pose at) => [
        for (final b in boxes)
          SceneBox(
            id: b.id,
            pose: Pose(at.toWorld(b.pose.position), at.rotation),
            size: b.size,
            material: b.material,
            label: b.label,
          ),
      ];

  List<SceneCylinder> cylindersAt(Pose at) => [
        for (final c in cylinders)
          SceneCylinder(
            id: c.id,
            p0: at.toWorld(c.p0),
            p1: at.toWorld(c.p1),
            radius: c.radius,
            material: c.material,
            label: c.label,
          ),
      ];

  List<SceneSphere> spheresAt(Pose at) => [
        for (final s in spheres)
          SceneSphere(id: s.id, center: at.toWorld(s.center), radius: s.radius, material: s.material),
      ];
}

/// Where the claw is: [tip] is the point between the arm tips (the
/// [SceneClaw.center]), [openWidthMm] the distance between the tips.
class ClawState {
  const ClawState(this.tip, {this.openWidthMm = 180});

  final Vec3 tip;
  final double openWidthMm;

  ClawState lerp(ClawState o, double t) =>
      ClawState(tip.lerp(o.tip, t), openWidthMm: openWidthMm + (o.openWidthMm - openWidthMm) * t);

  ClawState copyWith({Vec3? tip, double? openWidthMm}) =>
      ClawState(tip ?? this.tip, openWidthMm: openWidthMm ?? this.openWidthMm);
}

/// One key of a [SceneTimeline]. Everything reaches the values given here
/// [ms] milliseconds after the previous key; fields left null (or empty) keep
/// their previous value.
class SceneKey {
  const SceneKey({
    required this.ms,
    this.claw,
    this.poses = const {},
    this.hide = const {},
    this.step,
    this.markers,
    this.curve = Curves.easeInOut,
  }) : assert(ms >= 0);

  /// Duration of the segment that ends at this key. 0 = jump.
  final int ms;

  final ClawState? claw;

  /// Actor id → pose reached at this key.
  final Map<String, Pose> poses;

  /// Actors that disappear once this key is reached (e.g. after falling
  /// into the drop hole). They reappear when the timeline loops.
  final Set<String> hide;

  /// Index of the guide step (0-based) this segment illustrates.
  final int? step;

  /// Aim markers shown while moving to this key; `[]` clears them.
  final List<SceneMarker>? markers;

  /// Easing of this segment.
  final Curve curve;
}

/// Resolved state at one moment of a [SceneTimeline].
class SceneFrame {
  const SceneFrame({
    required this.claw,
    required this.poses,
    required this.hidden,
    required this.step,
    required this.markers,
  });

  final ClawState claw;
  final Map<String, Pose> poses;
  final Set<String> hidden;

  /// Guide step shown at this moment; -1 before the first step.
  final int step;
  final List<SceneMarker> markers;
}

/// A looping keyframe animation over a still [stage].
class SceneTimeline {
  SceneTimeline({
    required this.stage,
    required this.actors,
    required ClawState claw,
    required List<SceneKey> keys,
    this.clawCount = 2,
    this.clawRestHeightMm = 560,
  })  : assert(keys.isNotEmpty),
        _frames = _resolve(actors, claw, keys),
        _curves = [Curves.linear, for (final k in keys) k.curve],
        _ends = _endTimes(keys);

  /// Bars, platforms, drop hole, camera; actors and claw are added per frame.
  final Scene3D stage;
  final List<SceneActor> actors;
  final int clawCount;
  final double clawRestHeightMm;

  /// `_frames[0]` is the initial state, `_frames[i]` the state at key i-1.
  final List<SceneFrame> _frames;
  final List<Curve> _curves;

  /// End time of each segment; `_ends[0] == 0` for the initial state.
  final List<int> _ends;

  int get totalMs => _ends.last;
  Duration get duration => Duration(milliseconds: totalMs);

  /// Time of every key (starting with 0 for the initial state).
  List<int> get keyTimes => List.unmodifiable(_ends);

  /// Guide steps shown, in order of first appearance.
  List<int> get steps {
    final out = <int>[];
    for (final f in _frames) {
      if (f.step >= 0 && !out.contains(f.step)) out.add(f.step);
    }
    return out;
  }

  /// Start time of the first segment that shows [step], or null.
  int? startOfStep(int step) {
    for (var i = 1; i < _frames.length; i++) {
      if (_frames[i].step == step && _ends[i] > _ends[i - 1]) return _ends[i - 1];
    }
    return null;
  }

  /// State at [ms] (clamped to the timeline).
  SceneFrame frameAt(double ms) {
    final t = ms.clamp(0, totalMs.toDouble()).toDouble();
    var i = 1;
    while (i < _ends.length - 1 && t >= _ends[i]) {
      i++;
    }
    if (i >= _frames.length) return _frames.last;
    final start = _ends[i - 1], end = _ends[i];
    final from = _frames[i - 1], to = _frames[i];
    if (end <= start) return to;
    if (t >= end) return to;
    final u = _curves[i].transform(((t - start) / (end - start)).clamp(0.0, 1.0));
    return SceneFrame(
      claw: from.claw.lerp(to.claw, u),
      poses: {
        for (final a in actors) a.id: from.poses[a.id]!.lerp(to.poses[a.id]!, u),
      },
      hidden: from.hidden,
      step: to.step,
      markers: to.markers,
    );
  }

  /// The scene to draw at [ms].
  Scene3D sceneAt(double ms) => sceneFor(frameAt(ms));

  Scene3D sceneFor(SceneFrame f) {
    final boxes = [...stage.boxes];
    final cylinders = [...stage.cylinders];
    final spheres = [...stage.spheres];
    for (final a in actors) {
      if (f.hidden.contains(a.id)) continue;
      final pose = f.poses[a.id]!;
      boxes.addAll(a.boxesAt(pose));
      cylinders.addAll(a.cylindersAt(pose));
      spheres.addAll(a.spheresAt(pose));
    }
    return Scene3D(
      fieldWidthMm: stage.fieldWidthMm,
      fieldDepthMm: stage.fieldDepthMm,
      cylinders: cylinders,
      boxes: boxes,
      spheres: spheres,
      claw: SceneClaw(
        center: f.claw.tip,
        clawCount: clawCount,
        openWidthMm: f.claw.openWidthMm,
        restHeightMm: clawRestHeightMm,
      ),
      dropHole: stage.dropHole,
      markers: f.markers,
      camera: stage.camera,
    );
  }

  static List<int> _endTimes(List<SceneKey> keys) {
    final out = [0];
    for (final k in keys) {
      out.add(out.last + k.ms);
    }
    return out;
  }

  static List<SceneFrame> _resolve(List<SceneActor> actors, ClawState claw, List<SceneKey> keys) {
    var current = SceneFrame(
      claw: claw,
      poses: {for (final a in actors) a.id: a.pose},
      hidden: const {},
      step: -1,
      markers: const [],
    );
    final out = [current];
    for (final k in keys) {
      assert(k.poses.keys.every((id) => actors.any((a) => a.id == id)), 'unknown actor in ${k.poses.keys}');
      current = SceneFrame(
        claw: k.claw ?? current.claw,
        poses: {...current.poses, ...k.poses},
        hidden: {...current.hidden, ...k.hide},
        step: k.step ?? current.step,
        markers: k.markers ?? current.markers,
      );
      out.add(current);
    }
    return out;
  }
}
