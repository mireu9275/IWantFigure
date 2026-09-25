/// Animated 3D examples for the layout guide (움직임으로 보기): for every
/// layout type a small stage (bars, platform, drop hole ...) and a scripted
/// sequence of claw plays that moves the prize the way the guide's
/// "How to aim" steps describe. Each segment points at the guide step it
/// illustrates so the page can highlight that step while it plays.
///
/// The demos are illustrations, not predictions: poses are hand-tuned to
/// read clearly, and the page says so next to the view.
///
/// Field frame as in `models/scene.dart` (mm): X right, Y toward the player
/// (手前, +), Z up; the field is 600 × 500 with the floor at z = 0.
library;

import 'package:flutter/animation.dart' show Curve, Curves;

import '../models/analysis.dart';
import '../models/scene.dart';
import '../scene3d/timeline.dart';

/// Animated example of one layout type.
class GuideDemo {
  const GuideDemo({required this.type, required this.timeline});

  final LayoutType type;
  final SceneTimeline timeline;
}

// -----------------------------------------------------------------------------
// Shared building blocks for the demo files.

/// Field size used by every demo (same as the engine defaults).
const double demoFieldWidthMm = 600;
const double demoFieldDepthMm = 500;

/// Camera most demos start with: a little from the right and above.
const CameraHint demoCamera = CameraHint(yawDeg: 32, pitchDeg: 24, distanceMm: 1350, target: Vec3(0, 0, 170));

/// Rotates [pose] by the given angles about [pivot] (a point in the field
/// frame). Exact for a single axis; for several axes at once it is an
/// approximation that is good enough for an illustration.
///
/// Signs (see [Rotation]): `pitchDeg > 0` raises the front (+Y) end,
/// `rollDeg > 0` raises the left (−X) side, `yawDeg > 0` turns clockwise
/// seen from above.
Pose tiltAbout(Pose pose, Vec3 pivot, {double pitchDeg = 0, double rollDeg = 0, double yawDeg = 0}) {
  final delta = Rotation(pitchDeg: pitchDeg, rollDeg: rollDeg, yawDeg: yawDeg);
  return Pose(
    pivot + delta.apply(pose.position - pivot),
    pose.rotation.plus(pitchDeg: pitchDeg, rollDeg: rollDeg, yawDeg: yawDeg),
  );
}

/// Point on a box of [size] at [pose], in the box's fractional coordinates
/// (see [SceneBox.pointAt]): [u] 0 = front … 1 = back, [v] 0 = left … 1 =
/// right, [w] 0 = bottom … 1 = top.
Vec3 pointOn(Pose pose, Vec3 size, double u, double v, double w) =>
    SceneBox(id: '', pose: pose, size: size).pointAt(u, v, w);

/// Moves [pose] by [delta] without turning it.
Pose shifted(Pose pose, Vec3 delta) => Pose(pose.position + delta, pose.rotation);

/// A single-box prize actor with the given [size]; [label] is drawn next to it.
SceneActor boxActor({
  required String id,
  required Pose pose,
  required Vec3 size,
  String label = '',
  SceneMaterial material = SceneMaterial.cardboard,
}) =>
    SceneActor(
      id: id,
      pose: pose,
      boxes: [SceneBox(id: id, pose: const Pose(Vec3.zero), size: size, material: material, label: label)],
    );

/// Builds the keys of a demo out of the usual claw moves, tracking where the
/// claw and every actor are so each call can start from the current state.
///
/// Times are in milliseconds. A play runs: travel over the aim point →
/// lower the arms → close → lift → open at the top. Poses passed to a play
/// are reached at the end of the named phase.
class DemoScript {
  DemoScript({
    required List<SceneActor> actors,
    required Vec3 home,
    this.hoverZ = 330,
    this.openMm = 180,
    this.closedMm = 60,
  })  : _poses = {for (final a in actors) a.id: a.pose},
        _claw = ClawState(home, openWidthMm: openMm),
        start = ClawState(home, openWidthMm: openMm);

  /// Height of the arm tips while travelling.
  final double hoverZ;

  /// Width between the arm tips when open / fully closed.
  final double openMm;
  final double closedMm;

  /// Claw state at the start (pass to [SceneTimeline.claw]).
  final ClawState start;

  final List<SceneKey> keys = [];
  final Map<String, Pose> _poses;
  ClawState _claw;

  static const int travelMs = 750;
  static const int descendMs = 650;
  static const int closeMs = 500;
  static const int liftMs = 850;
  static const int releaseMs = 500;
  static const int settleMs = 450;

  /// Current pose of an actor.
  Pose pose(String id) => _poses[id]!;

  /// Current claw state.
  ClawState get claw => _claw;

  void _key({
    required int ms,
    ClawState? claw,
    Map<String, Pose> poses = const {},
    Set<String> hide = const {},
    int? step,
    List<SceneMarker>? markers,
    Curve curve = Curves.easeInOut,
  }) {
    if (claw != null) _claw = claw;
    _poses.addAll(poses);
    keys.add(SceneKey(ms: ms, claw: claw, poses: poses, hide: hide, step: step, markers: markers, curve: curve));
  }

  /// Keeps everything still for [ms], showing [step].
  void pause(int ms, {int? step}) => _key(ms: ms, step: step);

  /// Moves actors without the claw (e.g. a prize settling, rolling or
  /// falling), showing [step]. Use `Curves.easeIn` for a free fall.
  void move(
    Map<String, Pose> poses, {
    int ms = settleMs,
    int? step,
    Set<String> hide = const {},
    Curve curve = Curves.easeInOut,
  }) =>
      _key(ms: ms, poses: poses, step: step, hide: hide, curve: curve);

  /// Makes [ids] disappear now (after they fell into the drop hole).
  void hide(Set<String> ids) => _key(ms: 0, hide: ids);

  /// Travels at hover height until the claw centre is over [center] and
  /// shows the aim marker there (plus the working tip for a one-arm play).
  void aim(Vec3 center, {Arm arm = Arm.both, int? step}) {
    final over = ClawState(Vec3(center.x, center.y, hoverZ), openWidthMm: openMm);
    final moving = (over.tip - _claw.tip).length > 1 || _claw.openWidthMm != openMm;
    _key(
      ms: moving ? travelMs : 0,
      claw: over,
      step: step,
      markers: [
        SceneMarker(point: center, label: '', arm: arm),
        if (arm != Arm.both) SceneMarker(point: tipOf(center, arm), label: '', arm: arm, primary: false),
      ],
    );
  }

  /// Where the tip of [arm] is when the claw centre is at [center] and the
  /// arms are open (2-claw: the arms open along X).
  Vec3 tipOf(Vec3 center, Arm arm) =>
      Vec3(center.x + (arm == Arm.right ? 1 : -1) * openMm / 2, center.y, center.z);

  /// Claw centre that puts the tip of [arm] on [contact].
  Vec3 centerFor(Vec3 contact, Arm arm) =>
      Vec3(contact.x - (arm == Arm.right ? 1 : -1) * openMm / 2, contact.y, contact.z);

  /// One play aimed at [center] (the point between the arm tips when they
  /// stop): lower the arms, close them to [closeTo] (default [closedMm]),
  /// lift, open at the top.
  ///
  /// Actor poses: [onDescend] is reached as the arms come down (a tip
  /// pushing the prize), [onClose] as they close, [onLift] after the claw
  /// has risen [carryMm] with the prize still caught, [onRelease] when the
  /// prize has slipped off and settled while the claw finishes rising to
  /// [liftZ] (default [hoverZ]). Pass `carryMm: null` to keep the prize
  /// caught all the way up (then [onRelease] happens as the arms open).
  void play({
    required int step,
    required Vec3 center,
    Arm arm = Arm.both,
    double? closeTo,
    double? liftZ,
    double? carryMm = 45,
    Map<String, Pose> onDescend = const {},
    Map<String, Pose> onClose = const {},
    Map<String, Pose> onLift = const {},
    Map<String, Pose> onRelease = const {},
  }) {
    aim(center, arm: arm, step: step);
    _key(ms: descendMs, claw: ClawState(center, openWidthMm: openMm), poses: onDescend, step: step);
    final closed = closeTo ?? closedMm;
    _key(ms: closeMs, claw: ClawState(center, openWidthMm: closed), poses: onClose, step: step);
    final top = ClawState(Vec3(center.x, center.y, liftZ ?? hoverZ), openWidthMm: closed);
    if (carryMm == null) {
      _key(ms: liftMs, claw: top, poses: onLift, step: step);
      _key(ms: releaseMs, claw: top.copyWith(openWidthMm: openMm), poses: onRelease, step: step);
    } else {
      final caught = ClawState(Vec3(center.x, center.y, center.z + carryMm), openWidthMm: closed);
      _key(ms: (liftMs * 0.5).round(), claw: caught, poses: onLift, step: step);
      _key(ms: liftMs, claw: top, poses: onRelease, step: step);
      _key(ms: releaseMs, claw: top.copyWith(openWidthMm: openMm), step: step);
    }
  }

  /// Grabs [actorId] at [center], lifts it with the claw, carries it over
  /// [dropAt] (a claw centre above the hole, at hover height), opens and
  /// lets the actor fall to [fallTo], then hides it. [gripMm] is the arm
  /// width while holding.
  void carry({
    required int step,
    required String actorId,
    required Vec3 center,
    required Vec3 dropAt,
    required Pose fallTo,
    Arm arm = Arm.both,
    double? gripMm,
    double? liftZ,
    int? dropStep,
  }) {
    aim(center, arm: arm, step: step);
    _key(ms: descendMs, claw: ClawState(center, openWidthMm: openMm), step: step);
    final grip = gripMm ?? closedMm;
    _key(ms: closeMs, claw: ClawState(center, openWidthMm: grip), step: step);
    // The actor follows the claw from here on.
    final offset = pose(actorId).position - center;
    final top = Vec3(center.x, center.y, liftZ ?? hoverZ);
    _key(
      ms: liftMs,
      claw: ClawState(top, openWidthMm: grip),
      poses: {actorId: Pose(top + offset, pose(actorId).rotation)},
      step: step,
    );
    final over = Vec3(dropAt.x, dropAt.y, top.z);
    _key(
      ms: travelMs + 250,
      claw: ClawState(over, openWidthMm: grip),
      poses: {actorId: Pose(over + offset, pose(actorId).rotation)},
      step: dropStep ?? step,
      markers: const [],
    );
    _key(ms: releaseMs, claw: ClawState(over, openWidthMm: openMm), step: dropStep ?? step);
    _key(ms: settleMs, poses: {actorId: fallTo}, step: dropStep ?? step, curve: Curves.easeIn);
    hide({actorId});
  }

  /// Travels back to the start position and clears the marker.
  void goHome({int? step}) {
    _key(ms: travelMs, claw: start, step: step, markers: const []);
  }
}
