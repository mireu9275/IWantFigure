/// Inputs to the aim engine that come from the user rather than from the
/// photo analysis: prize dimensions, manual corrections, play observations.
library;

import '../models/analysis.dart';

/// Physical size of the prize. For a box resting across the bars the long
/// side normally runs front-to-back ([depthMm]).
class PrizeSpec {
  const PrizeSpec({
    this.name = '',
    required this.widthMm,
    required this.depthMm,
    required this.heightMm,
    this.massG,
  });

  /// Typical prize-figure box lying flat: 150 × 200 × 100 mm, about 300 g.
  static const defaultFigureBox = PrizeSpec(
    name: 'figure box (default)',
    widthMm: 150,
    depthMm: 200,
    heightMm: 100,
    massG: 300,
  );

  /// Typical medium plush toy approximated as a soft block.
  static const defaultPlush = PrizeSpec(
    name: 'plush (default)',
    widthMm: 220,
    depthMm: 180,
    heightMm: 200,
    massG: 250,
  );

  final String name;

  /// X extent (left-right).
  final double widthMm;

  /// Y extent (front-back).
  final double depthMm;

  /// Z extent (height).
  final double heightMm;
  final double? massG;

  /// Heavy prizes are stood up (縦ハメ); light ones are turned flat (横ハメ).
  bool get isHeavy => (massG ?? 300) >= 350;

  PrizeSpec copyWith({
    String? name,
    double? widthMm,
    double? depthMm,
    double? heightMm,
    double? massG,
  }) =>
      PrizeSpec(
        name: name ?? this.name,
        widthMm: widthMm ?? this.widthMm,
        depthMm: depthMm ?? this.depthMm,
        heightMm: heightMm ?? this.heightMm,
        massG: massG ?? this.massG,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'width_mm': widthMm,
        'depth_mm': depthMm,
        'height_mm': heightMm,
        'mass_g': massG,
      };

  factory PrizeSpec.fromJson(Map<String, dynamic> j) => PrizeSpec(
        name: (j['name'] ?? '').toString(),
        widthMm: (j['width_mm'] as num?)?.toDouble() ?? 150,
        depthMm: (j['depth_mm'] as num?)?.toDouble() ?? 200,
        heightMm: (j['height_mm'] as num?)?.toDouble() ?? 100,
        massG: (j['mass_g'] as num?)?.toDouble(),
      );
}

/// What the player saw after one play.
enum ObservationKind {
  /// Prize did not move at all.
  noMove,

  /// Prize shifted or rotated a little.
  smallMove,

  /// Prize moved a lot / rotated clearly.
  bigMove,

  /// The claw lifted the prize (even briefly).
  lifted,

  /// The prize fell into the drop hole — win.
  dropped,

  /// The prize is wedged in a dead position (詰み).
  stuck,
}

class Observation {
  const Observation(this.kind, {this.playIndex = 0, this.note});

  final ObservationKind kind;

  /// 1-based play number this observation belongs to (0 when unknown).
  final int playIndex;
  final String? note;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'play_index': playIndex,
        'note': note,
      };

  factory Observation.fromJson(Map<String, dynamic> j) => Observation(
        ObservationKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => ObservationKind.smallMove,
        ),
        playIndex: (j['play_index'] as num?)?.toInt() ?? 0,
        note: j['note'] as String?,
      );
}

/// Manual corrections made by the user on top of the detected geometry.
/// Every field is optional; `null` means "keep the detected value".
class SceneCorrections {
  const SceneCorrections({
    this.prizeBbox,
    this.topFaceRatio,
    this.frontBar,
    this.backBar,
    this.dropHole,
    this.claw,
    this.yawDeg,
    this.boxYOffsetMm,
  });

  static const none = SceneCorrections();

  /// Bounding box of the target prize.
  final NBox? prizeBbox;

  /// Fraction of the prize bbox height (from the top) that shows the top face.
  /// 0.35 is typical for a box photographed from slightly above.
  final double? topFaceRatio;

  /// Bounding boxes of the front (手前) and back (奥) bars.
  final NBox? frontBar;
  final NBox? backBar;
  final NBox? dropHole;
  final NBox? claw;

  /// Rotation of the prize seen from above, degrees (positive = counter-clockwise).
  final double? yawDeg;

  /// Front/back offset of the prize on the bars in mm (negative = toward the
  /// back, 奥寄り). Photos cannot tell this reliably, so the user sets it.
  final double? boxYOffsetMm;

  bool get isEmpty =>
      prizeBbox == null &&
      topFaceRatio == null &&
      frontBar == null &&
      backBar == null &&
      dropHole == null &&
      claw == null &&
      yawDeg == null &&
      boxYOffsetMm == null;

  /// Returns a copy with the given fields replaced. Fields listed in
  /// [clear] are reset to `null` ("use the detected value again").
  SceneCorrections copyWith({
    NBox? prizeBbox,
    double? topFaceRatio,
    NBox? frontBar,
    NBox? backBar,
    NBox? dropHole,
    NBox? claw,
    double? yawDeg,
    double? boxYOffsetMm,
    Set<String> clear = const {},
  }) =>
      SceneCorrections(
        prizeBbox: clear.contains('prizeBbox') ? null : prizeBbox ?? this.prizeBbox,
        topFaceRatio: clear.contains('topFaceRatio') ? null : topFaceRatio ?? this.topFaceRatio,
        frontBar: clear.contains('frontBar') ? null : frontBar ?? this.frontBar,
        backBar: clear.contains('backBar') ? null : backBar ?? this.backBar,
        dropHole: clear.contains('dropHole') ? null : dropHole ?? this.dropHole,
        claw: clear.contains('claw') ? null : claw ?? this.claw,
        yawDeg: clear.contains('yawDeg') ? null : yawDeg ?? this.yawDeg,
        boxYOffsetMm: clear.contains('boxYOffsetMm') ? null : boxYOffsetMm ?? this.boxYOffsetMm,
      );

  Map<String, dynamic> toJson() => {
        'prize_bbox': prizeBbox?.toList(),
        'top_face_ratio': topFaceRatio,
        'front_bar': frontBar?.toList(),
        'back_bar': backBar?.toList(),
        'drop_hole': dropHole?.toList(),
        'claw': claw?.toList(),
        'yaw_deg': yawDeg,
        'box_y_offset_mm': boxYOffsetMm,
      };

  factory SceneCorrections.fromJson(Map<String, dynamic>? j) {
    if (j == null) return SceneCorrections.none;
    NBox? box(dynamic v) => v is List && v.length == 4 ? NBox.fromList(v) : null;
    double? number(dynamic v) => v is num ? v.toDouble() : null;
    return SceneCorrections(
      prizeBbox: box(j['prize_bbox']),
      topFaceRatio: number(j['top_face_ratio']),
      frontBar: box(j['front_bar']),
      backBar: box(j['back_bar']),
      dropHole: box(j['drop_hole']),
      claw: box(j['claw']),
      yawDeg: number(j['yaw_deg']),
      boxYOffsetMm: number(j['box_y_offset_mm']),
    );
  }
}

/// Tunable heuristics of the engine. Defaults encode the community rules of
/// thumb; they are exposed so they can be adjusted from settings/tests.
class EngineOptions {
  const EngineOptions({
    this.fieldWidthMm = 600,
    this.fieldDepthMm = 500,
    this.barHeightMm = 80,
    this.barRadiusMm = 6,
    this.clawOpenWidthMm = 180,
    this.clawRestHeightMm = 520,
    this.edgeInset = 0.12,
    this.sideOffset = 0.22,
    this.defaultTopFaceRatio = 0.35,
    this.defaultBarGapRatio = 0.65,
  });

  static const defaults = EngineOptions();

  final double fieldWidthMm;
  final double fieldDepthMm;
  final double barHeightMm;
  final double barRadiusMm;
  final double clawOpenWidthMm;
  final double clawRestHeightMm;

  /// How far inside the prize end the claw tip should land (fraction of the
  /// prize depth). "端ギリギリ" = just inside the edge.
  final double edgeInset;

  /// Lateral offset from the prize centre line for alternating left/right
  /// contacts (fraction of the prize width).
  final double sideOffset;

  final double defaultTopFaceRatio;

  /// Bar gap as a fraction of the prize depth when the bars are not detected.
  final double defaultBarGapRatio;
}
