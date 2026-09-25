/// Guide demos for prizes hooked by a tag, a ring or an S-hook: a thin ring
/// (ペラ輪) on a box on a ramp, a D-ring hanging on a rod (D環), a prize
/// fished with a chain and S-hook (S字フック) and a box hanging from a rod by
/// a string loop (紐吊り).
///
/// Every ring is drawn as a loop of short cylinders in the local frame of
/// its prize actor, so it moves (and turns) together with the prize.
library;

import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve, Curves;

import '../../l10n/strings.dart';
import '../../models/analysis.dart';
import '../../models/scene.dart';
import '../../scene3d/timeline.dart';
import '../guide_demo.dart';

// -----------------------------------------------------------------------------
// Loops of cylinders.

/// A closed polyline through [points] (in an actor's local frame) drawn as
/// short cylinders.
List<SceneCylinder> _loop(
  String id,
  List<Vec3> points, {
  double radius = 3,
  SceneMaterial material = SceneMaterial.metal,
}) =>
    [
      for (var i = 0; i < points.length; i++)
        SceneCylinder(
          id: '${id}_$i',
          p0: points[i],
          p1: points[(i + 1) % points.length],
          radius: radius,
          material: material,
        ),
    ];

/// [n] points on a circle around [c] with radius [r] in the plane spanned by
/// the unit vectors [a] (angle 0) and [b] (angle 90°).
List<Vec3> _circle(Vec3 c, Vec3 a, Vec3 b, double r, {int n = 16}) => [
      for (var i = 0; i < n; i++) c + a * (r * math.cos(2 * math.pi * i / n)) + b * (r * math.sin(2 * math.pi * i / n)),
    ];

// -----------------------------------------------------------------------------
// ペラ輪.

/// The ramp (坂): slope, size, and the middle of its front (lower) top edge,
/// just behind the drop hole.
const double _rampPitchDeg = -15;
const Vec3 _rampSize = Vec3(380, 300, 12);
const Vec3 _rampLip = Vec3(0, 110, 60);
const Rotation _rampTilt = Rotation(pitchDeg: _rampPitchDeg);

/// Box with the thin ring on its top face. It is wider than the open claw
/// (180 mm), so in the throwaway play both tips land on its top.
const Vec3 _peraBoxSize = Vec3(210, 110, 80);

/// ペラ輪: radius, band, how far it leans back from upright, and where it is
/// fixed on the top face (local y of its lowest point).
const double _peraR = 36;
const double _peraBand = 3.5;
const double _peraLeanDeg = 50;
const double _peraBaseY = 22;

/// Unit vector from the ring's base toward its centre, in the box frame.
final Vec3 _peraLean = Vec3(0, -math.sin(_peraLeanDeg * math.pi / 180), math.cos(_peraLeanDeg * math.pi / 180));

/// Centre of the ring hole in the box frame.
final Vec3 _peraHole = Vec3(0, _peraBaseY, _peraBoxSize.z / 2 + _peraBand) + _peraLean * _peraR;

SceneActor _peraPrize(S s, Pose pose) => SceneActor(
      id: 'prize',
      pose: pose,
      boxes: [SceneBox(id: 'prize', pose: const Pose(Vec3.zero), size: _peraBoxSize, label: s.labelPrize)],
      // The ring plane holds the X axis (the direction the tips close in) and
      // the lean, so its hole faces up and toward the player.
      cylinders: _loop(
        'pera_ring',
        _circle(_peraHole, _peraLean * -1, const Vec3(1, 0, 0), _peraR, n: 18),
        radius: _peraBand,
        material: SceneMaterial.rubberTube,
      ),
    );

/// Pose of the box lying on the ramp with its centre [along] mm up the slope
/// from the lip (negative = past the lip), moved [x] sideways and turned
/// [yawDeg].
Pose _onRamp(double along, {double x = 0, double yawDeg = 0}) {
  final up = _rampTilt.apply(const Vec3(0, -1, 0));
  final normal = _rampTilt.apply(const Vec3(0, 0, 1));
  return Pose(
    _rampLip + Vec3(x, 0, 0) + up * along + normal * (_peraBoxSize.z / 2),
    Rotation(pitchDeg: _rampPitchDeg, yawDeg: yawDeg),
  );
}

/// ペラ輪 on a ramp: the first play only shows where the tips come down;
/// then one tip is aimed right into the ring hole. Each time it catches, the
/// rising claw lifts the box by the ring until the thin ring slips off, and
/// the box lands further down the ramp. A tip that lands on the ring does
/// nothing, so the next aim pulls a little (寄せ). Repeating the same spot
/// brings the box over the lip into the drop hole.
GuideDemo ringPeraDemo(S s) {
  const lift = 55.0; // how far the ring lifts the box while caught
  const carry = lift + 15; // the tip rises this much before the ring slips
  final start = _onRamp(150);
  final prize = _peraPrize(s, start);
  final script = DemoScript(actors: [prize], home: const Vec3(-190, 170, 310), hoverZ: 310);
  Vec3 hole(Pose p) => p.toWorld(_peraHole);
  // The right tip enters the hole; closing moves it to the left side of the
  // loop, which then hangs on it.
  final closeTo = script.openMm - 2 * (_peraR - _peraBand - 4);

  // 0: throwaway play aimed at the ring (the claw centre just in front of
  // it): both tips land on the top, one on each side of the ring, close in
  // front of it and come up empty. Nothing moves, but now we know where the
  // tips land.
  script.pause(800, step: 0);
  script.play(step: 0, center: pointOn(start, _peraBoxSize, 0.2, 0.5, 1));

  // 1: move the claw so the right tip comes down right over the ring hole.
  final c1 = script.centerFor(hole(start), Arm.right);
  script.aim(c1, arm: Arm.right, step: 1);
  script.pause(1000, step: 1);

  // 2: the tip goes into the hole; closing and rising lift the box by the
  // ring until it slips off, and the box lands further down the ramp.
  final rest1 = _onRamp(105);
  script.play(
    step: 2,
    center: c1,
    arm: Arm.right,
    closeTo: closeTo,
    carryMm: carry,
    onLift: {'prize': shifted(start, const Vec3(0, 0, lift))},
    onRelease: {'prize': rest1},
  );

  // 3: the next tip lands on the ring instead of in it — nothing moves.
  // Aimed with a slight pull (寄せ), the tip slips in and the ring catches.
  final onRing = hole(rest1) + rest1.rotation.apply(_peraLean) * (_peraR + _peraBand + 4);
  script.play(step: 3, center: script.centerFor(onRing, Arm.right), arm: Arm.right, closeTo: closeTo);
  const pull = Vec3(8, 0, 0); // aim a little past the hole centre
  final pulled = _onRamp(105, x: -10, yawDeg: -5); // the ring drags the box toward the claw
  final rest2 = _onRamp(60, x: -10, yawDeg: -5);
  script.play(
    step: 3,
    center: script.centerFor(hole(rest1) + pull, Arm.right),
    arm: Arm.right,
    closeTo: closeTo,
    carryMm: carry,
    onClose: {'prize': pulled},
    onLift: {'prize': shifted(pulled, const Vec3(0, 0, lift))},
    onRelease: {'prize': rest2},
  );

  // 4: the same spot again: this time the box lands on the lip, tips over
  // and falls into the drop hole.
  final tipping = tiltAbout(_onRamp(-8, x: -10, yawDeg: -5), _rampLip, pitchDeg: -28);
  script.play(
    step: 4,
    center: script.centerFor(hole(rest2), Arm.right),
    arm: Arm.right,
    closeTo: closeTo,
    carryMm: carry,
    onLift: {'prize': shifted(rest2, const Vec3(0, 0, lift))},
    onRelease: {'prize': tipping},
  );
  script.move(
    {'prize': Pose(_rampLip + const Vec3(-10, 70, -140), const Rotation(pitchDeg: -75, yawDeg: -5))},
    ms: 450,
    step: 4,
    curve: Curves.easeIn,
  );
  script.hide({'prize'});
  script.goHome(step: 4);
  script.pause(900, step: 4);

  return GuideDemo(
    type: LayoutType.ringPera,
    timeline: SceneTimeline(
      stage: _rampStage(),
      actors: [prize],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: 450,
    ),
  );
}

/// The ramp on four legs, sloping down toward the drop hole in front of it.
Scene3D _rampStage() {
  final up = _rampTilt.apply(const Vec3(0, -1, 0));
  final normal = _rampTilt.apply(const Vec3(0, 0, 1));
  final center = _rampLip + up * (_rampSize.y / 2) - normal * (_rampSize.z / 2);
  const hx = 175.0;
  Vec3 under(double s, double x) => _rampLip + Vec3(x, 0, 0) + up * s - normal * _rampSize.z;
  return Scene3D(
    fieldWidthMm: demoFieldWidthMm,
    fieldDepthMm: demoFieldDepthMm,
    boxes: [
      SceneBox(
        id: 'ramp',
        pose: Pose(center, _rampTilt),
        size: _rampSize,
        material: SceneMaterial.acrylic,
      ),
    ],
    cylinders: [
      for (final s in [12.0, _rampSize.y - 12])
        for (final x in [-hx, hx])
          SceneCylinder(
            id: 'leg_${s.round()}_${x.round()}',
            p0: Vec3(under(s, x).x, under(s, x).y, 0),
            p1: under(s, x),
            radius: 5,
          ),
    ],
    dropHole: SceneDropHole(xMin: -160, xMax: 160, yMin: _rampLip.y + 6, yMax: 245),
    camera: const CameraHint(yawDeg: 36, pitchDeg: 22, distanceMm: 820, target: Vec3(0, 0, 215)),
  );
}

// -----------------------------------------------------------------------------
// D環 / Oリング.

/// Height of the rod the D-ring hangs on, its radius and where it ends
/// (above the drop hole).
const double _rodZ = 250;
const double _rodR = 6;
const double _rodEndY = 30;

/// D-ring: half width, height of the straight sides below the arc, band radius.
const double _dHalfW = 44;
const double _dSide = 14;
const double _dBand = 4.5;

/// Prize hanging under the D-ring (a flat package, broad face to the player).
const Vec3 _dPrizeSize = Vec3(140, 40, 110);

/// Local frame of the D-ring prize: origin = middle of the ring's top bar,
/// which rests on the rod. The ring lies in the local XZ plane (crosswise to
/// the rod), the strap and the prize hang below it.
const double _dStrapTop = -(_dHalfW + _dSide) + _dBand;
const double _dStrapH = 18;
const double _dPrizeTop = _dStrapTop - _dStrapH;

SceneActor _dRingPrize(S s, Pose pose) {
  // Arc over the top (the part that rests on the rod), straight sides and the
  // flat bar the strap goes through.
  final points = <Vec3>[
    for (var i = 0; i <= 10; i++)
      Vec3(_dHalfW * math.cos(math.pi * i / 10), 0, -_dHalfW + _dHalfW * math.sin(math.pi * i / 10)),
    const Vec3(-_dHalfW, 0, -_dHalfW - _dSide),
    const Vec3(_dHalfW, 0, -_dHalfW - _dSide),
  ];
  return SceneActor(
    id: 'prize',
    pose: pose,
    cylinders: _loop('d_ring', points, radius: _dBand),
    boxes: [
      const SceneBox(
        id: 'd_strap',
        pose: Pose(Vec3(0, 0, _dStrapTop - _dStrapH / 2)),
        size: Vec3(26, 6, _dStrapH),
        material: SceneMaterial.plush,
      ),
      SceneBox(
        id: 'prize',
        pose: Pose(Vec3(0, 0, _dPrizeTop - _dPrizeSize.z / 2)),
        size: _dPrizeSize,
        label: s.labelPrize,
      ),
    ],
  );
}

/// Pose of the D-ring prize hanging on the rod at [y], turned [yawDeg].
Pose _onRod(double y, {double yawDeg = 0}) =>
    Pose(Vec3(0, y, _rodZ + _rodR + _dBand), Rotation(yawDeg: yawDeg));

/// [ring] with the prize swung [swingDeg] about the point where the ring
/// rests on the rod (> 0 = the prize swings toward the player).
Pose _swung(Pose ring, double swingDeg) =>
    tiltAbout(ring, ring.position - const Vec3(0, 0, _dBand), pitchDeg: swingDeg);

/// D環 / Oリング: the ring hangs on a rod that sticks out over the drop hole.
/// A first play checks the arm power, then the tips land on the outside of
/// the ring, alternating left and right, and the closing arms shove it along
/// the rod. Once the prize has turned lengthwise, a tip pushes the ring from
/// behind to the end of the rod; it teeters there and slides off.
GuideDemo ringDDemo(S s) {
  final start = _onRod(-140);
  final prize = _dRingPrize(s, start);
  final script = DemoScript(actors: [prize], home: const Vec3(-190, 150, 340), hoverZ: 340);
  const midZ = -_dHalfW; // centre of the arc, where the ring is widest

  // 0: power check — grab the ring itself: it comes up off the rod a little,
  // so the arm is strong enough; it lands a bit further along.
  script.pause(900, step: 0);
  final rest0 = _onRod(-128, yawDeg: 4);
  script.play(
    step: 0,
    center: start.toWorld(const Vec3(0, 0, midZ)),
    closeTo: 2 * (_dHalfW + _dBand + 4),
    carryMm: 48,
    onLift: {'prize': shifted(start, const Vec3(0, 0, 30))},
    onRelease: {'prize': rest0},
  );

  // Claw centre that puts the tip of [arm] just outside that side of the
  // ring (and a little behind it), where closing shoves the ring forward.
  Vec3 outerEdge(Pose ring, Arm arm) {
    final side = arm == Arm.right ? 1.0 : -1.0;
    return script.centerFor(ring.toWorld(Vec3(side * (_dHalfW + 14), -8, midZ + 4)), arm);
  }

  // 1: aim at the outer edge of the ring, not its centre.
  final c1 = outerEdge(rest0, Arm.left);
  script.aim(c1, arm: Arm.left, step: 1);
  script.pause(900, step: 1);

  // 2: left tip — the closing arm shoves the left side forward (the ring
  // turns and slides along the rod); then the right tip on the right side.
  const closeTo = 136.0;
  final rest1 = _onRod(-92, yawDeg: -18);
  script.play(step: 2, center: c1, arm: Arm.left, closeTo: closeTo, onClose: {'prize': rest1});
  final rest2 = _onRod(-56, yawDeg: 10);
  script.play(step: 2, center: outerEdge(rest1, Arm.right), arm: Arm.right, closeTo: closeTo, onClose: {'prize': rest2});

  // 3: left again — only the closing moves it, nothing is lifted. The
  // prize ends up turned lengthwise along the rod.
  final rest3 = _onRod(-18, yawDeg: -48);
  script.play(step: 3, center: outerEdge(rest2, Arm.left), arm: Arm.left, closeTo: closeTo, onClose: {'prize': rest3});

  // 4: the left tip comes down behind the middle of the ring and the
  // closing arm pushes it (押し) to the very end of the rod, the prize
  // swinging forward. It teeters there while the claw rises, slips off the
  // end as the arms open and falls into the hole.
  final c4 = script.centerFor(rest3.toWorld(const Vec3(0, -16, midZ + 6)), Arm.left);
  Pose atEnd(double past) => _onRod(_rodEndY + past, yawDeg: -50);
  final slipping = shifted(_swung(atEnd(8), 16), const Vec3(0, 0, -12));
  script.play(
    step: 4,
    center: c4,
    arm: Arm.left,
    closeTo: 120,
    carryMm: null,
    onClose: {'prize': _swung(atEnd(-6), 12)},
    onLift: {'prize': _swung(atEnd(-2), -5)},
    onRelease: {'prize': slipping},
  );
  // Falls until the top of the ring is below the floor.
  final fell = _swung(atEnd(30), 30);
  script.move(
    {'prize': Pose(Vec3(fell.position.x, fell.position.y, -20), fell.rotation)},
    ms: 450,
    step: 4,
    curve: Curves.easeIn,
  );
  script.hide({'prize'});
  script.goHome(step: 4);
  script.pause(900, step: 4);

  return GuideDemo(
    type: LayoutType.ringD,
    timeline: SceneTimeline(
      stage: _rodStage(),
      actors: [prize],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: 490,
    ),
  );
}

/// The rod along Y from a post at the back to its free end above the drop hole.
Scene3D _rodStage() {
  const backY = -demoFieldDepthMm / 2 + 8;
  return const Scene3D(
    fieldWidthMm: demoFieldWidthMm,
    fieldDepthMm: demoFieldDepthMm,
    cylinders: [
      SceneCylinder(id: 'post', p0: Vec3(0, backY, 0), p1: Vec3(0, backY, _rodZ + 30), radius: 10),
      SceneCylinder(id: 'rod', p0: Vec3(0, backY, _rodZ), p1: Vec3(0, _rodEndY, _rodZ), radius: _rodR),
    ],
    dropHole: SceneDropHole(xMin: -130, xMax: 130, yMin: -40, yMax: 240),
    camera: CameraHint(yawDeg: 50, pitchDeg: 16, distanceMm: 820, target: Vec3(0, -40, 240)),
  );
}

// -----------------------------------------------------------------------------
// S字フック.

/// S-hook in its own frame (origin = end of the claw rod, where the chain
/// starts): centre and radius of the lower bowl, whose tip points up at the
/// back (−Y); its lowest point, where a caught ring rests; the band radius.
const double _hookBowlY = -8;
const double _hookBowlZ = -100;
const double _hookBowlR = 18;
const double _hookBottomZ = _hookBowlZ - _hookBowlR;
const double _hookBand = 2.5;

/// Height of the claw tip while travelling. High enough that a prize
/// hanging from the hook clears the floor by about 100 mm.
const double _hookHoverZ = 400;

/// Prize fished with the hook: a box with an O-ring on a short strap on its
/// top, the ring facing the player.
const double _fishBoxH = 100;
const Vec3 _fishBoxSize = Vec3(120, 80, _fishBoxH);
const double _fishR = 34;
const double _fishBand = 4;
const double _fishRingAboveTop = 46; // ring centre above the top face
const double _fishRingZ = _fishBoxH / 2 + _fishRingAboveTop; // … above the box centre
const Vec3 _fishStrapSize = Vec3(22, 6, 16);

/// The O-ring standing above a box whose top face centre is at [top] (in the
/// frame the parts are built in), facing the player; [id] prefixes the part
/// ids. Its lower end sits on the strap from [_fishStrap].
List<SceneCylinder> _fishRing(String id, Vec3 top) => _loop(
      '${id}_ring',
      _circle(top + const Vec3(0, 0, _fishRingAboveTop), const Vec3(0, 0, -1), const Vec3(1, 0, 0), _fishR, n: 18),
      radius: _fishBand,
    );

/// The short strap between the top face centre [top] and the ring.
SceneBox _fishStrap(String id, Vec3 top) =>
    SceneBox(id: '${id}_strap', pose: Pose(top + Vec3(0, 0, _fishStrapSize.z / 2)), size: _fishStrapSize);

/// Where the prize hangs from the claw tip while the ring rests in the bowl
/// (before any swing).
const Vec3 _hangOffset = Vec3(0, _hookBowlY, _hookBottomZ + _hookBand + _fishBand - (_fishRingZ + _fishR));

/// Chain of three links and the S-hook, all in the hook's frame.
SceneActor _hookActor(Vec3 at) {
  List<Vec3> link(double z, {required bool facing}) => _circle(
        Vec3(0, 0, z),
        const Vec3(0, 0, 1),
        facing ? const Vec3(1, 0, 0) : const Vec3(0, 1, 0),
        7,
        n: 10,
      );
  double rad(int deg) => deg * math.pi / 180;
  // Upper curl (hangs on the last link), the spine running down the other
  // way, and the lower bowl ending in the tip.
  final s = <Vec3>[
    for (var a = -60; a <= 225; a += 25) Vec3(0, 9 * math.cos(rad(a)), -50 + 9 * math.sin(rad(a))),
    for (var a = 10; a >= -180; a -= 19)
      Vec3(0, _hookBowlY + _hookBowlR * math.cos(rad(a)), _hookBowlZ + _hookBowlR * math.sin(rad(a))),
    const Vec3(0, _hookBowlY - _hookBowlR, _hookBowlZ + 16),
  ];
  return SceneActor(
    id: 'hook',
    pose: Pose(at),
    cylinders: [
      ..._loop('chain_0', link(-7, facing: true), radius: 1.8),
      ..._loop('chain_1', link(-20, facing: false), radius: 1.8),
      ..._loop('chain_2', link(-33, facing: true), radius: 1.8),
      for (var i = 0; i + 1 < s.length; i++) SceneCylinder(id: 's_hook_$i', p0: s[i], p1: s[i + 1], radius: _hookBand),
    ],
  );
}

/// Box with an O-ring on a short strap; origin = box centre.
SceneActor _fishPrize(S s, Pose pose) => SceneActor(
      id: 'prize',
      pose: pose,
      boxes: [
        SceneBox(
          id: 'prize',
          pose: const Pose(Vec3.zero),
          size: _fishBoxSize,
          material: SceneMaterial.plush,
          label: s.labelPrize,
        ),
        _fishStrap('prize', const Vec3(0, 0, _fishBoxH / 2)),
      ],
      cylinders: _fishRing('prize', const Vec3(0, 0, _fishBoxH / 2)),
    );

/// Keys of the S-hook demo. The hook always hangs from the claw tip, turned
/// by the current swing; while [hanging], the prize hangs from the hook and
/// swings with it.
class _HookRun {
  _HookRun(this.tip, this.prize);

  final List<SceneKey> keys = [];
  Vec3 tip;
  Rotation swing = Rotation.identity;
  Pose prize;
  bool hanging = false;

  /// Everything reaches the given state [ms] after the previous key.
  void key(
    int ms, {
    Vec3? to,
    Rotation? swing,
    Pose? prize,
    int? step,
    List<SceneMarker>? markers,
    Set<String> hide = const {},
    Curve curve = Curves.easeInOut,
  }) {
    tip = to ?? tip;
    this.swing = swing ?? this.swing;
    if (hanging) {
      this.prize = Pose(tip + this.swing.apply(_hangOffset), this.swing);
    } else if (prize != null) {
      this.prize = prize;
    }
    keys.add(SceneKey(
      ms: ms,
      claw: ClawState(tip, openWidthMm: 0),
      poses: {'hook': Pose(tip, this.swing), 'prize': this.prize},
      hide: hide,
      step: step,
      markers: markers,
      curve: curve,
    ));
  }

  /// A short tap of the controls toward [to]: the hook trails behind while
  /// moving and swings past when it stops, dying down.
  void tap(Vec3 to, {required int step}) {
    final d = to - tip;
    final len = d.length;
    // Swing toward the direction of travel: +Y is pitch > 0, +X is roll < 0.
    Rotation toward(double deg) => Rotation(pitchDeg: deg * d.y / len, rollDeg: -deg * d.x / len);
    key(550, to: to, swing: toward(-10), step: step, markers: const []);
    key(380, swing: toward(24), step: step);
    key(380, swing: toward(-15), step: step);
    key(340, swing: toward(8), step: step);
    key(300, swing: Rotation.identity, step: step);
  }
}

/// S字フック (釣り): a chain with an S-hook replaces the claw. Short taps
/// make the hook swing wide; aimed just in front of the ring, it goes down
/// in front, slides back and its tip passes through the ring. Caught only
/// by the tip, the ring slips off on the way up; with the bowl deep under
/// the ring it lifts the prize, carries it to the hole and the prize comes
/// off when the hook swings there.
GuideDemo hookSDemo(S s) {
  const home = Vec3(-200, 120, _hookHoverZ);
  const start = Pose(Vec3(40, -60, _fishBoxH / 2));
  final prize = _fishPrize(s, start);
  final hook = _hookActor(home);
  final run = _HookRun(home, start);
  final ring = start.toWorld(const Vec3(0, 0, _fishRingZ));
  // Height of the claw tip that puts the bowl 14 mm below the ring centre
  // (the hook tip then stays under the top of the ring), and the tip
  // positions in front of the ring, just through it and deep in it.
  final low = ring.z - 14 - _hookBottomZ;
  final front = Vec3(ring.x, ring.y + 36, low);
  final shallow = Vec3(ring.x, ring.y + 18, low);
  final deep = Vec3(ring.x, ring.y + 6, low);
  // The bowl meets the top of the ring when the claw tip is this high.
  final contact = ring.z + _fishR - _fishBand - _hookBand - _hookBottomZ;
  final aimMarker = [SceneMarker(point: Vec3(ring.x, ring.y + 10, ring.z + 20), label: '')];

  // 0: short taps toward the prize - the hook swings wide after each stop.
  run.key(700, step: 0);
  run.tap(const Vec3(-70, 40, _hookHoverZ), step: 0);
  run.tap(Vec3(front.x, front.y, _hookHoverZ), step: 0);

  // 1: aimed just in front of the ring: the hook goes down in front of it
  // and slides back so its tip passes through the ring - but only the tip.
  run.key(700, step: 1, markers: aimMarker);
  run.key(650, to: front, swing: const Rotation(pitchDeg: 4), step: 1, markers: const []);
  run.key(450, to: shallow, swing: Rotation.identity, step: 1);
  // On the way up the ring rides on the very tip and slips off.
  run.key(500, to: shallow + Vec3(0, 0, contact - low + 18), prize: shifted(start, const Vec3(0, -4, 16)), step: 1);
  run.key(
    420,
    to: shallow + Vec3(0, 0, contact - low + 50),
    swing: const Rotation(pitchDeg: 10),
    prize: start,
    step: 1,
  );
  run.key(400, to: Vec3(front.x, front.y, _hookHoverZ), swing: Rotation.identity, step: 1);

  // 3: again, but slide on until the bowl sits deep under the ring before
  // lifting; then the prize comes up with the hook and is carried over the
  // hole.
  run.key(500, step: 3, markers: aimMarker);
  run.key(650, to: front, step: 3, markers: const []);
  run.key(600, to: deep, step: 3);
  run.key(600, step: 3);
  run.key(300, to: Vec3(deep.x, deep.y, contact), step: 3);
  run.hanging = true;
  run.key(850, to: Vec3(deep.x, deep.y, _hookHoverZ), step: 3);
  run.key(1100, to: home, swing: const Rotation(pitchDeg: -8, rollDeg: -6), step: 3);
  // It swings past over the hole; the ring slides off the tip.
  run.key(420, swing: const Rotation(pitchDeg: 12, rollDeg: 9), step: 3);
  run.hanging = false;
  // Falls until the top of the ring is below the floor.
  final fell = Pose(
    Vec3(run.prize.position.x, run.prize.position.y, -(_fishRingZ + _fishR + _fishBand) - 10),
    const Rotation(pitchDeg: 20, rollDeg: 12),
  );
  run.key(450, swing: Rotation.identity, prize: fell, step: 3, curve: Curves.easeIn);
  run.key(0, hide: {'prize'});
  run.key(900, step: 3);

  return GuideDemo(
    type: LayoutType.hookS,
    timeline: SceneTimeline(
      stage: _fishStage(),
      actors: [hook, prize],
      claw: const ClawState(home, openWidthMm: 0),
      keys: run.keys,
      clawRestHeightMm: _hookHoverZ + 100,
    ),
  );
}

/// Another prize with a ring at the back right and the drop hole at the
/// front left, under the hook's home position.
Scene3D _fishStage() {
  const size = Vec3(110, 80, 90);
  const other = Vec3(195, -135, 45);
  final top = other + Vec3(0, 0, size.z / 2);
  return Scene3D(
    fieldWidthMm: demoFieldWidthMm,
    fieldDepthMm: demoFieldDepthMm,
    boxes: [const SceneBox(id: 'other', pose: Pose(other), size: size), _fishStrap('other', top)],
    cylinders: _fishRing('other', top),
    dropHole: const SceneDropHole(xMin: -290, xMax: -110, yMin: 50, yMax: 240),
    camera: const CameraHint(yawDeg: 36, pitchDeg: 20, distanceMm: 900, target: Vec3(-60, -10, 250)),
  );
}

// -----------------------------------------------------------------------------
// 紐吊り.

/// String loop (紐): band radius, radius of the loose arc that lies over the
/// rod, and length of the two strands from the arc down to the knot.
const double _strR = 2;
const double _strArcR = 20;
const double _strLen = 70;

/// Local frame of the string prize: origin = top of the arc (centre line of
/// the string where it rests on the rod). The loop lies in the local XZ
/// plane (crosswise to the rod); the knot and the box hang below it.
const double _strKnotZ = -_strArcR - _strLen;
const double _strKnotH = 8;
const Vec3 _strBoxSize = Vec3(120, 60, 110);
const double _strBoxTop = _strKnotZ - _strKnotH;

/// Stopper bump standing on the free end of the rod.
const double _stopperY = _rodEndY - 6;
const double _stopperH = _rodR + 10;

/// Half width of the loop at local height [z]: a loose round arc around the
/// rod, then two strands that close into a teardrop at the knot.
double _strHalfW(double z) {
  if (z >= -_strArcR) return math.sqrt(math.max(0.0, _strArcR * _strArcR - (z + _strArcR) * (z + _strArcR)));
  final t = ((-_strArcR - z) / _strLen).clamp(0.0, 1.0);
  return _strArcR * (1 - t * t);
}

SceneActor _stringPrize(S s, Pose pose) {
  double z(double t) => -_strArcR - _strLen * t;
  final points = <Vec3>[
    // Arc over the rod from the right side to the left side …
    for (var i = 0; i <= 8; i++)
      Vec3(_strArcR * math.cos(math.pi * i / 8), 0, -_strArcR + _strArcR * math.sin(math.pi * i / 8)),
    // … down the left strand to the knot and up the right one.
    for (var k = 1; k <= 6; k++) Vec3(-_strHalfW(z(k / 6)), 0, z(k / 6)),
    for (var k = 5; k >= 1; k--) Vec3(_strHalfW(z(k / 6)), 0, z(k / 6)),
  ];
  return SceneActor(
    id: 'prize',
    pose: pose,
    cylinders: _loop('string', points, radius: _strR, material: SceneMaterial.rubberTube),
    boxes: [
      const SceneBox(
        id: 'str_knot',
        pose: Pose(Vec3(0, 0, _strKnotZ - _strKnotH / 2)),
        size: Vec3(12, 8, _strKnotH),
        material: SceneMaterial.rubberTube,
      ),
      SceneBox(
        id: 'prize',
        pose: Pose(Vec3(0, 0, _strBoxTop - _strBoxSize.z / 2)),
        size: _strBoxSize,
        label: s.labelPrize,
      ),
    ],
  );
}

/// Pose of the string prize hanging on the rod at [y], turned [yawDeg].
Pose _onRodString(double y, {double yawDeg = 0}) =>
    Pose(Vec3(0, y, _rodZ + _rodR + _strR), Rotation(yawDeg: yawDeg));

/// [loop] with the prize swung [swingDeg] about the point where the string
/// rests on the rod (> 0 = the prize swings toward the player).
Pose _strSwung(Pose loop, double swingDeg) =>
    tiltAbout(loop, loop.position - const Vec3(0, 0, _strR), pitchDeg: swingDeg);

/// 紐吊り: a box hangs by a soft string loop from a rod fixed to the back
/// wall, whose free end (with a small stopper) is over the drop hole. A
/// first play pinches the string: it comes up a little and slides, so the
/// arm is strong enough. Then a tip hooks the wall side of the loop, left
/// and right in turn, and each closing shoves the loop along the rod (the
/// box swings behind it). Near the end a tip goes into the loop beside the
/// rod, lifts it over the stopper and the claw's move pulls it off the end;
/// it slips off the tip into the hole.
GuideDemo hangStringDemo(S s) {
  final start = _onRodString(-140);
  final prize = _stringPrize(s, start);
  final script = DemoScript(actors: [prize], home: const Vec3(-190, 150, 340), hoverZ: 340);

  // 0: power check — both tips pinch the strands under the rod. The string
  // comes up a little, slips through the tips and lands a bit further on.
  script.pause(700, step: 0);
  const pinchZ = -32.0;
  final rest0 = _onRodString(-128, yawDeg: 4);
  script.play(
    step: 0,
    center: start.toWorld(const Vec3(0, 0, pinchZ)),
    closeTo: 2 * _strHalfW(pinchZ) - 6,
    carryMm: 48,
    onLift: {'prize': shifted(start, const Vec3(0, 4, 26))},
    onRelease: {'prize': rest0},
  );

  // Claw centre that puts the tip of [arm] just outside that side of the
  // loop and a little behind it (the wall side), under the rod.
  Vec3 wallSide(Pose loop, Arm arm) {
    final side = arm == Arm.right ? 1.0 : -1.0;
    return script.centerFor(loop.toWorld(Vec3(side * (_strArcR + _strR + 8), -10, -30)), arm);
  }

  // One shove: the closing tip drags the loop forward to [to]; the box lags
  // behind, swings past and settles.
  void shove(int step, Pose from, Arm arm, Pose to) => script.play(
        step: step,
        center: wallSide(from, arm),
        arm: arm,
        closeTo: 136,
        onClose: {'prize': _strSwung(to, -9)},
        onLift: {'prize': _strSwung(to, 5)},
        onRelease: {'prize': to},
      );

  // 1: hook the wall side of the loop with the left tip; closing pushes the
  // loop toward the free end.
  script.aim(wallSide(rest0, Arm.left), arm: Arm.left, step: 1);
  script.pause(900, step: 1);
  final rest1 = _onRodString(-85, yawDeg: -14);
  shove(1, rest0, Arm.left, rest1);

  // 2: right, then left again — the loop walks to just behind the stopper,
  // turned a little.
  final rest2 = _onRodString(-42, yawDeg: 12);
  shove(2, rest1, Arm.right, rest2);
  final rest3 = _onRodString(4, yawDeg: -30);
  shove(2, rest2, Arm.left, rest3);

  // 3: the right tip closes into the loop beside the rod, just under the
  // arc (引っ掛け). Rising, it lifts the loop over the stopper; the claw's
  // move toward the front pulls it off the free end, and when the arms open
  // it slips off the tip and falls into the hole.
  const grip = 136.0;
  final c3 = rest3.toWorld(const Vec3(14, 0, -9)) - const Vec3(grip / 2, 0, 0);
  script.aim(c3, arm: Arm.right, step: 3);
  script.pause(500, step: 3);
  final dropAt = c3 + const Vec3(0, 70, 0);
  final lifted = c3.z + 38;
  final hanging = Vec3(dropAt.x, dropAt.y, lifted) + (rest3.position - c3);
  script.carry(
    step: 3,
    actorId: 'prize',
    center: c3,
    dropAt: dropAt,
    fallTo: Pose(Vec3(hanging.x, hanging.y + 10, -20), const Rotation(pitchDeg: 15, yawDeg: -30)),
    arm: Arm.right,
    gripMm: grip,
    liftZ: lifted,
  );
  script.goHome(step: 3);
  script.pause(900, step: 3);

  return GuideDemo(
    type: LayoutType.hangString,
    timeline: SceneTimeline(
      stage: _stringStage(),
      actors: [prize],
      claw: script.start,
      keys: script.keys,
      clawRestHeightMm: 490,
    ),
  );
}

/// The rod of [_rodStage] with a small stopper standing on its free end.
Scene3D _stringStage() {
  const backY = -demoFieldDepthMm / 2 + 8;
  return const Scene3D(
    fieldWidthMm: demoFieldWidthMm,
    fieldDepthMm: demoFieldDepthMm,
    cylinders: [
      SceneCylinder(id: 'post', p0: Vec3(0, backY, 0), p1: Vec3(0, backY, _rodZ + 30), radius: 10),
      SceneCylinder(id: 'rod', p0: Vec3(0, backY, _rodZ), p1: Vec3(0, _rodEndY, _rodZ), radius: _rodR),
      SceneCylinder(
        id: 'stopper',
        p0: Vec3(0, _stopperY, _rodZ),
        p1: Vec3(0, _stopperY, _rodZ + _stopperH),
        radius: 5,
      ),
    ],
    dropHole: SceneDropHole(xMin: -130, xMax: 130, yMin: -40, yMax: 240),
    camera: CameraHint(yawDeg: 50, pitchDeg: 16, distanceMm: 820, target: Vec3(0, -40, 225)),
  );
}
