/// Pinhole orbit camera used by the software-rendered 3D view.
///
/// Pure Dart: only `dart:math` and the `Offset`/`Size` value types from
/// `dart:ui` are used, so the maths can be unit-tested without a widget tree.
///
/// Field frame (see `models/scene.dart`): X = player's right, Y = toward the
/// player, Z = up, all in millimetres. The camera basis is chosen so that at
/// `yawDeg == 0` the camera sits on the player's side (+Y), +X appears on the
/// right of the screen, +Y at the bottom (nearest the viewer) and +Z upward.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import '../models/scene.dart';

/// Result of projecting a field-space point onto the viewport.
class Projected {
  const Projected({
    required this.screen,
    required this.depth,
    required this.visible,
  });

  /// Position in viewport pixels (origin at the top-left corner).
  final Offset screen;

  /// Distance along the viewing direction in mm; positive = in front of the
  /// camera.
  final double depth;

  /// False when the point is behind (or closer than [OrbitCamera.nearMm] to)
  /// the camera. [screen] is not meaningful in that case.
  final bool visible;

  @override
  String toString() => 'Projected($screen, depth: ${depth.toStringAsFixed(1)}, visible: $visible)';
}

/// A camera orbiting around [target] at [distanceMm], described by a yaw
/// (rotation around the vertical axis) and a pitch (elevation above the
/// floor plane; positive looks down from above).
///
/// Instances are immutable; use [copyWith] to derive a moved camera. Pitch,
/// distance and field of view are clamped to sane ranges on construction.
class OrbitCamera {
  OrbitCamera({
    this.yawDeg = 35,
    double pitchDeg = 28,
    double distanceMm = 1300,
    this.target = Vec3.zero,
    double fovDeg = 45,
  })  : pitchDeg = pitchDeg.clamp(minPitchDeg, maxPitchDeg).toDouble(),
        distanceMm = distanceMm.clamp(minDistanceMm, maxDistanceMm).toDouble(),
        fovDeg = fovDeg.clamp(minFovDeg, maxFovDeg).toDouble();

  /// Camera matching the engine's suggested initial view.
  factory OrbitCamera.fromHint(CameraHint hint, {double fovDeg = 45}) => OrbitCamera(
        yawDeg: hint.yawDeg,
        pitchDeg: hint.pitchDeg,
        distanceMm: hint.distanceMm,
        target: hint.target,
        fovDeg: fovDeg,
      );

  static const double minPitchDeg = 5;
  static const double maxPitchDeg = 85;
  static const double minDistanceMm = 400;
  static const double maxDistanceMm = 4000;
  static const double minFovDeg = 10;
  static const double maxFovDeg = 120;

  /// Points closer than this to the camera plane are treated as invisible;
  /// primitives are clipped against it.
  static const double nearMm = 20;

  static const Vec3 _worldUp = Vec3(0, 0, 1);

  /// Rotation around the vertical axis in degrees. 0 = seen from the player's
  /// side; positive values move the camera toward the player's right.
  final double yawDeg;

  /// Elevation in degrees, clamped to [minPitchDeg]..[maxPitchDeg].
  /// Positive looks down at the field from above.
  final double pitchDeg;

  /// Distance from [eye] to [target] in mm, clamped to
  /// [minDistanceMm]..[maxDistanceMm].
  final double distanceMm;

  /// The point the camera looks at, in field coordinates.
  final Vec3 target;

  /// Field of view (degrees) across the shorter side of the viewport.
  final double fovDeg;

  /// Position of the camera in field coordinates.
  late final Vec3 eye = _computeEye();

  late final Vec3 _forward = (target - eye).normalized();
  late final Vec3 _right = _worldUp.cross(_forward).normalized();
  late final Vec3 _up = _forward.cross(_right);

  Vec3 _computeEye() {
    final yaw = yawDeg * math.pi / 180;
    final pitch = pitchDeg * math.pi / 180;
    final horizontal = math.cos(pitch) * distanceMm;
    return target +
        Vec3(
          math.sin(yaw) * horizontal,
          math.cos(yaw) * horizontal,
          math.sin(pitch) * distanceMm,
        );
  }

  /// Unit vector pointing from the camera to [target].
  Vec3 get forward => _forward;

  /// Unit vector pointing to the right of the screen, in field coordinates.
  Vec3 get right => _right;

  /// Unit vector pointing to the top of the screen, in field coordinates.
  Vec3 get up => _up;

  OrbitCamera copyWith({
    double? yawDeg,
    double? pitchDeg,
    double? distanceMm,
    Vec3? target,
    double? fovDeg,
  }) =>
      OrbitCamera(
        yawDeg: yawDeg ?? this.yawDeg,
        pitchDeg: pitchDeg ?? this.pitchDeg,
        distanceMm: distanceMm ?? this.distanceMm,
        target: target ?? this.target,
        fovDeg: fovDeg ?? this.fovDeg,
      );

  /// Focal length in pixels for [viewport]: the distance at which one mm of
  /// the target plane maps to one pixel, derived from [fovDeg] across the
  /// shorter viewport side so the framing is the same in portrait and
  /// landscape.
  double focalLength(Size viewport) {
    final shorter = math.min(viewport.width, viewport.height);
    return 0.5 * shorter / math.tan(fovDeg * math.pi / 360);
  }

  /// Transforms a field-space point into view space: x to the right, y up,
  /// z = depth in front of the camera (all mm).
  Vec3 toView(Vec3 world) {
    final v = world - eye;
    return Vec3(v.dot(_right), v.dot(_up), v.dot(_forward));
  }

  /// Perspective-divides a view-space point (see [toView]) onto [viewport].
  /// Depths below [nearMm] are clamped so the result stays finite.
  Offset viewToScreen(Vec3 view, Size viewport) {
    final focal = focalLength(viewport);
    final z = math.max(view.z, nearMm);
    return Offset(
      viewport.width / 2 + view.x / z * focal,
      viewport.height / 2 - view.y / z * focal,
    );
  }

  /// Projects [world] onto [viewport].
  Projected project(Vec3 world, Size viewport) {
    final v = toView(world);
    return Projected(
      screen: viewToScreen(v, viewport),
      depth: v.z,
      visible: v.z >= nearMm,
    );
  }

  /// Relative size factor for screen-space decorations (markers, labels) at a
  /// given [depth]: 1 at the target's depth, larger when closer, smaller when
  /// farther away. Unlike [pixelsPerMm] it does not change with the zoom
  /// level, so markers keep a readable size while the user zooms.
  double scaleAt(double depth) => distanceMm / math.max(depth, nearMm);

  /// Exact pixels per millimetre for something at [depth] on [viewport];
  /// use it to size world-space things (rod thickness, radii) on screen.
  double pixelsPerMm(double depth, Size viewport) => focalLength(viewport) / math.max(depth, nearMm);

  @override
  bool operator ==(Object other) =>
      other is OrbitCamera &&
      other.yawDeg == yawDeg &&
      other.pitchDeg == pitchDeg &&
      other.distanceMm == distanceMm &&
      other.target == target &&
      other.fovDeg == fovDeg;

  @override
  int get hashCode => Object.hash(yawDeg, pitchDeg, distanceMm, target, fovDeg);

  @override
  String toString() =>
      'OrbitCamera(yaw: ${yawDeg.toStringAsFixed(1)}, pitch: ${pitchDeg.toStringAsFixed(1)}, '
      'distance: ${distanceMm.toStringAsFixed(0)}, target: $target)';
}
