/// Guide demo for the takoyaki board (たこ焼き): a heap of ping-pong balls
/// and a board of holes on the floor. The winning hole is the drop hole (red);
/// the losing holes are dark squares, some already filled with a ball.
library;

import 'package:flutter/animation.dart' show Curve, Curves;

import '../../l10n/strings.dart';
import '../../models/analysis.dart';
import '../../models/scene.dart';
import '../../scene3d/timeline.dart';
import '../guide_demo.dart';

/// Ping-pong ball radius.
const double _r = 20;

/// Height step between square-packed layers of balls (r·√2).
const double _layer = _r * 1.4142136;

/// Centre of the heap (back right).
const Vec3 _heap = Vec3(150, -130, 0);

/// The board (front left): a 3 × 3 grid of holes [_pitch] apart whose middle
/// one, at ([_winX], [_winY]), is the winning hole.
const double _winX = -140, _winY = 80, _pitch = 70;
const Vec3 _win = Vec3(_winX, _winY, 0);

/// The losing holes around it and which of them are already filled.
const List<Vec3> _losing = [
  Vec3(_winX - _pitch, _winY - _pitch, 0), Vec3(_winX, _winY - _pitch, 0), Vec3(_winX + _pitch, _winY - _pitch, 0),
  Vec3(_winX - _pitch, _winY, 0), Vec3(_winX + _pitch, _winY, 0),
  Vec3(_winX - _pitch, _winY + _pitch, 0), Vec3(_winX, _winY + _pitch, 0), Vec3(_winX + _pitch, _winY + _pitch, 0),
];
const Set<int> _filled = {0, 2, 4, 5};

/// The empty losing hole (one of [_losing]) the second ball ends up in.
const Vec3 _loseB = Vec3(_winX + _pitch, _winY + _pitch, 0);

/// Side of a losing hole: smaller than a ball, which sits in it [_sunk] deep.
/// The winning hole (the drop hole) is wider, so a ball drops through.
const double _holeSide = 34;
const double _winSide = 44;

/// How deep a ball sits in a losing hole.
const double _sunk = 9;

/// Thickness of the dark square that shows a losing hole.
const double _holeDepth = 1.5;

/// The board: [_boardMargin] wider than the grid, framed by a low rim.
const double _boardMargin = 45;
const double _boardSide = 2 * _pitch + 2 * _boardMargin;
const double _rimWidth = 6, _rimHeight = 10;

/// たこ焼き: grab two balls from the top of the heap, carry them over the
/// board and let go just beside the winning hole: one bounces into it, the
/// other into a losing hole.
///
/// [DemoScript.carry] moves one actor with the claw and hides it as soon as
/// it lands; here two balls ride along and then bounce apart, so the keys
/// are written out with the same timings.
GuideDemo takoyakiDemo(S s) {
  // The two top balls of the heap sit side by side along Y (a ridge), so the
  // arms, which close along X, hold both.
  final top = _heap + const Vec3(0, 0, _r + 2 * _layer);
  final a0 = top + const Vec3(0, -_r, 0), b0 = top + const Vec3(0, _r, 0);
  SceneActor ball(String id, Vec3 at) =>
      SceneActor(id: id, pose: Pose(at), spheres: [SceneSphere(id: id, center: Vec3.zero, radius: _r)]);
  final ballA = ball('a', a0), ballB = ball('b', b0);

  const hoverZ = 250.0, openMm = 180.0, gripMm = 2 * _r + 4;
  const home = ClawState(Vec3(-140, 200, hoverZ), openWidthMm: openMm);
  final keys = <SceneKey>[];
  void key(
    int ms, {
    ClawState? claw,
    Vec3? a,
    Vec3? b,
    Set<String> hide = const {},
    required int step,
    List<SceneMarker>? markers,
    Curve curve = Curves.easeInOut,
  }) =>
      keys.add(SceneKey(
        ms: ms,
        claw: claw,
        poses: {if (a != null) 'a': Pose(a), if (b != null) 'b': Pose(b)},
        hide: hide,
        step: step,
        markers: markers,
        curve: curve,
      ));

  // 0: aim at the tallest part of the heap and pick up two balls.
  key(1500, step: 0);
  key(
    DemoScript.travelMs + 250,
    claw: ClawState(Vec3(top.x, top.y, hoverZ), openWidthMm: openMm),
    step: 0,
    // On top of the two balls, so it does not hide them.
    markers: [SceneMarker(point: top + const Vec3(0, 0, _r), label: '')],
  );
  key(500, step: 0);
  key(DemoScript.descendMs, claw: ClawState(top, openWidthMm: openMm), step: 0);
  key(DemoScript.closeMs, claw: ClawState(top, openWidthMm: gripMm), step: 0);
  final lift = Vec3(0, 0, hoverZ - top.z);
  key(
    DemoScript.liftMs,
    claw: ClawState(Vec3(top.x, top.y, hoverZ), openWidthMm: gripMm),
    a: a0 + lift,
    b: b0 + lift,
    step: 0,
  );

  // 1: carry them over the board: the losing holes that are already filled
  // make the winning one more likely.
  const release = Vec3(-104, 88, 170);
  final carry = Vec3(release.x - top.x, release.y - top.y, 0);
  key(
    DemoScript.travelMs + 400,
    claw: ClawState(Vec3(release.x, release.y, hoverZ), openWidthMm: gripMm),
    a: a0 + lift + carry,
    b: b0 + lift + carry,
    step: 1,
    markers: const [],
  );
  key(1500, step: 1);

  // 2: lower a little and let go just beside the winning hole; the balls
  // bounce on the board and settle — one in the winning hole.
  final down = Vec3(0, 0, release.z - hoverZ);
  final held = [a0 + lift + carry + down, b0 + lift + carry + down];
  key(
    700,
    claw: const ClawState(release, openWidthMm: gripMm),
    a: held[0],
    b: held[1],
    step: 2,
    // The spot on the board under the claw.
    markers: [SceneMarker(point: Vec3(release.x, release.y, 0), label: '')],
  );
  const drop = Vec3(0, 0, -14);
  key(
    350,
    claw: const ClawState(release, openWidthMm: openMm),
    a: held[0] + drop,
    b: held[1] + drop,
    step: 2,
    markers: const [],
    curve: Curves.easeIn,
  );
  key(330, a: const Vec3(-108, 66, _r), b: const Vec3(-100, 112, _r), step: 2, curve: Curves.easeIn);
  key(260, a: const Vec3(-119, 72, _r + 34), b: const Vec3(-88, 127, _r + 30), step: 2, curve: Curves.easeOut);
  key(260, a: const Vec3(-127, 77, _r), b: const Vec3(-78, 140, _r), step: 2, curve: Curves.easeIn);
  key(300, a: _win + const Vec3(0, 0, _r), b: _loseB + const Vec3(0, 0, _r), step: 2);
  key(280, a: _win + const Vec3(0, 0, -30), b: _loseB + const Vec3(0, 0, _r - _sunk), step: 2, curve: Curves.easeIn);
  key(0, hide: {'a'}, step: 2);
  key(500, step: 2);
  key(DemoScript.liftMs, claw: ClawState(Vec3(release.x, release.y, hoverZ), openWidthMm: openMm), step: 2);

  // 3: on a time-saver board, count the losing holes that are still open.
  key(DemoScript.travelMs, claw: home, step: 3);
  key(1800, step: 3);

  return GuideDemo(
    type: LayoutType.takoyaki,
    timeline: SceneTimeline(
      stage: _stage(),
      actors: [ballA, ballB],
      claw: home,
      keys: keys,
      clawRestHeightMm: 420,
    ),
  );
}

/// The board (a rim around holes on the floor, the winning one as the drop
/// hole) and the heap of balls without its two top balls.
Scene3D _stage() {
  const pitch = 2 * _r;
  final heap = <SceneSphere>[
    for (var i = 0; i < 3; i++)
      for (var j = 0; j < 4; j++)
        SceneSphere(
          id: 'heap0_${i}_$j',
          center: _heap + Vec3((i - 1) * pitch, (j - 1.5) * pitch, _r),
          radius: _r,
        ),
    for (var i = 0; i < 2; i++)
      for (var j = 0; j < 3; j++)
        SceneSphere(
          id: 'heap1_${i}_$j',
          center: _heap + Vec3((i - 0.5) * pitch, (j - 1) * pitch, _r + _layer),
          radius: _r,
        ),
  ];
  return Scene3D(
    fieldWidthMm: demoFieldWidthMm,
    fieldDepthMm: demoFieldDepthMm,
    boxes: [
      // The board's low rim (the board is the floor inside it): back, front,
      // left, right.
      for (final (id, dx, dy, w, d) in const [
        ('board_back', 0.0, -_boardSide / 2, _boardSide + _rimWidth, _rimWidth),
        ('board_front', 0.0, _boardSide / 2, _boardSide + _rimWidth, _rimWidth),
        ('board_left', -_boardSide / 2, 0.0, _rimWidth, _boardSide - _rimWidth),
        ('board_right', _boardSide / 2, 0.0, _rimWidth, _boardSide - _rimWidth),
      ])
        SceneBox(
          id: id,
          pose: Pose(Vec3(_winX + dx, _winY + dy, _rimHeight / 2)),
          size: Vec3(w, d, _rimHeight),
          material: SceneMaterial.metal,
        ),
      // Each losing hole is a dark square on the floor.
      for (var i = 0; i < _losing.length; i++)
        SceneBox(
          id: 'hole_$i',
          pose: Pose(_losing[i] + const Vec3(0, 0, _holeDepth / 2)),
          size: const Vec3(_holeSide, _holeSide, _holeDepth),
          material: SceneMaterial.metal,
        ),
    ],
    spheres: [
      ...heap,
      for (final i in _filled)
        SceneSphere(id: 'filled_$i', center: _losing[i] + const Vec3(0, 0, _r - _sunk), radius: _r),
    ],
    dropHole: const SceneDropHole(
      xMin: _winX - _winSide / 2,
      xMax: _winX + _winSide / 2,
      yMin: _winY - _winSide / 2,
      yMax: _winY + _winSide / 2,
    ),
    camera: const CameraHint(yawDeg: 20, pitchDeg: 28, distanceMm: 900, target: Vec3(-40, 0, 150)),
  );
}
