/// Guide demos for prizes walked off a platform — 前落とし (front drop),
/// 谷落とし (valley drop), 横落とし (side drop) — and a box standing directly
/// on the floor plate (箱 直置き).
///
/// The platforms are translucent acrylic stage boxes and the drop hole lies
/// on the floor right past the edge the prize leaves by. Each demo moves the
/// box toward that edge with one-arm pulls (寄せ), lifts or pokes until its
/// centre of mass is just short of the edge; then a press tips it past its
/// balance point and it falls into the hole.
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;

import '../../l10n/strings.dart';
import '../../models/analysis.dart';
import '../../models/scene.dart';
import '../../scene3d/timeline.dart';
import '../guide_demo.dart';

/// Clearance between an arm tip and the face it hooks or pushes.
const double _tipGap = 6;

/// Where the claw starts and ends: front left, over the player's side.
const Vec3 _home = Vec3(-230, 190, 330);

/// Height of the claw body: low enough that the body stays in view with a
/// camera close to the shelf.
const double _clawRestZ = 500;

/// How long a prize takes to turn off the edge ([_tipOffMs]) and then to
/// drop straight into the hole ([_dropMs]).
const int _tipOffMs = 250;
const int _dropMs = 300;

/// How much of a prize still shows above the floor when it disappears into
/// the hole.
const double _sunkMm = 20;

/// A flat acrylic platform (shelf, floor plate) from the floor up to [top].
SceneBox _platform(
  String id, {
  required double xMin,
  required double xMax,
  required double yMin,
  required double yMax,
  required double top,
}) =>
    SceneBox(
      id: id,
      pose: Pose(Vec3((xMin + xMax) / 2, (yMin + yMax) / 2, top / 2)),
      size: Vec3(xMax - xMin, yMax - yMin, top),
      material: SceneMaterial.acrylic,
    );

/// Centre of a drop hole on the floor.
Vec3 _holeCenter(SceneDropHole hole) => Vec3((hole.xMin + hole.xMax) / 2, (hole.yMin + hole.yMax) / 2, 0);

/// Point just behind (奥) the back face of a box at [pose]: where a tip
/// hooks to pull that part forward. [v] 0 = left … 1 = right, [w] 0 =
/// bottom … 1 = top.
Vec3 _behind(Pose pose, Vec3 size, double v, double w) => pointOn(pose, size, 1 + _tipGap / size.y, v, w);

/// Point just outside the right face of a box at [pose]; [u] 0 = front … 1
/// = back.
Vec3 _rightOf(Pose pose, Vec3 size, double u, double w) => pointOn(pose, size, u, 1 + _tipGap / size.x, w);

/// [v] in the local frame of a body turned by [r] (inverse of
/// [Rotation.apply]: undo yaw, then pitch, then roll).
Vec3 _unapply(Rotation r, Vec3 v) => Rotation(rollDeg: -r.rollDeg).apply(
      Rotation(pitchDeg: -r.pitchDeg).apply(Rotation(yawDeg: -r.yawDeg).apply(v)),
    );

/// Tilts [pose] about its own axes (pitch about its left-right axis, roll
/// about its front-back axis) keeping the body point at [pivot] in place —
/// e.g. lifting one end of a box that is turned on the shelf while the
/// opposite bottom edge stays down. Exact when the box is only yawed.
Pose _tipAbout(Pose pose, Vec3 pivot, {double pitchDeg = 0, double rollDeg = 0}) {
  final to = pose.rotation.plus(pitchDeg: pitchDeg, rollDeg: rollDeg);
  return Pose(pivot + to.apply(_unapply(pose.rotation, pose.position - pivot)), to);
}

/// Turns [pose] about a line through [pivot] parallel to a field axis
/// (pitch: X, roll: Y) — e.g. a turned box tipping over a platform edge
/// that runs along X. Unlike [tiltAbout] this is exact for any starting
/// rotation; the result is converted back to yaw / pitch / roll angles
/// close to the starting ones so the timeline interpolates smoothly (keep
/// the total turn below 90° to stay clear of gimbal lock).
Pose _turnAbout(Pose pose, Vec3 pivot, {double pitchDeg = 0, double rollDeg = 0}) {
  final delta = Rotation(pitchDeg: pitchDeg, rollDeg: rollDeg);
  Vec3 column(Vec3 e) => delta.apply(pose.rotation.apply(e));
  final ex = column(const Vec3(1, 0, 0));
  final ey = column(const Vec3(0, 1, 0));
  final ez = column(const Vec3(0, 0, 1));
  // Rotation.apply is yaw · pitch · roll; its bottom row is
  // (−cos p sin r, sin p, cos p cos r) and its middle column starts with
  // (−sin y cos p, cos y cos p).
  const toDeg = 180 / math.pi;
  final p = math.asin(ey.z.clamp(-1.0, 1.0)) * toDeg;
  final r = math.atan2(-ex.z, ez.z) * toDeg;
  final y = math.atan2(-ey.x, ey.y) * toDeg;
  double near(double a, double ref) => a + 360 * ((ref - a) / 360).roundToDouble();
  final old = pose.rotation;
  return Pose(
    pivot + delta.apply(pose.position - pivot),
    Rotation(yawDeg: near(y, old.yawDeg), pitchDeg: p, rollDeg: near(r, old.rollDeg)),
  );
}

/// Drops the actor `'prize'` (a box of [size] at [from], already clear of
/// the platform) straight down into the hole under [at] until only
/// [_sunkMm] of it shows above the floor, then hides it.
void _dropInto(DemoScript script, {required int step, required Pose from, required Vec3 size, required Vec3 at}) {
  final top = SceneBox(id: '', pose: from, size: size).corners().map((c) => c.z).reduce(math.max);
  final sunk = Pose(Vec3(at.x, at.y, from.position.z - top + _sunkMm), from.rotation);
  script.move({'prize': sunk}, ms: _dropMs, step: step, curve: Curves.linear);
  script.hide({'prize'});
}

/// The finish shared by the platform demos (押す). The claw comes down on
/// [center], a point on the prize's top, with its arms open; only then,
/// while it is down, the prize tips `tipDeg.$1` about the platform edge —
/// just past its balance point, as its centre of mass is only a little
/// short of the edge — and it keeps turning over the edge while the claw
/// rises (`tipDeg.$2`, `tipDeg.$3`) and off it (`tipDeg.$4`, easing in),
/// then drops into the hole under [hole]. [over] gives the prize turned by
/// an angle about the edge.
void _pressOver(
  DemoScript script, {
  required int step,
  required Vec3 center,
  Arm arm = Arm.both,
  required (double, double, double, double) tipDeg,
  required Pose Function(double deg) over,
  required Vec3 size,
  required Vec3 hole,
}) {
  script.play(
    step: step,
    center: center,
    arm: arm,
    closeTo: script.openMm,
    carryMm: null,
    onClose: {'prize': over(tipDeg.$1)},
    onLift: {'prize': over(tipDeg.$2)},
    onRelease: {'prize': over(tipDeg.$3)},
  );
  final off = over(tipDeg.$4);
  script.move({'prize': off}, ms: _tipOffMs, step: step, curve: Curves.easeIn);
  _dropInto(script, step: step, from: off, size: size, at: hole);
}

// -----------------------------------------------------------------------------
// 前落とし

/// Shelf top and front edge of the front drop.
const double _shelfTop = 100;
const double _shelfEdgeY = 60;

/// Drop hole in front of the shelf.
const SceneDropHole _frontHole = SceneDropHole(
  xMin: -200,
  xMax: 200,
  yMin: _shelfEdgeY + 15,
  yMax: demoFieldDepthMm / 2 - 15,
);

/// 前落とし: the box lies across a flat shelf with the drop hole in front.
/// One-arm pulls (寄せ) alternate between its ends — the right arm hooked
/// behind the left end swings the left end forward, the left arm behind the
/// right end swings the right end forward — so it zigzags toward the edge.
/// Once the front overhangs the hole and the centre of mass is just behind
/// the edge, the open claw presses the overhang down (押す) and the box tips
/// over the edge.
GuideDemo frontDropDemo(S s) {
  const size = Vec3(230, 130, 90);
  const start = Pose(Vec3(-10, -140, _shelfTop + 45)); // 45: half the box height
  final prize = boxActor(id: 'prize', pose: start, size: size, label: s.labelPrize);
  final script = DemoScript(actors: [prize], home: _home);
  Vec3 leftEnd(Pose p) => pointOn(p, size, 0.5, 0, 0);
  Vec3 rightEnd(Pose p) => pointOn(p, size, 0.5, 1, 0);

  /// One 寄せ with [arm] hooked just behind the far end (the right arm
  /// behind the left end and vice versa): closing drags that back corner
  /// sideways and the hooked end swings forward by [yawDeg] about the other
  /// end; it is raised a little while caught ([rollDeg] about the bottom
  /// edge of the other end) and the box lands [slide] mm further forward.
  /// Returns the pose it lands in.
  Pose pull({
    required int step,
    required Arm arm,
    required Pose from,
    required double yawDeg,
    required double rollDeg,
    required double slide,
  }) {
    final hooksLeft = arm == Arm.right;
    final pivot = hooksLeft ? rightEnd(from) : leftEnd(from);
    final rest = shifted(tiltAbout(from, pivot, yawDeg: yawDeg), Vec3(0, slide, 0));
    final caught = tiltAbout(from, pivot, yawDeg: yawDeg * 0.7);
    script.play(
      step: step,
      center: script.centerFor(_behind(from, size, hooksLeft ? 0.1 : 0.9, 0.5), arm),
      arm: arm,
      closeTo: 120,
      onClose: {'prize': tiltAbout(from, pivot, yawDeg: yawDeg * 0.4)},
      onLift: {'prize': _tipAbout(caught, hooksLeft ? rightEnd(caught) : leftEnd(caught), rollDeg: rollDeg)},
      onRelease: {'prize': rest},
    );
    return rest;
  }

  // 0: judge the setup, then the right arm behind the left end: the left
  // end comes forward.
  script.pause(900, step: 0);
  final rest1 = pull(step: 0, arm: Arm.right, from: start, yawDeg: -12, rollDeg: 6, slide: 8);

  // 1: then the left arm behind the right end: the box zigzags forward.
  final rest2 = pull(step: 1, arm: Arm.left, from: rest1, yawDeg: 22, rollDeg: -6, slide: 8);

  // 2: the left end is the light side: the same pull moves it farther.
  final rest3 = pull(step: 2, arm: Arm.right, from: rest2, yawDeg: -26, rollDeg: 9, slide: 14);

  // 3: one more pull squares it up: the front now hangs well over the hole
  // and the centre of mass is just behind the edge.
  final rest4 = pull(step: 3, arm: Arm.left, from: rest3, yawDeg: 14, rollDeg: -5, slide: 14);

  // 4: 押す — the open claw comes down on the middle of the overhang; the
  // box tips about the shelf edge and falls into the hole.
  final edge = Vec3(rest4.position.x, _shelfEdgeY, _shelfTop);
  final overhang = pointOn(rest4, size, 0, 0.5, 1).y - _shelfEdgeY;
  _pressOver(
    script,
    step: 4,
    center: pointOn(rest4, size, overhang / 2 / size.y, 0.5, 1),
    tipDeg: (16, 48, 66, 78),
    over: (deg) => _turnAbout(rest4, edge, pitchDeg: -deg),
    size: size,
    hole: _holeCenter(_frontHole),
  );
  script.goHome(step: 4);
  script.pause(800, step: 4);

  const hw = demoFieldWidthMm / 2, hd = demoFieldDepthMm / 2;
  return GuideDemo(
    type: LayoutType.frontDrop,
    timeline: SceneTimeline(
      stage: Scene3D(
        fieldWidthMm: demoFieldWidthMm,
        fieldDepthMm: demoFieldDepthMm,
        boxes: [_platform('shelf', xMin: -hw, xMax: hw, yMin: -hd, yMax: _shelfEdgeY, top: _shelfTop)],
        dropHole: _frontHole,
        camera: const CameraHint(yawDeg: 28, pitchDeg: 28, distanceMm: 1150, target: Vec3(-10, -20, 215)),
      ),
      actors: [prize],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: _clawRestZ,
    ),
  );
}

// -----------------------------------------------------------------------------
// 谷落とし

/// The two boards of the valley meet at a gap along X: its edges are at
/// y = ±[_valleyHalfGap], height [_valleyZ]; the boards rise away from it at
/// [_slopeDeg].
const double _valleyZ = 110;
const double _valleyHalfGap = 47;
const double _slopeDeg = 18;
const double _boardMm = 12;
const double _slope = _slopeDeg * math.pi / 180;

/// Height of the board surface above field point y (inside the gap: the
/// height of its edges).
double _boardZ(double y) => _valleyZ + math.max(0.0, y.abs() - _valleyHalfGap) * math.tan(_slope);

/// One sloped acrylic board: [front] = the one on the player's side.
SceneBox _board(String id, {required bool front}) {
  const run = demoFieldDepthMm / 2 - _valleyHalfGap; // horizontal length
  final len = run / math.cos(_slope);
  final sign = front ? 1.0 : -1.0;
  // Middle of the top surface, then half a board thickness below it.
  final top = Vec3(0, sign * (_valleyHalfGap + run / 2), _valleyZ + run / 2 * math.tan(_slope));
  final normal = Vec3(0, -sign * math.sin(_slope), math.cos(_slope));
  return SceneBox(
    id: id,
    pose: Pose(top - normal * (_boardMm / 2), Rotation(pitchDeg: sign * _slopeDeg)),
    size: Vec3(demoFieldWidthMm, len, _boardMm),
    material: SceneMaterial.acrylic,
  );
}

/// A box of [size] lying level across the valley, turned by [yawDeg]: it
/// rests on the boards with its lowest corners.
Pose _straddling(Vec3 size, double yawDeg) {
  final a = yawDeg * math.pi / 180;
  final reach = size.x / 2 * math.sin(a).abs() + size.y / 2 * math.cos(a).abs();
  return Pose(Vec3(0, 0, _boardZ(reach) + size.z / 2), Rotation(yawDeg: yawDeg));
}

/// A box of [size] lying on the front board with the middle of its bottom
/// face [s] mm up the slope from the gap edge.
Pose _onFrontBoard(Vec3 size, double s, {double yawDeg = 0}) {
  final surface = Vec3(0, _valleyHalfGap + s * math.cos(_slope), _valleyZ + s * math.sin(_slope));
  final normal = Vec3(0, -math.sin(_slope), math.cos(_slope));
  return Pose(surface + normal * (size.z / 2), Rotation(pitchDeg: _slopeDeg, yawDeg: yawDeg));
}

/// 谷落とし: two boards slope down to a gap. The box starts turned across
/// the valley; one arm turns it lengthwise, both arms lift its back end so
/// it rides up onto the front board (乗り上げ), and pokes at its front
/// corners (突き) let it slide back down a little at a time until its back
/// end drops into the gap and it falls through standing on end.
GuideDemo valleyDropDemo(S s) {
  const size = Vec3(100, 160, 50);
  final start = _straddling(size, 62);
  final prize = boxActor(id: 'prize', pose: start, size: size, label: s.labelPrize);
  final script = DemoScript(actors: [prize], home: _home);

  // 0: turned almost across the valley it could wedge sideways. The right
  // tip comes down just behind its back end, at the rear corner, and as it
  // closes it pushes that corner to the left: the box turns about its
  // middle until it lies lengthwise (the corner swings away from the tip,
  // so the tip never cuts into it).
  script.pause(1000, step: 0);
  final lengthwise = _straddling(size, 0);
  script.play(
    step: 0,
    center: script.centerFor(_behind(start, size, 0.05, 0.8), Arm.right),
    arm: Arm.right,
    closeTo: 130,
    onClose: {'prize': _straddling(size, 34)},
    onLift: {'prize': _straddling(size, 14)},
    onRelease: {'prize': lengthwise},
  );

  // 1: 乗り上げ — both tips grip the back end near its top and lift it; the
  // box rides up onto the front board with its back end just over the gap.
  final frontFoot = pointOn(lengthwise, size, 0, 0.5, 0);
  final onBoard = _onFrontBoard(size, 65);
  script.play(
    step: 1,
    center: pointOn(lengthwise, size, 0.85, 0.5, 0.8),
    closeTo: size.x + 10,
    onLift: {'prize': tiltAbout(lengthwise, frontFoot, pitchDeg: -14)},
    onRelease: {'prize': onBoard},
  );

  // 2: 突き — the left tip jabs the top of the front right corner and the
  // box slides back down toward the gap, turning a little.
  final poked = _onFrontBoard(size, 42, yawDeg: -3);
  script.play(
    step: 2,
    center: script.centerFor(pointOn(onBoard, size, 0.08, 0.9, 1), Arm.left),
    arm: Arm.left,
    closeTo: script.openMm,
    onClose: {'prize': poked},
  );

  // 3: a second, gentle poke on the other corner; the slope does the rest.
  script.play(
    step: 3,
    center: script.centerFor(pointOn(poked, size, 0.08, 0.1, 1), Arm.right),
    arm: Arm.right,
    closeTo: script.openMm,
    onClose: {'prize': _onFrontBoard(size, 22)},
  );
  // It slides to the gap edge (its centre of mass passes the edge), tips
  // over it back end first until it stands on end in the gap — in quarter
  // turns, speeding up, so it turns about the edge instead of cutting
  // through the board; the gap is just wide enough for its back top edge to
  // pass the far board — and drops through.
  final atEdge = _onFrontBoard(size, 4);
  script.move({'prize': atEdge}, ms: 500, step: 3, curve: Curves.easeIn);
  const edge = Vec3(0, _valleyHalfGap, _valleyZ);
  const upright = 90 - _slopeDeg;
  const quarterMs = [200, 100, 80, 70];
  for (var i = 0; i < quarterMs.length; i++) {
    script.move(
      {'prize': tiltAbout(atEdge, edge, pitchDeg: upright * (i + 1) / quarterMs.length)},
      ms: quarterMs[i],
      step: 3,
      curve: i == 0 ? Curves.easeIn : Curves.linear,
    );
  }
  // Straight down, its bottom face sliding past the edge of the front board.
  final standing = tiltAbout(atEdge, edge, pitchDeg: upright);
  _dropInto(script, step: 3, from: standing, size: size, at: standing.position - const Vec3(0, 1, 0));
  script.goHome(step: 3);
  script.pause(800, step: 3);

  const hw = demoFieldWidthMm / 2, hd = demoFieldDepthMm / 2;
  // The high ends of the boards rest on thin walls at the cabinet's front
  // and back; a wall stops where the board's underside starts.
  final wallTop = _boardZ(hd) - _boardMm / math.cos(_slope);
  return GuideDemo(
    type: LayoutType.valleyDrop,
    timeline: SceneTimeline(
      stage: Scene3D(
        fieldWidthMm: demoFieldWidthMm,
        fieldDepthMm: demoFieldDepthMm,
        boxes: [
          _board('board_back', front: false),
          _board('board_front', front: true),
          _platform('wall_back', xMin: -hw, xMax: hw, yMin: -hd, yMax: -hd + 10, top: wallTop),
          _platform('wall_front', xMin: -hw, xMax: hw, yMin: hd - 10, yMax: hd, top: wallTop),
        ],
        dropHole: const SceneDropHole(xMin: -250, xMax: 250, yMin: -_valleyHalfGap, yMax: _valleyHalfGap),
        camera: const CameraHint(yawDeg: 30, pitchDeg: 30, distanceMm: 1200, target: Vec3(0, 0, 210)),
      ),
      actors: [prize],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: _clawRestZ,
    ),
  );
}

// -----------------------------------------------------------------------------
// 横落とし

/// Left edge of the side-drop shelf; the drop hole lies left of it.
const double _sideEdgeX = -150;

/// Drop hole left of the side-drop shelf.
const SceneDropHole _sideHole = SceneDropHole(
  xMin: -demoFieldWidthMm / 2 + 10,
  xMax: _sideEdgeX - 10,
  yMin: -170,
  yMax: 170,
);

/// 横落とし: the drop hole is on the left, so the pulls work on the far
/// (right) end: the left arm catches its front corner, the right arm its
/// back corner, and each pull swings the box a step to the left about its
/// opposite left corner. When the left side hangs over the hole with the
/// centre of mass just inside the edge, the left tip presses the far left
/// of the top and the box rolls over the edge.
GuideDemo sideDropDemo(S s) {
  const size = Vec3(140, 220, 90);
  const start = Pose(Vec3(20, 0, _shelfTop + 45)); // 45: half the box height
  final prize = boxActor(id: 'prize', pose: start, size: size, label: s.labelPrize);
  // The camera looks from the left here, so the claw waits on the right
  // where it does not hide the box.
  final script = DemoScript(actors: [prize], home: Vec3(-_home.x, _home.y, _home.z));
  Vec3 backLeft(Pose p) => pointOn(p, size, 1, 0, 0);
  Vec3 frontLeft(Pose p) => pointOn(p, size, 0, 0, 0);

  /// One 寄せ on a corner of the right end ([front] or back): the box turns
  /// by [yawDeg] about the opposite left corner and lands [slide] further
  /// left. The front corner takes the left arm, the back corner the right
  /// (tips beside the right face). The right tip pushes its corner to the
  /// left as the arms close; the left tip catches the front corner and
  /// lifts it as the claw rises, and the box swings over as it drops back.
  /// The right-arm play aims at the top of the corner so the claw centre
  /// stays on the box's top instead of inside it.
  Pose pull({
    required int step,
    required Pose from,
    required bool front,
    required double yawDeg,
    required double slide,
  }) {
    final arm = front ? Arm.left : Arm.right;
    final pivot = front ? backLeft(from) : frontLeft(from);
    final rest = shifted(tiltAbout(from, pivot, yawDeg: yawDeg), Vec3(slide, 0, 0));
    final caught = tiltAbout(from, pivot, yawDeg: yawDeg * 0.6);
    script.play(
      step: step,
      center: script.centerFor(_rightOf(from, size, front ? 0.08 : 0.92, front ? 0.8 : 1), arm),
      arm: arm,
      closeTo: front ? 170 : 160,
      onClose: {'prize': front ? from : tiltAbout(from, pivot, yawDeg: yawDeg * 0.2)},
      onLift: {'prize': _tipAbout(caught, pointOn(caught, size, 0.5, 0, 0), rollDeg: -7)},
      onRelease: {'prize': rest},
    );
    return rest;
  }

  // 0: the right end is far from the hole: catch its front corner first.
  script.pause(900, step: 0);
  final rest1 = pull(step: 0, from: start, front: true, yawDeg: 12, slide: -12);
  // 1: then its back corner with the right arm.
  final rest2 = pull(step: 1, from: rest1, front: false, yawDeg: -24, slide: -12);
  // 2: the light side turns more and travels farther.
  final rest3 = pull(step: 2, from: rest2, front: true, yawDeg: 18, slide: -39);

  // 3: 押し — the left side hangs over the hole with the centre of mass just
  // inside the edge: the left tip presses the far left of the top and the
  // box rolls over the shelf edge.
  final edge = Vec3(_sideEdgeX, rest3.position.y, _shelfTop);
  Pose over(double deg) => _turnAbout(rest3, edge, rollDeg: -deg);
  _pressOver(
    script,
    step: 3,
    center: script.centerFor(pointOn(rest3, size, 0.5, 0.03, 1), Arm.left),
    arm: Arm.left,
    tipDeg: (7, 44, 64, 84),
    over: over,
    size: size,
    hole: Vec3(_holeCenter(_sideHole).x, rest3.position.y, 0),
  );
  script.goHome(step: 3);
  script.pause(800, step: 3);

  const hw = demoFieldWidthMm / 2, hd = demoFieldDepthMm / 2;
  return GuideDemo(
    type: LayoutType.sideDrop,
    timeline: SceneTimeline(
      stage: Scene3D(
        fieldWidthMm: demoFieldWidthMm,
        fieldDepthMm: demoFieldDepthMm,
        boxes: [_platform('shelf', xMin: _sideEdgeX, xMax: hw, yMin: -hd, yMax: hd, top: _shelfTop)],
        dropHole: _sideHole,
        camera: const CameraHint(yawDeg: -28, pitchDeg: 28, distanceMm: 1150, target: Vec3(-40, 0, 215)),
      ),
      actors: [prize],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: _clawRestZ,
    ),
  );
}

// -----------------------------------------------------------------------------
// 箱 直置き

/// Top and front edge of the floor plate the box stands on.
const double _plateTop = 40;
const double _plateEdgeY = 40;

/// Drop hole in front of the floor plate.
const SceneDropHole _plateHole = SceneDropHole(
  xMin: -200,
  xMax: 200,
  yMin: _plateEdgeY + 15,
  yMax: demoFieldDepthMm / 2 - 15,
);

/// 箱 直置き: a box lies flat on the floor plate. The claw is lined up
/// so both open tips drop into the gaps beside it; the grab lifts only the
/// light right side (the left side is the heavy one). A pull brings the
/// left end forward, a lift of the sunken back left corner (角持ち上げ)
/// walks it up to the edge over its front right corner, and pressing the
/// overhanging front left corner tips it into the hole.
GuideDemo floorBoxDemo(S s) {
  const size = Vec3(150, 130, 100);
  const start = Pose(Vec3(10, -80, _plateTop + 50)); // 50: half the box height
  final prize = boxActor(id: 'prize', pose: start, size: size, label: s.labelPrize);
  final script = DemoScript(actors: [prize], home: _home);
  Vec3 leftEnd(Pose p) => pointOn(p, size, 0.5, 0, 0);
  Vec3 rightEnd(Pose p) => pointOn(p, size, 0.5, 1, 0);

  // 0: line up the claw so the open tips fall into the gaps beside the box.
  final grip = pointOn(start, size, 0.5, 0.5, 0.6);
  script.pause(600, step: 0);
  script.aim(grip, step: 0);
  script.pause(900, step: 0);

  // 1: grab and lift: only the right side comes up — the left is heavy. The
  // left tip rides up the left face as the box tilts about its left edge.
  final rest1 = shifted(start, const Vec3(0, 4, 0));
  script.play(
    step: 1,
    center: grip,
    closeTo: size.x + 16,
    carryMm: 25,
    onLift: {'prize': _tipAbout(start, leftEnd(start), rollDeg: -6)},
    onRelease: {'prize': rest1},
  );

  // 2: 寄せ — the right tip hooked behind the left end pulls it toward the
  // drop: the box swings about its right end.
  final rest2 = shifted(tiltAbout(rest1, rightEnd(rest1), yawDeg: -18), const Vec3(0, 30, 0));
  final caught = tiltAbout(rest1, rightEnd(rest1), yawDeg: -11);
  script.play(
    step: 2,
    center: script.centerFor(_behind(rest1, size, 0.12, 0.3), Arm.right),
    arm: Arm.right,
    closeTo: 120,
    onClose: {'prize': tiltAbout(rest1, rightEnd(rest1), yawDeg: -5)},
    onLift: {'prize': _tipAbout(caught, rightEnd(caught), rollDeg: 6)},
    onRelease: {'prize': rest2},
  );

  // 3: 角持ち上げ — the right tip hooks the sunken (heavy) back left corner and
  // lifts it: the box tips forward over its front right corner and lands
  // further on, turned a little more, with its centre of mass just short of
  // the edge and the front left corner hanging over the hole.
  final frontFoot = pointOn(rest2, size, 0, 1, 0);
  final rest3 = Pose(
    Vec3(rest2.position.x + 4, _plateEdgeY - 8, rest2.position.z),
    rest2.rotation.plus(yawDeg: -6),
  );
  script.play(
    step: 3,
    center: script.centerFor(_behind(rest2, size, 0.06, 0.3), Arm.right),
    arm: Arm.right,
    closeTo: 150,
    carryMm: 60,
    onLift: {'prize': _tipAbout(_tipAbout(rest2, frontFoot, pitchDeg: -16), frontFoot, rollDeg: 6)},
    onRelease: {'prize': rest3},
  );

  // 4: press the overhanging front left corner with the right tip: the box
  // tips over the plate edge into the hole.
  final edge = Vec3(0, _plateEdgeY, _plateTop);
  _pressOver(
    script,
    step: 4,
    center: script.centerFor(pointOn(rest3, size, 0.08, 0.1, 1), Arm.right),
    arm: Arm.right,
    tipDeg: (14, 40, 58, 70),
    over: (deg) => _turnAbout(rest3, edge, pitchDeg: -deg),
    size: size,
    hole: Vec3(rest3.position.x, _holeCenter(_plateHole).y, 0),
  );
  script.goHome(step: 4);
  script.pause(800, step: 4);

  const hw = demoFieldWidthMm / 2, hd = demoFieldDepthMm / 2;
  return GuideDemo(
    type: LayoutType.floorBox,
    timeline: SceneTimeline(
      stage: Scene3D(
        fieldWidthMm: demoFieldWidthMm,
        fieldDepthMm: demoFieldDepthMm,
        boxes: [_platform('plate', xMin: -hw, xMax: hw, yMin: -hd, yMax: _plateEdgeY, top: _plateTop)],
        dropHole: _plateHole,
        camera: const CameraHint(yawDeg: 28, pitchDeg: 28, distanceMm: 1150, target: Vec3(0, -20, 200)),
      ),
      actors: [prize],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: _clawRestZ,
    ),
  );
}
