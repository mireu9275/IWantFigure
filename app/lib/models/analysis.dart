/// Data model for one crane-game analysis (mirrors `shared/analysis.schema.json`).
///
/// Coordinates are normalized to the analyzed image: x, y in [0, 1],
/// origin at the top-left corner, x to the right, y downward.
library;

/// Prize setup type (景品設置パターン).
enum LayoutType {
  bridgeParallel('bridge_parallel', '橋渡し(平行)'),
  bridgeHanoji('bridge_hanoji', '末広がり / ハの字'),
  bridgeStep('bridge_step', '段差 / クロス / ピンクチューブ'),
  frontDrop('front_drop', '前落とし'),
  valleyDrop('valley_drop', '谷落とし'),
  sideDrop('side_drop', '横落とし'),
  ringPera('ring_pera', 'ペラ輪'),
  ringD('ring_d', 'D環 / Oリング'),
  hookS('hook_s', 'S字フック'),
  takoyaki('takoyaki', 'たこ焼き'),
  threeClaw('three_claw', '3本爪 ぬいぐるみ'),
  twoClawDirect('two_claw_direct', '2本爪 直取り'),
  pile('pile', '山積み'),
  floorBox('floor_box', '箱 直置き'),
  unknown('unknown', '判別不可');

  const LayoutType(this.wire, this.labelJa);

  /// Wire value used in JSON.
  final String wire;

  /// Japanese community name (shown in the UI next to the localized label).
  final String labelJa;

  static LayoutType fromWire(String? value) => LayoutType.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => LayoutType.unknown,
      );

  /// True for setups where a box rests across two bars.
  bool get isBridge =>
      this == bridgeParallel || this == bridgeHanoji || this == bridgeStep;
}

/// Kind of a detected object.
enum ObjectKind {
  box('box'),
  plush('plush'),
  bar('bar'),
  tubeBar('tube_bar'),
  claw('claw'),
  dropHole('drop_hole'),
  ring('ring'),
  shelf('shelf'),
  other('other');

  const ObjectKind(this.wire);
  final String wire;

  static ObjectKind fromWire(String? value) => ObjectKind.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => ObjectKind.other,
      );

  bool get isPrize => this == box || this == plush;
  bool get isBar => this == bar || this == tubeBar;
}

/// Play technique (テクニック).
enum Technique {
  tateHame('tate_hame', '縦ハメ'),
  yokoHame('yoko_hame', '横ハメ'),
  zurashi('zurashi', 'ずらし'),
  yose('yose', '寄せ'),
  oshikomi('oshikomi', '押し込み'),
  mochiage('mochiage', '持ち上げ'),
  hikkake('hikkake', '引っ掛け'),
  noriage('noriage', '乗り上げ'),
  tsuki('tsuki', '突き'),
  otoshi('otoshi', '落とし'),
  nadare('nadare', '雪崩'),
  kadoOshi('kado_oshi', '角押し'),
  unknown('unknown', '—');

  const Technique(this.wire, this.labelJa);
  final String wire;
  final String labelJa;

  static Technique fromWire(String? value) => Technique.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => Technique.unknown,
      );
}

/// Which part of the prize the claw should contact.
enum TargetEdge {
  frontLeft('front_left'),
  frontRight('front_right'),
  backLeft('back_left'),
  backRight('back_right'),
  front('front'),
  back('back'),
  left('left'),
  right('right'),
  center('center');

  const TargetEdge(this.wire);
  final String wire;

  static TargetEdge fromWire(String? value) => TargetEdge.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => TargetEdge.center,
      );
}

/// Which claw arm makes contact.
enum Arm {
  left('left'),
  right('right'),
  both('both');

  const Arm(this.wire);
  final String wire;

  static Arm fromWire(String? value) => Arm.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => Arm.both,
      );

  Arm get opposite => switch (this) {
        Arm.left => Arm.right,
        Arm.right => Arm.left,
        Arm.both => Arm.both,
      };
}

enum ArmPower {
  weak('weak'),
  medium('medium'),
  strong('strong'),
  unknown('unknown');

  const ArmPower(this.wire);
  final String wire;

  static ArmPower fromWire(String? value) => ArmPower.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => ArmPower.unknown,
      );
}

enum AssistLamp {
  none('none'),
  blue('blue'),
  green('green'),
  unknown('unknown');

  const AssistLamp(this.wire);
  final String wire;

  static AssistLamp fromWire(String? value) => AssistLamp.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => AssistLamp.unknown,
      );
}

/// Which way the claw unit twists while it descends (seen from above).
/// Not visible in a photo: the player observes it on the first play.
enum ClawRotation {
  unknown('unknown'),
  none('none'),
  clockwise('clockwise'),
  counterClockwise('counter_clockwise');

  const ClawRotation(this.wire);
  final String wire;

  static ClawRotation fromWire(String? value) => ClawRotation.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => ClawRotation.unknown,
      );

  bool get isKnown => this == clockwise || this == counterClockwise;
}

enum ExitSide {
  front('front'),
  left('left'),
  right('right'),
  back('back'),
  center('center'),
  unknown('unknown');

  const ExitSide(this.wire);
  final String wire;

  static ExitSide fromWire(String? value) => ExitSide.values.firstWhere(
        (e) => e.wire == value,
        orElse: () => ExitSide.unknown,
      );
}

/// A 2D point in normalized image coordinates (0..1).
class Pt {
  const Pt(this.x, this.y);

  final double x;
  final double y;

  Pt operator +(Pt o) => Pt(x + o.x, y + o.y);
  Pt operator -(Pt o) => Pt(x - o.x, y - o.y);
  Pt scale(double k) => Pt(x * k, y * k);

  Pt clamp01() => Pt(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));

  List<double> toList() => [x, y];

  @override
  String toString() => 'Pt(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)})';

  @override
  bool operator ==(Object other) => other is Pt && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Axis-aligned box in normalized image coordinates.
class NBox {
  const NBox(this.x1, this.y1, this.x2, this.y2);

  final double x1;
  final double y1;
  final double x2;
  final double y2;

  static NBox fromList(List<dynamic> v) {
    if (v.length != 4) {
      throw FormatException('bbox must have 4 numbers, got ${v.length}');
    }
    final d = v.map((e) => (e as num).toDouble()).toList();
    return NBox(d[0], d[1], d[2], d[3]).normalized();
  }

  /// Returns a box with x1 <= x2 and y1 <= y2, clamped to [0, 1].
  NBox normalized() {
    final ax = x1 < x2 ? x1 : x2;
    final bx = x1 < x2 ? x2 : x1;
    final ay = y1 < y2 ? y1 : y2;
    final by = y1 < y2 ? y2 : y1;
    return NBox(
      ax.clamp(0.0, 1.0),
      ay.clamp(0.0, 1.0),
      bx.clamp(0.0, 1.0),
      by.clamp(0.0, 1.0),
    );
  }

  double get width => x2 - x1;
  double get height => y2 - y1;
  double get cx => (x1 + x2) / 2;
  double get cy => (y1 + y2) / 2;
  double get area => width * height;
  Pt get center => Pt(cx, cy);

  bool contains(Pt p) => p.x >= x1 && p.x <= x2 && p.y >= y1 && p.y <= y2;

  /// Point at fractional position inside the box (0..1 each).
  Pt at(double fx, double fy) => Pt(x1 + width * fx, y1 + height * fy);

  NBox copyWith({double? x1, double? y1, double? x2, double? y2}) =>
      NBox(x1 ?? this.x1, y1 ?? this.y1, x2 ?? this.x2, y2 ?? this.y2);

  List<double> toList() => [x1, y1, x2, y2];

  @override
  String toString() =>
      'NBox(${x1.toStringAsFixed(3)}, ${y1.toStringAsFixed(3)}, ${x2.toStringAsFixed(3)}, ${y2.toStringAsFixed(3)})';

  @override
  bool operator ==(Object other) =>
      other is NBox &&
      other.x1 == x1 &&
      other.y1 == y1 &&
      other.x2 == x2 &&
      other.y2 == y2;

  @override
  int get hashCode => Object.hash(x1, y1, x2, y2);
}

class DetectedObject {
  const DetectedObject({
    required this.id,
    required this.kind,
    required this.bbox,
    this.notes = '',
  });

  final String id;
  final ObjectKind kind;
  final NBox bbox;
  final String notes;

  factory DetectedObject.fromJson(Map<String, dynamic> j) => DetectedObject(
        id: (j['id'] ?? '').toString(),
        kind: ObjectKind.fromWire(j['kind'] as String?),
        bbox: NBox.fromList(j['bbox'] as List<dynamic>),
        notes: (j['notes'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.wire,
        'bbox': bbox.toList(),
        'notes': notes,
      };

  DetectedObject copyWith({NBox? bbox, String? notes}) => DetectedObject(
        id: id,
        kind: kind,
        bbox: bbox ?? this.bbox,
        notes: notes ?? this.notes,
      );
}

class MachineInfo {
  const MachineInfo({
    this.clawCount = 0,
    this.armPower = ArmPower.unknown,
    this.assistLamp = AssistLamp.unknown,
    this.exitSide = ExitSide.unknown,
  });

  /// 2, 3, or 0 when unknown.
  final int clawCount;
  final ArmPower armPower;
  final AssistLamp assistLamp;
  final ExitSide exitSide;

  factory MachineInfo.fromJson(Map<String, dynamic> j) => MachineInfo(
        clawCount: (j['claw_count'] as num?)?.toInt() ?? 0,
        armPower: ArmPower.fromWire(j['arm_power_estimate'] as String?),
        assistLamp: AssistLamp.fromWire(j['assist_lamp'] as String?),
        exitSide: ExitSide.fromWire(j['exit_side'] as String?),
      );

  Map<String, dynamic> toJson() => {
        'claw_count': clawCount,
        'arm_power_estimate': armPower.wire,
        'assist_lamp': assistLamp.wire,
        'exit_side': exitSide.wire,
      };

  MachineInfo copyWith({
    int? clawCount,
    ArmPower? armPower,
    AssistLamp? assistLamp,
    ExitSide? exitSide,
  }) =>
      MachineInfo(
        clawCount: clawCount ?? this.clawCount,
        armPower: armPower ?? this.armPower,
        assistLamp: assistLamp ?? this.assistLamp,
        exitSide: exitSide ?? this.exitSide,
      );
}

class Strategy {
  const Strategy({
    this.technique = Technique.unknown,
    this.targetObjectId = '',
    this.targetEdge = TargetEdge.center,
    this.arm = Arm.both,
    this.sequence = const [],
    this.abortIf = const [],
    this.expectedMotion = '',
  });

  final Technique technique;
  final String targetObjectId;
  final TargetEdge targetEdge;
  final Arm arm;
  final List<String> sequence;
  final List<String> abortIf;
  final String expectedMotion;

  factory Strategy.fromJson(Map<String, dynamic> j) => Strategy(
        technique: Technique.fromWire(j['technique'] as String?),
        targetObjectId: (j['target_object_id'] ?? '').toString(),
        targetEdge: TargetEdge.fromWire(j['target_edge'] as String?),
        arm: Arm.fromWire(j['arm'] as String?),
        sequence: _stringList(j['sequence']),
        abortIf: _stringList(j['abort_if']),
        expectedMotion: (j['expected_motion'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'technique': technique.wire,
        'target_object_id': targetObjectId,
        'target_edge': targetEdge.wire,
        'arm': arm.wire,
        'sequence': sequence,
        'abort_if': abortIf,
        'expected_motion': expectedMotion,
      };
}

/// Result of analyzing one photo. Produced by the server (or the mock provider).
class AnalysisResult {
  const AnalysisResult({
    this.analysisId = '',
    this.provider = '',
    this.model = '',
    this.latencyMs = 0,
    this.imageWidth = 0,
    this.imageHeight = 0,
    required this.layoutType,
    required this.confidence,
    required this.machine,
    required this.objects,
    required this.strategy,
    this.explanation = '',
    this.needsMorePhotos = const [],
    this.warnings = const [],
  });

  final String analysisId;
  final String provider;
  final String model;
  final int latencyMs;

  /// Pixel size of the image the coordinates refer to (0 when unknown).
  final int imageWidth;
  final int imageHeight;

  final LayoutType layoutType;
  final double confidence;
  final MachineInfo machine;
  final List<DetectedObject> objects;
  final Strategy strategy;
  final String explanation;
  final List<String> needsMorePhotos;
  final List<String> warnings;

  factory AnalysisResult.fromJson(Map<String, dynamic> j) {
    final image = j['image'] as Map<String, dynamic>?;
    return AnalysisResult(
      analysisId: (j['analysis_id'] ?? '').toString(),
      provider: (j['provider'] ?? '').toString(),
      model: (j['model'] ?? '').toString(),
      latencyMs: (j['latency_ms'] as num?)?.toInt() ?? 0,
      imageWidth: (image?['width'] as num?)?.toInt() ?? 0,
      imageHeight: (image?['height'] as num?)?.toInt() ?? 0,
      layoutType: LayoutType.fromWire(j['layout_type'] as String?),
      confidence: ((j['confidence'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      machine: j['machine'] is Map<String, dynamic>
          ? MachineInfo.fromJson(j['machine'] as Map<String, dynamic>)
          : const MachineInfo(),
      objects: (j['objects'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DetectedObject.fromJson)
          .toList(),
      strategy: j['strategy'] is Map<String, dynamic>
          ? Strategy.fromJson(j['strategy'] as Map<String, dynamic>)
          : const Strategy(),
      explanation: (j['explanation'] ?? '').toString(),
      needsMorePhotos: _stringList(j['needs_more_photos']),
      warnings: _stringList(j['warnings']),
    );
  }

  Map<String, dynamic> toJson() => {
        'analysis_id': analysisId,
        'provider': provider,
        'model': model,
        'latency_ms': latencyMs,
        'image': {'width': imageWidth, 'height': imageHeight},
        'layout_type': layoutType.wire,
        'confidence': confidence,
        'machine': machine.toJson(),
        'objects': objects.map((o) => o.toJson()).toList(),
        'strategy': strategy.toJson(),
        'explanation': explanation,
        'needs_more_photos': needsMorePhotos,
        'warnings': warnings,
      };

  AnalysisResult copyWith({
    LayoutType? layoutType,
    double? confidence,
    MachineInfo? machine,
    List<DetectedObject>? objects,
    Strategy? strategy,
    String? explanation,
    List<String>? needsMorePhotos,
    List<String>? warnings,
  }) =>
      AnalysisResult(
        analysisId: analysisId,
        provider: provider,
        model: model,
        latencyMs: latencyMs,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        layoutType: layoutType ?? this.layoutType,
        confidence: confidence ?? this.confidence,
        machine: machine ?? this.machine,
        objects: objects ?? this.objects,
        strategy: strategy ?? this.strategy,
        explanation: explanation ?? this.explanation,
        needsMorePhotos: needsMorePhotos ?? this.needsMorePhotos,
        warnings: warnings ?? this.warnings,
      );

  /// Objects of a given kind, in detection order.
  List<DetectedObject> ofKind(ObjectKind kind) =>
      objects.where((o) => o.kind == kind).toList();

  DetectedObject? byId(String id) {
    for (final o in objects) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// The prize the strategy targets, falling back to the first prize object.
  DetectedObject? get targetPrize {
    final byStrategy = byId(strategy.targetObjectId);
    if (byStrategy != null && byStrategy.kind.isPrize) return byStrategy;
    for (final o in objects) {
      if (o.kind.isPrize) return o;
    }
    return null;
  }

  /// Replaces (or inserts) an object with the same id.
  AnalysisResult withObject(DetectedObject obj) {
    final list = [...objects];
    final i = list.indexWhere((o) => o.id == obj.id);
    if (i >= 0) {
      list[i] = obj;
    } else {
      list.add(obj);
    }
    return copyWith(objects: list);
  }
}

List<String> _stringList(dynamic v) =>
    (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();
