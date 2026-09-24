/// Output of the aim engine.
library;

import '../models/analysis.dart';
import '../models/scene.dart';

/// One recommended play.
class AimStep {
  const AimStep({
    required this.index,
    required this.arm,
    required this.technique,
    required this.edge,
    required this.clawPoint,
    required this.tipPoint,
    required this.fieldPoint,
    required this.title,
    required this.detail,
  });

  /// 1-based play number within the sequence.
  final int index;

  /// Arm that makes contact.
  final Arm arm;
  final Technique technique;
  final TargetEdge edge;

  /// Where the *centre of the claw unit* should be, in normalized image
  /// coordinates. This is what the player steers.
  final Pt clawPoint;

  /// Where the chosen arm's tip touches the prize (normalized image coords).
  final Pt tipPoint;

  /// Claw centre in field coordinates (mm) at the moment of contact.
  final Vec3 fieldPoint;

  /// Short instruction, e.g. "오른쪽 아암을 안쪽 끝에".
  final String title;

  /// One or two sentences explaining what should happen.
  final String detail;
}

/// Everything the 2D overlay needs to draw on top of the photo.
class OverlayGeometry {
  const OverlayGeometry({
    required this.prizeBbox,
    required this.topFace,
    this.frontBar,
    this.backBar,
    this.dropHole,
    this.claw,
    this.motionFrom,
    this.motionTo,
    this.barsSynthesized = false,
    this.extraBars = const [],
  });

  final NBox prizeBbox;

  /// Top face of the prize as 4 points: front-left, front-right, back-right, back-left.
  final List<Pt> topFace;

  /// Bar centre lines as [p0, p1].
  final List<Pt>? frontBar;
  final List<Pt>? backBar;

  /// Additional detected bars (3-/4-bar setups), as centre lines.
  final List<List<Pt>> extraBars;
  final NBox? dropHole;
  final NBox? claw;

  /// Arrow showing the expected motion of the prize.
  final Pt? motionFrom;
  final Pt? motionTo;

  /// True when the bars were not detected and were placed by heuristics.
  final bool barsSynthesized;
}

class AimPlan {
  const AimPlan({
    required this.layoutType,
    required this.technique,
    required this.confidence,
    required this.steps,
    required this.currentStepIndex,
    required this.abortIf,
    required this.rationale,
    required this.warnings,
    required this.armPowerEstimate,
    required this.overlay,
    required this.scene,
    this.requestedPhotos = const [],
    this.finished = false,
    this.barCount = 0,
    this.clawRotation = ClawRotation.unknown,
  });

  final LayoutType layoutType;
  final Technique technique;
  final double confidence;

  /// Recommended sequence; empty when the engine cannot plan.
  final List<AimStep> steps;

  /// Index into [steps] of the play to make now.
  final int currentStepIndex;
  final List<String> abortIf;

  /// Why this aim point: bullet-style sentences.
  final List<String> rationale;
  final List<String> warnings;
  final ArmPower armPowerEstimate;

  /// Null when no prize was found.
  final OverlayGeometry? overlay;
  final Scene3D scene;

  /// Extra photos the analysis asked for (from the LLM or the engine).
  final List<String> requestedPhotos;

  /// True once an observation reports the prize dropped.
  final bool finished;

  /// Number of bars in the scene (0 for non-bridge layouts).
  final int barCount;

  /// Claw twist during descent that the plan compensates for.
  final ClawRotation clawRotation;

  bool get canPlan => steps.isNotEmpty && overlay != null;

  AimStep? get current => canPlan ? steps[currentStepIndex] : null;
}
