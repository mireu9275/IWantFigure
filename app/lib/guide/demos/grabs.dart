/// Guide demos where the claw grabs and carries: 3-claw plush, 2-claw direct
/// grab, pile (山積み).
///
/// The plush toys are built from balls (body, head, ears ...) plus a feet
/// block that carries the label and a small tag, so the arms can be seen
/// wrapping the body, catching the neck or going through the tag.
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;

import '../../l10n/strings.dart';
import '../../models/analysis.dart';
import '../../models/scene.dart';
import '../../scene3d/timeline.dart';
import '../guide_demo.dart';

// -----------------------------------------------------------------------------
// Shared parts

/// Local offset of the tag of a [_bear] with body radius [r]: on its +X side,
/// a little below the middle of the body.
Vec3 _tagAt(double r) => Vec3(r + 4, 0, -r * 0.3);

/// Local centre of the head of a [_bear] facing [front], and its radius.
Vec3 _headAt(double r, Vec3 front) => front * 4 + Vec3(0, 0, r * 1.42);
double _headRadius(double r) => r * 0.74;

/// Depth of the feet block of a [_bear]; its front face is at
/// `r * 0.7 + _feetDepth / 2` along `front`, its bottom level with the body's.
const double _feetDepth = 34;

/// A sitting plush bear: body, head, ears, snout and arms are balls, the feet
/// are a block that carries [label], and a tag hangs on its +X side (see
/// [_tagAt]). Local origin = body centre, [r] = body radius, [front] = the
/// way the face looks (a unit vector along X or Y).
SceneActor _bear({
  required String id,
  required Pose pose,
  required String label,
  required Vec3 front,
  required double r,
}) {
  final side = Vec3(front.y.abs(), front.x.abs(), 0);
  Vec3 at(double f, double s, double z) => front * f + side * s + Vec3(0, 0, z);
  Vec3 extent(double f, double s, double z) =>
      Vec3(front.x.abs() * f + side.x * s, front.y.abs() * f + side.y * s, z);
  final headR = _headRadius(r);
  final headZ = _headAt(r, front).z;
  return SceneActor(
    id: id,
    pose: pose,
    boxes: [
      SceneBox(
        id: '${id}_feet',
        pose: Pose(at(r * 0.7, 0, -r + 13)),
        size: extent(_feetDepth, r * 1.35, 26),
        material: SceneMaterial.plush,
        label: label,
      ),
      SceneBox(id: '${id}_tag', pose: Pose(_tagAt(r)), size: const Vec3(8, 26, 34), material: SceneMaterial.marker),
    ],
    spheres: [
      SceneSphere(id: '${id}_body', center: Vec3.zero, radius: r),
      SceneSphere(id: '${id}_arm_l', center: at(r * 0.3, -r * 0.92, r * 0.12), radius: r * 0.26),
      SceneSphere(id: '${id}_arm_r', center: at(r * 0.3, r * 0.92, r * 0.12), radius: r * 0.26),
      SceneSphere(id: '${id}_head', center: _headAt(r, front), radius: headR),
      SceneSphere(id: '${id}_ear_l', center: at(0, -headR * 0.68, headZ + headR * 0.8), radius: r * 0.24),
      SceneSphere(id: '${id}_ear_r', center: at(0, headR * 0.68, headZ + headR * 0.8), radius: r * 0.24),
      SceneSphere(
        id: '${id}_snout',
        center: at(headR * 0.92, 0, headZ - headR * 0.2),
        radius: r * 0.2,
        material: SceneMaterial.cardboard,
      ),
    ],
  );
}

/// [pose] moved up or down so the lowest part of [actor] rests on the floor.
Pose _onFloor(SceneActor actor, Pose pose) {
  var low = double.infinity;
  for (final b in actor.boxesAt(pose)) {
    for (final c in b.corners()) {
      low = math.min(low, c.z);
    }
  }
  for (final ball in actor.spheresAt(pose)) {
    low = math.min(low, ball.center.z - ball.radius);
  }
  return shifted(pose, Vec3(0, 0, -low));
}

/// Half the thickness of an arm tip: how far its centre stays off a surface
/// it touches.
const double _tipGap = 4;

/// Replaces the markers of the key at [index] in [script]. A play started at
/// index `i` writes, in order: `i` aim (travel), `i + 1` lower, `i + 2`
/// close, then lift and open.
void _setMarkers(DemoScript script, int index, List<SceneMarker> markers) {
  final k = script.keys[index];
  script.keys[index] = SceneKey(
    ms: k.ms,
    claw: k.claw,
    poses: k.poses,
    hide: k.hide,
    step: k.step,
    curve: k.curve,
    markers: markers,
  );
}

/// Adds a small marker on [contact], the point the working tip goes for, to
/// the aim key of the play started at [play]. The script's own tip marker
/// assumes two arms opening along X.
void _markContact(DemoScript script, int play, Vec3 contact) => _setMarkers(
      script,
      play,
      [...?script.keys[play].markers, SceneMarker(point: contact, label: '', primary: false)],
    );

/// Clears the aim markers of the play started at [play] as the arms close:
/// on small prizes that then move under the claw centre they would hide the
/// motion.
void _clearOnClose(DemoScript script, int play) => _setMarkers(script, play + 2, const []);

// -----------------------------------------------------------------------------
// 3本爪

/// Directions of the three arms as the painter draws them (90°, 210°, 330°
/// around the centre): front (手前), back-left and back-right.
const Vec3 _armFront = Vec3(0, 1, 0);
const Vec3 _armBackRight = Vec3(0.8660254, -0.5, 0);

/// Claw centre that puts the tip of the arm pointing along [dir] on
/// [contact] when the tips are on a circle [openMm] across.
Vec3 _centerFor3(Vec3 contact, Vec3 dir, double openMm) => contact - dir * (openMm / 2);

/// Where a tip touches the back (−Y side) of a ball at [center] with radius
/// [radius] when it comes straight down [behind] mm behind the centre.
Vec3 _onBackOf(Vec3 center, double radius, double behind) {
  final r = radius + _tipGap;
  return Vec3(center.x, center.y - behind, center.z + math.sqrt(r * r - behind * behind));
}

/// The acrylic shield (シールド) in front of the plush: along X at the back
/// edge of the drop hole, whose top edge the plush tips over.
const double _shieldY = 102;
const double _shieldH = 70;
const double _shieldT = 8;

/// 3本爪: wrap the centre of mass (the plush lifts, then slips — a payout
/// machine), hook the tag, press it against the shield, then lift the far
/// side so it tips over the shield into the drop hole.
GuideDemo threeClawDemo(S s) {
  const r = 62.0;
  const open = 220.0;
  const start = Pose(Vec3(-185, -80, r));
  // It faces the player (+Y), toward the shield and the hole.
  const facing = Vec3(0, 1, 0);
  final plush = _bear(id: 'plush', pose: start, label: s.labelPrize, front: facing, r: r);
  final script = DemoScript(
    actors: [plush],
    home: const Vec3(-210, 180, 320),
    hoverZ: 320,
    openMm: open,
    closedMm: 100,
  );

  // 0: all three tips around the centre of mass, low enough to close under
  // the bulge of the belly.
  script.pause(1200, step: 0);
  final c1 = Vec3(start.position.x, start.position.y, r / 4);
  script.aim(c1, step: 0);
  script.pause(700, step: 0);

  // 1: the tips go under the belly and it lifts — then slips out (payout
  // machine) and lands a little further forward.
  const rest1 = Pose(Vec3(-185, -55, r), Rotation(yawDeg: 6));
  script.play(
    step: 1,
    center: c1,
    carryMm: 70,
    onLift: {'plush': shifted(start, const Vec3(0, 0, 70))},
    onRelease: {'plush': rest1},
  );

  // 2: タグ掛け — the back-right tip goes through the tag; closing and
  // lifting drag the plush toward the hole side.
  final tag = rest1.toWorld(_tagAt(r));
  final c2 = _centerFor3(tag, _armBackRight, open);
  const pull = Vec3(-26, 15, 0);
  final pulled = shifted(rest1, pull);
  final leftFoot = pulled.toWorld(const Vec3(-45, 0, -r));
  const rest2 = Pose(Vec3(-215, -25, r), Rotation(yawDeg: -4));
  final play2 = script.keys.length;
  script.play(
    step: 2,
    center: c2,
    closeTo: 160,
    onClose: {'plush': pulled},
    onLift: {'plush': tiltAbout(pulled, leftFoot, rollDeg: -18)},
    onRelease: {'plush': rest2},
  );
  _markContact(script, play2, tag);

  // 3: 押し — the front tip comes down on the back of the head and presses
  // on: the head slides out from under it, so the plush lurches forward,
  // slides on into the shield and leans on its top edge (it catches there).
  // The "lift" of this play goes down: the tip slides down the back of the
  // head while the plush moves `shove` forward.
  const reach = 30.0; // where the tip lands, behind the centre of the head
  const shove = 15.0;
  final head2 = rest2.toWorld(_headAt(r, facing));
  final touch = _onBackOf(head2, _headRadius(r), reach);
  final pressed = _onBackOf(head2 + const Vec3(0, shove, 0), _headRadius(r), reach + shove);
  // Upright against the shield it leans forward on its toes.
  const upright3 = Pose(Vec3(-212, 26, r));
  final toe = upright3.toWorld(const Vec3(0, r * 0.7 + _feetDepth / 2, -r));
  final rest3 = tiltAbout(upright3, toe, pitchDeg: -12);
  final play3 = script.keys.length;
  script.play(
    step: 3,
    center: _centerFor3(touch, _armFront, open),
    closeTo: open,
    carryMm: null,
    liftZ: pressed.z,
    onLift: {'plush': shifted(rest2, const Vec3(0, shove, 0))},
    onRelease: {'plush': rest3},
  );
  _markContact(script, play3, touch);

  // 4: lift the far (back) side: the plush turns over the shield's top edge
  // and drops into the hole.
  final body = rest3.position;
  final pivot = Vec3(body.x, _shieldY, _shieldH);
  // The front tip goes under the back of the belly and rises with it while
  // the plush turns about the shield's top edge.
  final under = Vec3(body.x, body.y - (r + _tipGap) * 0.77, body.z - (r + _tipGap) * 0.64);
  Pose over(double deg) => tiltAbout(rest3, pivot, pitchDeg: -deg);
  final tipUp = tiltAbout(Pose(under), pivot, pitchDeg: -40).position.z;
  final play4 = script.keys.length;
  script.play(
    step: 4,
    center: _centerFor3(under, _armFront, open),
    // Closing would pull the front tip back off the belly.
    closeTo: open,
    carryMm: null,
    liftZ: tipUp,
    onLift: {'plush': over(40)},
    onRelease: {'plush': over(80)},
  );
  _markContact(script, play4, under);
  // On top of the shield it rolls on over the front top edge, head first,
  // and drops into the hole (short steps, so it does not cut the corner).
  final frontEdge = Vec3(body.x, _shieldY + _shieldT, _shieldH);
  Pose rollOn(double deg) => tiltAbout(over(80), frontEdge, pitchDeg: -deg);
  for (final deg in const [30.0, 60.0, 90.0]) {
    script.move({'plush': rollOn(deg)}, ms: 190, step: 4, curve: Curves.linear);
  }
  script.move({'plush': shifted(rollOn(90), const Vec3(0, 15, -130))}, ms: 350, step: 4, curve: Curves.easeIn);
  script.hide({'plush'});
  script.goHome(step: 4);
  script.pause(900, step: 4);

  return GuideDemo(
    type: LayoutType.threeClaw,
    timeline: SceneTimeline(
      stage: _threeClawStage(),
      actors: [plush],
      claw: script.start,
      keys: script.keys,
      clawCount: 3,
      clawRestHeightMm: 520,
    ),
  );
}

/// Floor, drop hole in the front-left corner and its L-shaped acrylic shield.
Scene3D _threeClawStage() => const Scene3D(
      fieldWidthMm: demoFieldWidthMm,
      fieldDepthMm: demoFieldDepthMm,
      boxes: [
        SceneBox(
          id: 'shield_back',
          pose: Pose(Vec3(-210, _shieldY + _shieldT / 2, _shieldH / 2)),
          size: Vec3(180, _shieldT, _shieldH),
          material: SceneMaterial.acrylic,
        ),
        SceneBox(
          id: 'shield_side',
          pose: Pose(Vec3(-116, 180, _shieldH / 2)),
          size: Vec3(_shieldT, 140, _shieldH),
          material: SceneMaterial.acrylic,
        ),
      ],
      dropHole: SceneDropHole(xMin: -300, xMax: -120, yMin: _shieldY + _shieldT, yMax: 250),
      camera: CameraHint(yawDeg: 48, pitchDeg: 21, distanceMm: 960, target: Vec3(-190, 40, 225)),
    );

// -----------------------------------------------------------------------------
// 2本爪 直取り

/// Edge of the drop hole the plush is walked to (2本爪 直取り).
const double _directHoleX = 150;

/// 2本爪 直取り: pick a catchable part, pull the plush by its tag with the
/// left arm, watch where the tips land on the neck (it only turns a little),
/// lift the legs so it rolls over onto its back toward the hole, then hook
/// the neck of the overhanging head and drag it over the edge.
GuideDemo twoClawDirectDemo(S s) {
  const r = 50.0;
  const open = 160.0;
  const y = 100.0;
  // It sits with its back (and tag) toward the hole on the right.
  const start = Pose(Vec3(-38, y, r));
  final plush = _bear(id: 'plush', pose: start, label: s.labelPrize, front: const Vec3(-1, 0, 0), r: r);
  final script = DemoScript(actors: [plush], home: const Vec3(225, 125, 300), hoverZ: 300, openMm: open);
  Vec3 neckOf(Pose p) => p.toWorld(const Vec3(-2, 0, r * 0.86));
  Vec3 tagOf(Pose p) => p.toWorld(_tagAt(r));

  // 0: catchable parts — the neck, then the tag.
  script.pause(900, step: 0);
  script.aim(neckOf(start), step: 0);
  script.pause(600, step: 0);
  final c1 = script.centerFor(tagOf(start), Arm.left);
  script.aim(c1, arm: Arm.left, step: 0);
  script.pause(500, step: 0);

  // 1: 寄せ — the left tip in the tag drags the plush toward the hole as the
  // arms close; lifting raises its back, then it drops a little closer.
  final pulled = shifted(start, Vec3((open - script.closedMm) / 2, 0, 0));
  final frontFoot = pulled.position + Vec3(-r - 6, 0, -r);
  const rest1 = Pose(Vec3(22, y, r));
  final play1 = script.keys.length;
  script.play(
    step: 1,
    center: c1,
    arm: Arm.left,
    onClose: {'plush': pulled},
    onLift: {'plush': tiltAbout(pulled, frontFoot, rollDeg: -16)},
    onRelease: {'plush': rest1},
  );
  _clearOnClose(script, play1);

  // 2: play 1 on the neck — watch where the tips land: it lifts a little and
  // only turns (still progress).
  final c2 = neckOf(rest1);
  const rest2 = Pose(Vec3(30, y + 6, r), Rotation(yawDeg: 12));
  final play2 = script.keys.length;
  script.play(
    step: 2,
    center: c2,
    carryMm: 30,
    onLift: {'plush': shifted(rest1, const Vec3(0, 0, 30))},
    onRelease: {'plush': rest2},
  );
  _clearOnClose(script, play2);

  // 3: 持ち上げ — the left tip goes under the feet and lifts them: the plush
  // rolls over onto its back, head toward the hole.
  // (the plush faces -X, so its toes are at local -X)
  final toes = rest2.toWorld(const Vec3(-r * 0.7 - _feetDepth / 2 - _tipGap, 0, -r + 8));
  final c3 = script.centerFor(toes, Arm.left);
  final heel = rest2.toWorld(const Vec3(r * 0.6, 0, -r));
  // On its back it lies on the tag, which hangs there.
  final rest3 = _onFloor(plush, const Pose(Vec3(90, y, r), Rotation(rollDeg: 100)));
  final play3 = script.keys.length;
  script.play(
    step: 3,
    center: c3,
    arm: Arm.left,
    closeTo: open - 40,
    onClose: {'plush': tiltAbout(rest2, heel, rollDeg: 6)},
    onLift: {'plush': tiltAbout(rest2, heel, rollDeg: 32)},
    onRelease: {'plush': rest3},
  );
  _clearOnClose(script, play3);

  // 4: the head overhangs the edge — hook the neck with the left tip and
  // drag it over; it tips into the hole.
  // The tip goes into the groove between body and head, from above.
  final c4 = script.centerFor(neckOf(rest3) + const Vec3(0, 0, 26), Arm.left);
  final dragged = shifted(rest3, const Vec3(45, 0, 0));
  // Past the edge it turns about the rim of the hole and drops in; it keeps
  // turning while the claw rises and opens (no pause half over the rim).
  Pose tipped(double deg) => tiltAbout(dragged, const Vec3(_directHoleX, y, 0), rollDeg: deg);
  final play4 = script.keys.length;
  script.play(
    step: 4,
    center: c4,
    arm: Arm.left,
    carryMm: null,
    onClose: {'plush': dragged},
    onLift: {'plush': tipped(35)},
    onRelease: {'plush': tipped(80)},
  );
  _clearOnClose(script, play4);
  script.move({'plush': shifted(tipped(120), const Vec3(15, 0, -110))}, ms: 350, step: 4, curve: Curves.easeIn);
  script.hide({'plush'});
  script.goHome(step: 4);
  script.pause(900, step: 4);

  return GuideDemo(
    type: LayoutType.twoClawDirect,
    timeline: SceneTimeline(
      stage: const Scene3D(
        fieldWidthMm: demoFieldWidthMm,
        fieldDepthMm: demoFieldDepthMm,
        dropHole: SceneDropHole(xMin: _directHoleX, xMax: 300, yMin: 0, yMax: 250),
        camera: CameraHint(yawDeg: 18, pitchDeg: 20, distanceMm: 880, target: Vec3(90, 70, 222)),
      ),
      actors: [plush],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: 480,
    ),
  );
}

// -----------------------------------------------------------------------------
// 山積み

/// Top of the acrylic shelf the pile sits on; its right edge drops into the
/// hole (the downhill side of the pile).
const double _shelfTop = 70;
const double _shelfEdge = 110;

/// Radius of the round mascots in the pile.
const double _ballR = 28;

/// Centre of a ball resting on [a] and [b] (two touching balls side by side
/// along Y), turned [deg] from level toward the hole (+X): 90 = straight
/// above them, 0 = level with them on the hole side.
Vec3 _onTwo(Vec3 a, Vec3 b, double deg) {
  final m = (a + b) * 0.5;
  final half = (a - b).length / 2;
  final l = math.sqrt(4 * _ballR * _ballR - half * half);
  final t = deg * math.pi / 180;
  return m + Vec3(l * math.cos(t), 0, l * math.sin(t));
}

/// Centre of a ball rolling over the ball [a] toward the hole, [deg] from
/// level (90 = on top of it).
Vec3 _onOne(Vec3 a, double deg) {
  final t = deg * math.pi / 180;
  return a + Vec3(2 * _ballR * math.cos(t), 0, 2 * _ballR * math.sin(t));
}

/// Centre of a ball in the hollow of three touching balls.
Vec3 _onThree(Vec3 a, Vec3 b, Vec3 c) {
  final m = (a + b + c) * (1 / 3);
  final d = (a - m).length;
  return m + Vec3(0, 0, math.sqrt(4 * _ballR * _ballR - d * d));
}

/// Where a ball that fell off the edge at [y] ends up, down in the hole
/// (below the floor, just before it is hidden).
Vec3 _inHole(double y) => Vec3(_shelfEdge + 55, y, -40);

/// Centre of a ball rolling over the shelf edge at [y], [deg] down from the
/// top of the edge (0 = balanced on it, 90 = level with it).
Vec3 _overEdge(double y, double deg) {
  final t = deg * math.pi / 180;
  return Vec3(_shelfEdge + _ballR * math.sin(t), y, _shelfTop + _ballR * math.cos(t));
}

/// 山積み: round mascots heaped on a shelf next to the hole. Lift the top
/// one: it slips and rolls down the drop-side slope, taking a neighbour with
/// it (雪崩). Then push a front one over the edge with the left arm, scoop two
/// more from underneath, and finally drag out a ball at the foot of the heap
/// so the one resting on it comes down too.
GuideDemo pileDemo(S s) {
  const r = _ballR;
  const z0 = _shelfTop + r;
  const row = 2 * r * 0.8660254; // distance between rows of touching balls
  const ax = _shelfEdge - r - 4, bx = ax - row, cx = bx - row;
  const a1 = Vec3(ax, -2 * r, z0), a2 = Vec3(ax, 0, z0), a3 = Vec3(ax, 2 * r, z0);
  const b1 = Vec3(bx, -3 * r, z0), b2 = Vec3(bx, -r, z0), b3 = Vec3(bx, r, z0), b4 = Vec3(bx, 3 * r, z0);
  const c1 = Vec3(cx, -2 * r, z0), c2 = Vec3(cx, 0, z0), c3 = Vec3(cx, 2 * r, z0);
  final p1 = _onThree(a1, a2, b2), p2 = _onThree(a2, a3, b3), p3 = _onThree(b2, b3, c2);
  final q = _onThree(p1, p2, p3);

  // Orange and pink mascots, alternating (pink = the rubber-tube colour).
  var pink = false;
  SceneActor ball(String id, Vec3 at) {
    pink = !pink;
    return SceneActor(
      id: id,
      pose: Pose(at),
      spheres: [
        SceneSphere(
          id: id,
          center: Vec3.zero,
          radius: r,
          material: pink ? SceneMaterial.rubberTube : SceneMaterial.plush,
        ),
      ],
    );
  }

  final actors = [
    ball('a1', a1), ball('a2', a2), ball('a3', a3),
    ball('b1', b1), ball('b2', b2), ball('b3', b3), ball('b4', b4),
    ball('c1', c1), ball('c3', c3),
    // A boxed mascot in the back row carries the label.
    boxActor(
      id: 'box',
      pose: const Pose(Vec3(cx, 0, _shelfTop + 23)),
      size: const Vec3(40, 50, 46),
      label: s.labelPrize,
    ),
    ball('p1', p1), ball('p2', p2), ball('p3', p3), ball('q', q),
  ];
  final script = DemoScript(actors: actors, home: const Vec3(195, 0, 290), hoverZ: 290);
  Map<String, Pose> at(Map<String, Vec3> centres) => {for (final e in centres.entries) e.key: Pose(e.value)};

  // 0: read the pile — its slope runs down to the hole on the right.
  script.pause(1200, step: 0);
  script.aim(q, step: 0);
  script.pause(500, step: 0);

  // 1: hook the top one and lift: it slips out, rolls down the drop-side
  // slope and over the edge, and the one below follows (雪崩).
  final play1 = script.keys.length;
  script.play(
    step: 1,
    center: q,
    carryMm: 45,
    onLift: at({'q': q + const Vec3(0, 0, 45)}),
    onRelease: at({'q': _onTwo(p1, p2, 60)}),
  );
  _clearOnClose(script, play1);
  script.move(at({'q': _onTwo(p1, p2, 28)}), ms: 250, step: 1, curve: Curves.linear);
  script.move(at({'q': _onOne(a2, 50)}), ms: 250, step: 1, curve: Curves.linear);
  script.move(
    at({'q': const Vec3(_shelfEdge + 26, 0, 112), 'p2': _onTwo(a2, a3, 75)}),
    ms: 250,
    step: 1,
    curve: Curves.linear,
  );
  script.move(
    at({'q': _inHole(-10), 'p2': _onTwo(a2, a3, 35)}),
    ms: 350,
    step: 1,
    curve: Curves.easeIn,
  );
  script.hide({'q'});
  script.move(at({'p2': const Vec3(_shelfEdge + 30, r, 106)}), ms: 250, step: 1, curve: Curves.linear);
  script.move(at({'p2': _inHole(40)}), ms: 350, step: 1, curve: Curves.easeIn);
  script.hide({'p2'});

  // 2: the front row sits level — the left tip goes in behind the middle one
  // and pushes it downhill over the edge; the one above drops into its place.
  final push = script.centerFor(const Vec3(ax - 26, 0, z0 + 12), Arm.left);
  final play2 = script.keys.length;
  script.play(
    step: 2,
    center: push,
    arm: Arm.left,
    carryMm: null,
    onClose: at({'a2': _overEdge(0, 45)}),
    onLift: at({'a2': _inHole(0), 'p1': const Vec3(ax - 6, -8, z0 + 30)}),
    onRelease: at({'p1': a2}),
  );
  _clearOnClose(script, play2);
  script.hide({'a2'});

  // 3: すくい — the left tip goes down between two balls and, closing,
  // slides under the point where they touch; rising, it scoops both over the
  // edge together.
  final scoop = script.centerFor(const Vec3(ax - 18, r, _shelfTop + 10), Arm.left);
  final play3 = script.keys.length;
  script.play(
    step: 3,
    center: scoop,
    arm: Arm.left,
    closeTo: script.openMm - 44,
    onLift: at({
      'p1': const Vec3(_shelfEdge + 22, -6, z0 + 22),
      'a3': const Vec3(_shelfEdge + 24, 2 * r + 6, z0 + 20),
    }),
    onRelease: at({'p1': _inHole(-5), 'a3': _inHole(70)}),
  );
  _clearOnClose(script, play3);
  script.hide({'p1', 'a3'});

  // 4: break the heap rather than taking balls one by one: the left tip goes
  // in behind b3, a ball at the foot of the heap, and drags it to the edge
  // (寄せ). p3, which rested on it, loses its footing, rolls off b2 onto the
  // shelf and follows it over the edge.
  final pull = script.centerFor(b3 - const Vec3(r + _tipGap, 0, 8), Arm.left);
  final dragged = b3 + Vec3((script.openMm - script.closedMm) / 2, 0, 0);
  // p3 turned about b2 toward the gap b3 left (still touching b2), then
  // down on the shelf just in front of where b3 was.
  final offB2 = b2 + const Vec3(-3, 45, 34).normalized() * (2 * r);
  final p3Down = b3 + const Vec3(16, 2, 0);
  final play4 = script.keys.length;
  script.play(
    step: 4,
    center: pull,
    arm: Arm.left,
    carryMm: null,
    onClose: at({'b3': dragged}),
    onLift: at({'b3': _overEdge(b3.y, 30), 'p3': offB2}),
    onRelease: at({'b3': _overEdge(b3.y, 75), 'p3': p3Down}),
  );
  _clearOnClose(script, play4);
  script.move(
    at({'b3': _inHole(b3.y + 15), 'p3': Vec3(ax, p3Down.y, z0)}),
    ms: 350,
    step: 4,
    curve: Curves.easeIn,
  );
  script.hide({'b3'});
  script.move(at({'p3': _overEdge(p3Down.y, 0)}), ms: 200, step: 4, curve: Curves.linear);
  script.move(at({'p3': _overEdge(p3Down.y, 60)}), ms: 200, step: 4, curve: Curves.linear);
  script.move(at({'p3': _inHole(p3Down.y + 10)}), ms: 300, step: 4, curve: Curves.easeIn);
  script.hide({'p3'});
  script.goHome(step: 4);
  script.pause(900, step: 4);

  return GuideDemo(
    type: LayoutType.pile,
    timeline: SceneTimeline(
      stage: const Scene3D(
        fieldWidthMm: demoFieldWidthMm,
        fieldDepthMm: demoFieldDepthMm,
        boxes: [
          SceneBox(
            id: 'shelf',
            pose: Pose(Vec3((_shelfEdge - demoFieldWidthMm / 2) / 2, 0, _shelfTop / 2)),
            size: Vec3(_shelfEdge + demoFieldWidthMm / 2, demoFieldDepthMm, _shelfTop),
            material: SceneMaterial.acrylic,
          ),
        ],
        dropHole: SceneDropHole(xMin: _shelfEdge, xMax: 280, yMin: -110, yMax: 110),
        camera: CameraHint(yawDeg: 14, pitchDeg: 22, distanceMm: 790, target: Vec3(90, 0, 222)),
      ),
      actors: actors,
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: 460,
    ),
  );
}
