/// Guide demos for the bridge setups (橋渡し): parallel bars, ハの字 and
/// stepped / tube bars.
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;

import '../../l10n/strings.dart';
import '../../models/analysis.dart';
import '../../models/scene.dart';
import '../../scene3d/timeline.dart';
import '../guide_demo.dart';

/// Bars sit well above the floor so a prize dropping between them reads as
/// falling into the chute.
const double _barZ = 150;
const double _barR = 6;

/// Pink rubber tube (ピンクチューブ) slid over the middle of a bar.
const double _tubeR = 10;

/// Camera for the bridges: looks at bar height.
const CameraHint _bridgeCamera = CameraHint(yawDeg: 32, pitchDeg: 22, distanceMm: 1400, target: Vec3(0, 0, 200));

/// Two bars along X at y = ±[gap]/2 and the drop hole between them. When
/// [tubeFromX] < [tubeToX] that stretch of both bars wears a pink rubber
/// tube of radius [_tubeR] (ピンクチューブ). With [posts] thin posts hold
/// the bar ends, so bars at different heights (段差) read at a glance.
Scene3D _bridgeStage(
  S s, {
  double gap = 130,
  double frontZ = _barZ,
  double backZ = _barZ,
  SceneMaterial material = SceneMaterial.metal,
  double tubeFromX = 0,
  double tubeToX = 0,
  bool posts = false,
  double holeHalfWidth = 200,
  CameraHint camera = _bridgeCamera,
}) {
  const hx = demoFieldWidthMm / 2;
  return Scene3D(
    fieldWidthMm: demoFieldWidthMm,
    fieldDepthMm: demoFieldDepthMm,
    cylinders: [
      SceneCylinder(
        id: 'bar_front',
        p0: Vec3(-hx, gap / 2, frontZ),
        p1: Vec3(hx, gap / 2, frontZ),
        radius: _barR,
        material: material,
        label: s.labelFrontBar,
      ),
      SceneCylinder(
        id: 'bar_back',
        p0: Vec3(-hx, -gap / 2, backZ),
        p1: Vec3(hx, -gap / 2, backZ),
        radius: _barR,
        material: material,
        label: s.labelBackBar,
      ),
      if (tubeFromX < tubeToX) ...[
        SceneCylinder(
          id: 'tube_front',
          p0: Vec3(tubeFromX, gap / 2, frontZ),
          p1: Vec3(tubeToX, gap / 2, frontZ),
          radius: _tubeR,
          material: SceneMaterial.rubberTube,
        ),
        SceneCylinder(
          id: 'tube_back',
          p0: Vec3(tubeFromX, -gap / 2, backZ),
          p1: Vec3(tubeToX, -gap / 2, backZ),
          radius: _tubeR,
          material: SceneMaterial.rubberTube,
        ),
      ],
      if (posts)
        for (final (y, z) in [(gap / 2, frontZ), (-gap / 2, backZ)])
          for (final x in const [-hx, hx])
            SceneCylinder(
              id: 'post_${x < 0 ? 'l' : 'r'}_${y > 0 ? 'front' : 'back'}',
              p0: Vec3(x, y, 0),
              p1: Vec3(x, y, z - _barR),
              radius: 4,
              material: material,
            ),
    ],
    dropHole: SceneDropHole(
      xMin: -holeHalfWidth,
      xMax: holeHalfWidth,
      yMin: -gap / 2 + _barR,
      yMax: gap / 2 - _barR,
    ),
    camera: camera,
  );
}

/// Pose of a box of [size] whose front end has slipped into the gap between
/// two bars along X: it leans [thetaDeg] front-down with its bottom face on
/// the back bar (centre at [backY], [backZ], radius [backR]) and its front
/// face against the front bar ([frontY], [frontZ], [frontR]). Returns null
/// when at that angle the box no longer touches both bars (it would fall
/// through).
Pose? bridgeWedge({
  required double thetaDeg,
  required Vec3 size,
  required double frontY,
  required double backY,
  double frontZ = _barZ,
  double backZ = _barZ,
  double frontR = _barR,
  double backR = _barR,
  double x = 0,
  double yawDeg = 0,
}) {
  final th = thetaDeg * math.pi / 180;
  // Side view (y, z): u = the box's long axis toward its front end,
  // n = the normal of its top face.
  final uy = math.cos(th), uz = -math.sin(th);
  final ny = math.sin(th), nz = math.cos(th);
  double dotN(double y, double z) => ny * y + nz * z;
  double dotU(double y, double z) => uy * y + uz * z;
  // Front-bottom edge E: on the plane r above the back bar, r behind the front bar.
  final a = backR + dotN(backY, backZ);
  final b = dotU(frontY, frontZ) - frontR;
  final ey = a * ny + b * uy, ez = a * nz + b * uz;
  // The front bar must touch the front face, the back bar the bottom face.
  final onFront = dotN(frontY - frontR * uy - ey, frontZ - frontR * uz - ez);
  final onBottom = dotU(backY + backR * ny - ey, backZ + backR * nz - ez);
  if (onFront < 0 || onFront > size.z || onBottom > 0 || onBottom < -size.y) return null;
  final cy = ey - uy * size.y / 2 + ny * size.z / 2;
  final cz = ez - uz * size.y / 2 + nz * size.z / 2;
  return Pose(Vec3(x, cy, cz), Rotation(pitchDeg: -thetaDeg, yawDeg: yawDeg));
}

/// Deepest point of any of [bars] inside a box of [size] at [pose] grown by
/// that bar's radius, in mm (0 = the box is clear of every bar). The same
/// measure as the guide demo tests, which sample each bar every 4 mm.
double _sinkInto(Pose pose, Vec3 size, List<SceneCylinder> bars) {
  // The box's own axes in the field frame: the rotation is orthonormal, so
  // local coordinates are dot products with them.
  final r = pose.rotation;
  final ax = r.apply(const Vec3(1, 0, 0));
  final ay = r.apply(const Vec3(0, 1, 0));
  final az = r.apply(const Vec3(0, 0, 1));
  var worst = 0.0;
  for (final c in bars) {
    // Points farther than a corner of the grown box cannot be inside it.
    final reach = (size * 0.5 + Vec3(c.radius, c.radius, c.radius)).length;
    final n = math.max(1, ((c.p1 - c.p0).length / 4).ceil());
    for (var i = 0; i <= n; i++) {
      final d = c.p0.lerp(c.p1, i / n) - pose.position;
      if (d.length > reach) continue;
      final dx = size.x / 2 + c.radius - d.dot(ax).abs();
      final dy = size.y / 2 + c.radius - d.dot(ay).abs();
      final dz = size.z / 2 + c.radius - d.dot(az).abs();
      if (dx > 0 && dy > 0 && dz > 0) worst = math.max(worst, math.min(dx, math.min(dy, dz)));
    }
  }
  return worst;
}

/// [pose] moved straight down (or up) until the box of [size] rests on
/// [bars]: the lowest height, coming from above, at which it does not sink
/// into any of them. Its x, y and rotation are kept.
Pose _restOn(Pose pose, Vec3 size, List<SceneCylinder> bars) {
  Pose at(double z) => Pose(Vec3(pose.position.x, pose.position.y, z), pose.rotation);
  bool clear(double z) => _sinkInto(at(z), size, bars) <= 0.2;
  // Step down until the box touches a bar, then bisect.
  var hi = pose.position.z + 200;
  var lo = hi - 20;
  while (clear(lo) && lo > pose.position.z - 400) {
    hi = lo;
    lo -= 20;
  }
  for (var i = 0; i < 16; i++) {
    final mid = (lo + hi) / 2;
    if (clear(mid)) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return at(hi);
}

/// 橋渡し (parallel), 縦ハメ: lift the back end with alternating arms; the
/// front end slips into the gap and the box stands up step by step until the
/// last corner is pushed through.
GuideDemo bridgeParallelDemo(S s) {
  const size = Vec3(150, 200, 90);
  const gap = 130.0;
  const frontY = gap / 2, backY = -gap / 2;
  const onBars = _barZ + _barR + 45; // centre height when lying on the bars
  const start = Pose(Vec3(0, -15, onBars));
  final prize = boxActor(id: 'prize', pose: start, size: size, label: s.labelPrize);
  final script = DemoScript(actors: [prize], home: const Vec3(-230, 190, 420), hoverZ: 400);
  const frontPivot = Vec3(0, frontY, _barZ + _barR);
  Pose wedge(double deg, {double yaw = 0}) =>
      bridgeWedge(thetaDeg: deg, size: size, frontY: frontY, backY: backY, yawDeg: yaw)!;

  // 0: judge the weight — just look at the setup.
  script.pause(1400, step: 0);

  // 1: aim so the right tip lands just inside the back end (端ギリギリ).
  final c1 = script.centerFor(pointOn(start, size, 0.9, 0.78, 1), Arm.right);
  script.aim(c1, arm: Arm.right, step: 1);
  script.pause(1100, step: 1);

  // 2: play 1 — the back end lifts and the box tilts on the front bar; it
  // lands a little further back.
  const rest1 = Pose(Vec3(0, -29, onBars), Rotation(yawDeg: -5));
  script.play(
    step: 2,
    center: c1,
    arm: Arm.right,
    onClose: {'prize': tiltAbout(start, frontPivot, pitchDeg: -5)},
    onLift: {'prize': tiltAbout(start, frontPivot, pitchDeg: -14)},
    onRelease: {'prize': rest1},
  );

  // 3: play 2 — the left arm takes the other back corner; the front end
  // slips off the front bar into the gap.
  final c2 = script.centerFor(pointOn(rest1, size, 0.9, 0.22, 1), Arm.left);
  final rest2 = wedge(24, yaw: -2);
  script.play(
    step: 3,
    center: c2,
    arm: Arm.left,
    onClose: {'prize': tiltAbout(rest1, frontPivot, pitchDeg: -5)},
    onLift: {'prize': tiltAbout(rest1, frontPivot, pitchDeg: -14)},
    onRelease: {'prize': rest2},
  );

  // 4: standing at an angle — lift the raised (light) back end to turn it more.
  final c3 = script.centerFor(pointOn(rest2, size, 0.95, 0.72, 1), Arm.right);
  final rest3 = wedge(42);
  script.play(
    step: 4,
    center: c3,
    arm: Arm.right,
    onLift: {'prize': wedge(34)},
    onRelease: {'prize': rest3},
  );

  // 5: push the remaining corner down: the box stands up and drops through.
  final top = pointOn(rest3, size, 1, 0.5, 1);
  final c4 = Vec3(top.x, top.y + 20, top.z - 20);
  final through = Pose(Vec3(0, rest3.position.y + 25, rest3.position.z - 60), const Rotation(pitchDeg: -84));
  script.play(step: 5, center: c4, closeTo: script.openMm, onDescend: {'prize': through});
  script.move(
    {'prize': Pose(Vec3(0, through.position.y, -120), const Rotation(pitchDeg: -88))},
    ms: 450,
    step: 5,
    curve: Curves.easeIn,
  );
  script.hide({'prize'});
  script.goHome(step: 5);
  script.pause(900, step: 5);

  return GuideDemo(
    type: LayoutType.bridgeParallel,
    timeline: SceneTimeline(
      stage: _bridgeStage(s, gap: gap),
      actors: [prize],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: 620,
    ),
  );
}

// -----------------------------------------------------------------------------
// 末広がり / ハの字

/// Half the distance between the ハの字 bars at the front (手前, narrow) and
/// the back (奥, wide) end of the field.
const double _hanojiFrontHalf = 30;
const double _hanojiBackHalf = 140;

/// Camera for ハの字: from the right and above, so the bars read as flaring
/// from the front (left of the view) toward the back and the drop hole under
/// the wide part is not hidden behind the box.
const CameraHint _hanojiCamera = CameraHint(yawDeg: 58, pitchDeg: 36, distanceMm: 1300, target: Vec3(0, 20, 235));

/// Two bars running front to back (along Y) that flare apart toward the back;
/// the drop hole is under the wide part, where the gap is wider than the box.
Scene3D _hanojiStage() {
  const hy = demoFieldDepthMm / 2;
  return const Scene3D(
    fieldWidthMm: demoFieldWidthMm,
    fieldDepthMm: demoFieldDepthMm,
    cylinders: [
      SceneCylinder(
        id: 'bar_left',
        p0: Vec3(-_hanojiFrontHalf, hy, _barZ),
        p1: Vec3(-_hanojiBackHalf, -hy, _barZ),
        radius: _barR,
      ),
      SceneCylinder(
        id: 'bar_right',
        p0: Vec3(_hanojiFrontHalf, hy, _barZ),
        p1: Vec3(_hanojiBackHalf, -hy, _barZ),
        radius: _barR,
      ),
    ],
    dropHole: SceneDropHole(xMin: -100, xMax: 100, yMin: -235, yMax: -10),
    camera: _hanojiCamera,
  );
}

/// 末広がり / ハの字: the bars flare toward the back. The box starts over the
/// narrow front end; a test play barely moves it, so it is walked backward
/// by lifting its front corners with alternating arms (each lift lets it
/// slide toward the wide end and turn a little). Both arms then lift its
/// back end so it comes down resting on the left bar with the back-right
/// corner over the gap (乗り上げ), and a tip pressing that corner tips it
/// through. つまみ上げ (for a strong arm) is skipped: the test play showed a
/// weak one.
GuideDemo bridgeHanojiDemo(S s) {
  const size = Vec3(150, 200, 90);
  final stage = _hanojiStage();
  Pose rest(Pose p) => _restOn(p, size, stage.cylinders);
  Pose flat(double x, double y, double yaw) =>
      rest(Pose(Vec3(x, y, _barZ + _barR + size.z / 2), Rotation(yawDeg: yaw)));
  Pose tilted(Pose p, {double pitch = 0, double roll = 0}) =>
      rest(Pose(p.position, p.rotation.plus(pitchDeg: pitch, rollDeg: roll)));

  final start = flat(0, 150, 0);
  final prize = boxActor(id: 'prize', pose: start, size: size, label: s.labelPrize);
  final script = DemoScript(actors: [prize], home: const Vec3(-230, 200, 420), hoverZ: 400);

  // One arm's tip lifts the front corner on its side (the corner farthest
  // from the wide end) and drags it inward as the arms close; the box slides
  // back and turns, landing at [to].
  void walk(int step, Arm arm, Pose to, {double amount = 1, double carry = 55}) {
    final from = script.pose('prize');
    final left = arm == Arm.left;
    final corner = pointOn(from, size, 0.08, left ? 0.15 : 0.85, 1);
    final side = left ? 1.0 : -1.0; // rollDeg > 0 raises the left side
    script.play(
      step: step,
      center: script.centerFor(corner, arm),
      arm: arm,
      carryMm: carry,
      onClose: {'prize': tilted(from, pitch: 2 * amount, roll: side * 1.5 * amount)},
      onLift: {'prize': tilted(from, pitch: 11 * amount, roll: side * 8 * amount)},
      onRelease: {'prize': to},
    );
  }

  // 0: check the arm power — a first lift barely moves the box.
  script.pause(300, step: 0);
  walk(0, Arm.right, flat(1, 147, 1.5), amount: 0.3, carry: 15);

  // 1: hook a front corner (far from the wide end) and pull: the left tip
  // drags that corner inward, so the box turns and slides back.
  walk(1, Arm.left, flat(5, 120, -7));

  // 2: alternate the arms; it creeps toward the wide end a little each play.
  walk(2, Arm.right, flat(-3, 92, 4));
  walk(2, Arm.left, flat(3, 64, -5));

  // 4: 乗り上げ — both arms lift the back end; it comes down further back and
  // shifted onto the left bar: the back-left corner rests on that bar, the
  // back-right corner hangs over the wide gap and only the front-right
  // corner still lies on the right bar.
  final p3 = script.pose('prize');
  final rideUp = flat(-16, 36, -10);
  script.play(
    step: 4,
    center: pointOn(p3, size, 0.86, 0.5, 0.75),
    closeTo: size.x + 8,
    onLift: {'prize': tilted(p3, pitch: -13, roll: 3)},
    onRelease: {'prize': rideUp},
  );

  // 5: the right tip comes down on the corner over the gap and presses it:
  // the box tips back-right into the gap.
  final tipped = tilted(shifted(rideUp, const Vec3(6, -14, 0)), pitch: 34, roll: 14);
  script.play(
    step: 5,
    center: script.centerFor(pointOn(rideUp, size, 0.97, 0.92, 1), Arm.right),
    arm: Arm.right,
    closeTo: script.openMm,
    onClose: {'prize': tipped},
  );
  // Once the claw is away it keeps tipping over backward, slides off the
  // bars and falls through the wide gap into the hole.
  final yaw = rideUp.rotation.yawDeg;
  final slipping = tilted(shifted(tipped, const Vec3(4, -55, 0)), pitch: 16, roll: -6);
  final falling = Pose(Vec3(0, -70, 60), Rotation(pitchDeg: 80, yawDeg: yaw));
  final inHole = Pose(Vec3(0, -85, -90), Rotation(pitchDeg: 86, yawDeg: yaw));
  script.move({'prize': slipping}, ms: 300, step: 5, curve: Curves.easeIn);
  script.move({'prize': falling}, ms: 200, step: 5, curve: Curves.linear);
  script.move({'prize': inHole}, ms: 200, step: 5, curve: Curves.linear);
  script.hide({'prize'});
  script.goHome(step: 5);
  script.pause(200, step: 5);

  return GuideDemo(
    type: LayoutType.bridgeHanoji,
    timeline: SceneTimeline(
      stage: stage,
      actors: [prize],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: 620,
    ),
  );
}

// -----------------------------------------------------------------------------
// 段差 / クロス / ピンクチューブ

/// Camera for the stepped bars: low enough that the height step between the
/// bars (and their posts) reads at a glance, aimed at the left half where the
/// box ends up.
const CameraHint _stepCamera = CameraHint(yawDeg: 50, pitchDeg: 18, distanceMm: 1300, target: Vec3(-40, 0, 220));

/// 段差 with ピンクチューブ: the back bar is higher and the middle of both
/// bars wears pink tubes. The box starts tilted across the bars on the
/// tubes; lifting its front end lets it drop into the gap, leaning upright
/// on the high back bar (真縦の斜めハマり). A ずり上げ on its lower end goes
/// nowhere on the tube, so the claw gives up sliding, drags the box sideways
/// onto bare metal (寄せ) and stands it up (縦ハメ) until it slips through.
/// The crossed-bar variant (クロス) needs a different stage and is not shown.
GuideDemo bridgeStepDemo(S s) {
  const size = Vec3(150, 200, 90);
  const gap = 130.0;
  const frontY = gap / 2, backY = -gap / 2;
  const frontZ = 130.0, backZ = 195.0; // 段差: the back bar is 65 mm higher
  const tubeFrom = -70.0, tubeTo = 130.0;
  final stage = _bridgeStage(
    s,
    gap: gap,
    frontZ: frontZ,
    backZ: backZ,
    tubeFromX: tubeFrom,
    tubeToX: tubeTo,
    posts: true,
    holeHalfWidth: 240,
    camera: _stepCamera,
  );
  Pose rest(Pose p) => _restOn(p, size, stage.cylinders);

  // Leaning front-down between the bars at [x]; it lies on the tubes while
  // any part of it is over them.
  Pose wedge(double deg, double x) {
    final onTube = x - size.x / 2 < tubeTo && x + size.x / 2 > tubeFrom;
    final r = onTube ? _tubeR : _barR;
    return bridgeWedge(
      thetaDeg: deg,
      size: size,
      frontY: frontY,
      backY: backY,
      frontZ: frontZ,
      backZ: backZ,
      frontR: r,
      backR: r,
      x: x,
    )!;
  }

  // Start: across both tubes, tilted by the step between the bars, the front
  // end just past the low front bar.
  const x0 = -40.0;
  final slope = math.atan2(backZ - frontZ, gap);
  final along = Vec3(0, math.cos(slope), -math.sin(slope)); // down the slope, toward the front
  final up = Vec3(0, math.sin(slope), math.cos(slope));
  const mid = Vec3(x0, 0, (frontZ + backZ) / 2);
  Pose across(double shift) =>
      rest(Pose(mid + along * shift + up * (_tubeR + size.z / 2), Rotation(pitchDeg: -slope * 180 / math.pi)));
  final start = across(-15);
  final prize = boxActor(id: 'prize', pose: start, size: size, label: s.labelPrize);
  final script = DemoScript(actors: [prize], home: const Vec3(-230, 190, 420), hoverZ: 420);
  final backPivot = Vec3(x0, backY, backZ) + up * _tubeR;

  // 0: hook the front end (near the low bar) and pull it up: the box turns
  // on the high bar and slides back a little; let go, its front end slips
  // off the low bar and drops into the gap, leaving it leaning on the high
  // bar.
  final hookFront = pointOn(start, size, 0.1, 0.8, 1);
  final frontUp = rest(tiltAbout(across(-25), backPivot, pitchDeg: 12));
  final upright = wedge(55, x0);
  script.pause(900, step: 0);
  script.play(
    step: 0,
    center: script.centerFor(hookFront, Arm.right),
    arm: Arm.right,
    carryMm: pointOn(frontUp, size, 0.1, 0.8, 1).z - hookFront.z,
    onClose: {'prize': rest(tiltAbout(start, backPivot, pitchDeg: 2))},
    onLift: {'prize': frontUp},
    onRelease: {'prize': upright},
  );

  // 1: ずり上げ — hook the lower (front) end and try to slide it up over the
  // high bar. The tip lifts that end a little, turning the box about its
  // contact with the high bar, but the box does not slide up...
  final th = upright.rotation.pitchDeg.abs() * math.pi / 180;
  final onHighBar = Vec3(x0, backY + _tubeR * math.sin(th), backZ + _tubeR * math.cos(th));
  final lowerEnd = pointOn(upright, size, 0.06, 0.75, 1);
  final nudged = tiltAbout(upright, onHighBar, pitchDeg: 8);
  script.play(
    step: 1,
    center: script.centerFor(lowerEnd, Arm.right),
    arm: Arm.right,
    carryMm: pointOn(nudged, size, 0.06, 0.75, 1).z - lowerEnd.z,
    onLift: {'prize': nudged},
    onRelease: {'prize': upright},
  );

  // 2: ...on the pink tube it drops straight back: nothing slides here, so
  // give up sliding.
  script.goHome(step: 2);
  script.pause(500, step: 2);

  // 3: pull (寄せ) it left along the bars onto the bare metal: the right tip
  // drags the box as the arms close.
  final bareX = tubeFrom - size.x / 2 - 15; // clear of the tube
  for (final toX in [(x0 + bareX) / 2, bareX]) {
    final from = script.pose('prize');
    script.play(
      step: 3,
      center: script.centerFor(pointOn(from, size, 0.45, 0.9, 1), Arm.right),
      arm: Arm.right,
      onClose: {'prize': wedge(55, toX)},
    );
  }

  // 4: 縦ハメ — hook the upper (back) end with the left tip and lift it: the
  // box stands up steeper and, once let go, slips between the bars.
  final hookTop = pointOn(script.pose('prize'), size, 0.92, 0.25, 1);
  final raised = wedge(65, bareX);
  script.play(
    step: 4,
    center: script.centerFor(hookTop, Arm.left),
    arm: Arm.left,
    carryMm: pointOn(raised, size, 0.92, 0.25, 1).z - hookTop.z,
    onLift: {'prize': raised},
    onRelease: {'prize': raised},
  );
  // At 65° its upper end sits on the edge of the high bar: once the claw is
  // away it slips off, turns upright between the bars and drops.
  final slipping = Pose(Vec3(bareX, -6, 180), const Rotation(pitchDeg: -84));
  final falling = Pose(Vec3(bareX, -3, 40), const Rotation(pitchDeg: -86));
  final inHole = Pose(Vec3(bareX, -2, -90), const Rotation(pitchDeg: -88));
  script.move({'prize': slipping}, ms: 250, step: 4, curve: Curves.easeIn);
  script.move({'prize': falling}, ms: 200, step: 4, curve: Curves.linear);
  script.move({'prize': inHole}, ms: 200, step: 4, curve: Curves.linear);
  script.hide({'prize'});
  script.goHome(step: 4);
  script.pause(700, step: 4);

  return GuideDemo(
    type: LayoutType.bridgeStep,
    timeline: SceneTimeline(
      stage: stage,
      actors: [prize],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: 620,
    ),
  );
}
