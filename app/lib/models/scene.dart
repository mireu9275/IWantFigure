/// Parametric 3D scene of a crane-game field, produced by the aim engine and
/// rendered by the 3D view.
///
/// Field coordinate frame (millimetres):
///   origin = centre of the field floor,
///   X = to the player's right (+),
///   Y = toward the player (手前, +) / away from the player (奥, −),
///   Z = up (+).
library;

import 'dart:math' as math;

import 'analysis.dart';

class Vec3 {
  const Vec3(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);

  final double x;
  final double y;
  final double z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);
  double get length => math.sqrt(dot(this));
  Vec3 normalized() {
    final l = length;
    return l == 0 ? this : this * (1 / l);
  }

  Vec3 lerp(Vec3 o, double t) => this + (o - this) * t;

  List<double> toList() => [x, y, z];

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)}, ${z.toStringAsFixed(1)})';

  @override
  bool operator ==(Object other) =>
      other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

/// Rotation as Euler angles in degrees. [apply] rotates a local vector by
/// roll (about Y), then pitch (about X), then yaw (about Z) in the fixed field
/// frame — i.e. the intrinsic yaw → pitch → roll reading. Because the field
/// frame is left-handed (X right, Y toward the player, Z up), a positive yaw
/// turns the box clockwise when seen from above.
class Rotation {
  const Rotation({this.yawDeg = 0, this.pitchDeg = 0, this.rollDeg = 0});

  static const identity = Rotation();

  /// Rotation about Z (vertical) — turning the box seen from above.
  final double yawDeg;

  /// Rotation about X — tilting front/back end up or down.
  final double pitchDeg;

  /// Rotation about Y — tilting left/right side up or down.
  final double rollDeg;

  /// Adds angle deltas to this rotation.
  Rotation plus({double yawDeg = 0, double pitchDeg = 0, double rollDeg = 0}) => Rotation(
        yawDeg: this.yawDeg + yawDeg,
        pitchDeg: this.pitchDeg + pitchDeg,
        rollDeg: this.rollDeg + rollDeg,
      );

  Rotation lerp(Rotation o, double t) => Rotation(
        yawDeg: yawDeg + (o.yawDeg - yawDeg) * t,
        pitchDeg: pitchDeg + (o.pitchDeg - pitchDeg) * t,
        rollDeg: rollDeg + (o.rollDeg - rollDeg) * t,
      );

  /// Applies this rotation to a local-space vector.
  Vec3 apply(Vec3 v) {
    final yaw = yawDeg * math.pi / 180;
    final pitch = pitchDeg * math.pi / 180;
    final roll = rollDeg * math.pi / 180;
    // roll about Y
    var x = v.x * math.cos(roll) + v.z * math.sin(roll);
    var y = v.y;
    var z = -v.x * math.sin(roll) + v.z * math.cos(roll);
    // pitch about X
    final y2 = y * math.cos(pitch) - z * math.sin(pitch);
    final z2 = y * math.sin(pitch) + z * math.cos(pitch);
    y = y2;
    z = z2;
    // yaw about Z
    final x3 = x * math.cos(yaw) - y * math.sin(yaw);
    final y3 = x * math.sin(yaw) + y * math.cos(yaw);
    x = x3;
    y = y3;
    return Vec3(x, y, z);
  }
}

/// Pose of a rigid body: position of its centre plus rotation.
class Pose {
  const Pose(this.position, [this.rotation = Rotation.identity]);

  final Vec3 position;
  final Rotation rotation;

  Pose lerp(Pose o, double t) =>
      Pose(position.lerp(o.position, t), rotation.lerp(o.rotation, t));

  /// Transforms a point given in the body's local frame into the field frame.
  Vec3 toWorld(Vec3 local) => position + rotation.apply(local);
}

enum SceneMaterial { metal, rubberTube, cardboard, plush, acrylic, marker }

/// A cuboid (prize box, plush approximated as a box, shelf...).
class SceneBox {
  const SceneBox({
    required this.id,
    required this.pose,
    required this.size,
    this.material = SceneMaterial.cardboard,
    this.label = '',
  });

  final String id;
  final Pose pose;

  /// Full extents: x = width (left-right), y = depth (front-back), z = height.
  final Vec3 size;
  final SceneMaterial material;
  final String label;

  /// The 8 corners in field coordinates.
  List<Vec3> corners() {
    final hx = size.x / 2, hy = size.y / 2, hz = size.z / 2;
    return [
      for (final sz in [-1.0, 1.0])
        for (final sy in [-1.0, 1.0])
          for (final sx in [-1.0, 1.0]) pose.toWorld(Vec3(sx * hx, sy * hy, sz * hz)),
    ];
  }

  /// Point on the box given fractional local coordinates:
  /// [u] 0 = front edge (+Y side) … 1 = back edge (−Y side),
  /// [v] 0 = left … 1 = right, [w] 0 = bottom … 1 = top.
  Vec3 pointAt(double u, double v, double w) => pose.toWorld(Vec3(
        (v - 0.5) * size.x,
        (0.5 - u) * size.y,
        (w - 0.5) * size.z,
      ));

  SceneBox copyWith({Pose? pose, Vec3? size, String? label}) => SceneBox(
        id: id,
        pose: pose ?? this.pose,
        size: size ?? this.size,
        material: material,
        label: label ?? this.label,
      );
}

/// A cylinder between two points (bars, rods).
class SceneCylinder {
  const SceneCylinder({
    required this.id,
    required this.p0,
    required this.p1,
    this.radius = 6,
    this.material = SceneMaterial.metal,
    this.label = '',
  });

  final String id;
  final Vec3 p0;
  final Vec3 p1;
  final double radius;
  final SceneMaterial material;
  final String label;
}

/// Rectangle on the floor (z = 0) where the prize falls to win.
class SceneDropHole {
  const SceneDropHole({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });

  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
}

/// The claw unit. [center] is the position of the claw's centre when it is
/// lowered to the recommended aim point; the view draws it above that point.
class SceneClaw {
  const SceneClaw({
    required this.center,
    this.clawCount = 2,
    this.openWidthMm = 180,
    this.restHeightMm = 520,
  });

  final Vec3 center;
  final int clawCount;

  /// Distance between the two arm tips when fully open (2-claw).
  final double openWidthMm;

  /// Height of the claw unit at rest, above the floor.
  final double restHeightMm;
}

/// A highlighted aim point.
class SceneMarker {
  const SceneMarker({
    required this.point,
    required this.label,
    this.arm = Arm.both,
    this.primary = true,
  });

  final Vec3 point;
  final String label;
  final Arm arm;
  final bool primary;
}

/// Predicted motion of the prize after one play: interpolate [from] → [to].
class SceneMotion {
  const SceneMotion({
    required this.boxId,
    required this.from,
    required this.to,
    required this.description,
  });

  final String boxId;
  final Pose from;
  final Pose to;
  final String description;
}

/// Suggested initial camera for the 3D view.
class CameraHint {
  const CameraHint({
    this.yawDeg = 35,
    this.pitchDeg = 28,
    this.distanceMm = 1300,
    this.target = Vec3.zero,
  });

  final double yawDeg;
  final double pitchDeg;
  final double distanceMm;
  final Vec3 target;
}

class Scene3D {
  const Scene3D({
    this.fieldWidthMm = 600,
    this.fieldDepthMm = 500,
    this.cylinders = const [],
    this.boxes = const [],
    this.claw,
    this.dropHole,
    this.markers = const [],
    this.motion,
    this.camera = const CameraHint(),
  });

  final double fieldWidthMm;
  final double fieldDepthMm;
  final List<SceneCylinder> cylinders;
  final List<SceneBox> boxes;
  final SceneClaw? claw;
  final SceneDropHole? dropHole;
  final List<SceneMarker> markers;
  final SceneMotion? motion;
  final CameraHint camera;

  SceneBox? boxById(String id) {
    for (final b in boxes) {
      if (b.id == id) return b;
    }
    return null;
  }

  Scene3D copyWith({
    List<SceneCylinder>? cylinders,
    List<SceneBox>? boxes,
    SceneClaw? claw,
    SceneDropHole? dropHole,
    List<SceneMarker>? markers,
    SceneMotion? motion,
    CameraHint? camera,
  }) =>
      Scene3D(
        fieldWidthMm: fieldWidthMm,
        fieldDepthMm: fieldDepthMm,
        cylinders: cylinders ?? this.cylinders,
        boxes: boxes ?? this.boxes,
        claw: claw ?? this.claw,
        dropHole: dropHole ?? this.dropHole,
        markers: markers ?? this.markers,
        motion: motion ?? this.motion,
        camera: camera ?? this.camera,
      );
}
