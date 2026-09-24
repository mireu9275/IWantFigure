import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/aim_engine.dart';
import 'package:iwantfigure/models/analysis.dart';

AnalysisResult _sample() {
  final json = jsonDecode(File('assets/samples/bridge_parallel.json').readAsStringSync())
      as Map<String, dynamic>;
  return AnalysisResult.fromJson(json);
}

void main() {
  const engine = AimEngine();

  test('sample analysis parses and round-trips', () {
    final r = _sample();
    expect(r.layoutType, LayoutType.bridgeParallel);
    expect(r.objects.length, 5);
    expect(r.targetPrize?.id, 'box1');
    final again = AnalysisResult.fromJson(r.toJson());
    expect(again.strategy.technique, Technique.tateHame);
    expect(again.objects.first.bbox, r.objects.first.bbox);
  });

  test('bridge_parallel with a heavy box plans 縦ハメ with alternating arms', () {
    final plan = engine.plan(_sample(), prize: PrizeSpec.defaultFigureBox.copyWith(massG: 400));
    expect(plan.canPlan, isTrue);
    expect(plan.technique, Technique.tateHame);
    expect(plan.steps.length, greaterThanOrEqualTo(2));
    final arms = plan.steps.map((s) => s.arm).toSet();
    expect(arms, containsAll([Arm.left, Arm.right]));
    final prize = plan.overlay!.prizeBbox;
    for (final s in plan.steps) {
      expect(s.clawPoint.x, inInclusiveRange(0, 1));
      expect(s.clawPoint.y, inInclusiveRange(0, 1));
      // The tip touches the prize top face.
      expect(s.tipPoint.x, inInclusiveRange(prize.x1, prize.x2));
      expect(s.tipPoint.y, inInclusiveRange(prize.y1, prize.y2));
      expect(s.title, isNotEmpty);
    }
    expect(plan.scene.cylinders.length, 2);
    expect(plan.scene.boxes.any((b) => b.id == 'prize'), isTrue);
    expect(plan.scene.motion, isNotNull);
    expect(plan.overlay!.barsSynthesized, isFalse);
    expect(plan.current!.arm, Arm.right);
  });

  test('a light box with a wide gap plans 横ハメ; a narrow gap forces 縦ハメ', () {
    final light = PrizeSpec(widthMm: 100, depthMm: 200, heightMm: 80, massG: 150);
    final wide = engine.plan(
      _sample().copyWith(strategy: const Strategy(technique: Technique.yokoHame, targetObjectId: 'box1')),
      prize: light,
    );
    expect(wide.technique, Technique.yokoHame);

    final narrow = engine.plan(
      _sample().copyWith(strategy: const Strategy(technique: Technique.yokoHame, targetObjectId: 'box1')),
      prize: light.copyWith(widthMm: 190),
    );
    expect(narrow.technique, Technique.tateHame);
    expect(narrow.warnings.any((w) => w.contains('横ハメ')), isTrue);
  });

  test('observations drive the current step and the arm-power estimate', () {
    final r = _sample();
    final p0 = engine.plan(r);
    final p1 = engine.plan(r, observations: const [Observation(ObservationKind.smallMove)]);
    expect(p1.currentStepIndex, (p0.currentStepIndex + 1) % p0.steps.length);

    final weak = engine.plan(r, observations: const [
      Observation(ObservationKind.noMove),
      Observation(ObservationKind.noMove),
    ]);
    expect(weak.armPowerEstimate, ArmPower.weak);
    // Weak arm → aim closer to the very edge (smaller inset → larger u → higher on the top face).
    final tate0 = p0.steps.firstWhere((s) => s.technique == Technique.tateHame);
    final tateW = weak.steps.firstWhere((s) => s.technique == Technique.tateHame);
    expect(tateW.tipPoint.y, lessThan(tate0.tipPoint.y));

    final strong = engine.plan(r, observations: const [Observation(ObservationKind.lifted)]);
    expect(strong.armPowerEstimate, ArmPower.strong);

    final done = engine.plan(r, observations: const [Observation(ObservationKind.dropped)]);
    expect(done.finished, isTrue);

    final stuck = engine.plan(r, observations: const [Observation(ObservationKind.stuck)]);
    expect(stuck.warnings.any((w) => w.contains('初期位置')), isTrue);
  });

  test('user corrections override detected geometry', () {
    final r = _sample();
    const moved = NBox(0.10, 0.40, 0.30, 0.70);
    final plan = engine.plan(r, corrections: const SceneCorrections(prizeBbox: moved, yawDeg: 12));
    expect(plan.overlay!.prizeBbox, moved);
    // Telling the engine the box sits toward the back adds a pull-forward step first.
    final back = engine.plan(r, corrections: const SceneCorrections(boxYOffsetMm: -60));
    expect(back.steps.first.technique, Technique.yose);
    expect(back.scene.boxById('prize')!.pose.position.y, -60);
    expect(plan.steps.first.tipPoint.x, inInclusiveRange(moved.x1, moved.x2));
    expect(plan.scene.boxById('prize')!.pose.rotation.yawDeg, 12);
    // Prize moved to the left of the field → negative X in the scene.
    expect(plan.scene.boxById('prize')!.pose.position.x, lessThan(0));
  });

  test('missing bars are synthesized with a warning', () {
    final r = _sample();
    final noBars = r.copyWith(objects: r.objects.where((o) => !o.kind.isBar).toList());
    final plan = engine.plan(noBars);
    expect(plan.canPlan, isTrue);
    expect(plan.overlay!.barsSynthesized, isTrue);
    expect(plan.overlay!.frontBar, isNotNull);
    expect(plan.warnings.any((w) => w.contains('바')), isTrue);
  });

  test('front_drop: alternate 寄せ, then 押し込み after enough movement', () {
    final r = _sample().copyWith(
      layoutType: LayoutType.frontDrop,
      strategy: const Strategy(technique: Technique.yose, targetObjectId: 'box1'),
      machine: const MachineInfo(clawCount: 2, exitSide: ExitSide.front),
    );
    final plan = engine.plan(r);
    expect(plan.technique, Technique.yose);
    expect(plan.steps.length, 3);
    expect(plan.steps.last.technique, Technique.oshikomi);
    expect(plan.currentStepIndex, 0);
    final later = engine.plan(r, observations: const [
      Observation(ObservationKind.bigMove),
      Observation(ObservationKind.smallMove),
      Observation(ObservationKind.bigMove),
    ]);
    expect(later.currentStepIndex, 2);
    expect(plan.scene.cylinders, isEmpty);
    expect(plan.scene.dropHole, isNotNull);
  });

  test('ring and plush layouts aim on the object bbox', () {
    final ring = _sample().copyWith(
      layoutType: LayoutType.ringPera,
      strategy: const Strategy(technique: Technique.hikkake, targetObjectId: 'box1'),
      objects: [
        const DetectedObject(id: 'box1', kind: ObjectKind.box, bbox: NBox(0.3, 0.4, 0.7, 0.8)),
        const DetectedObject(id: 'ring1', kind: ObjectKind.ring, bbox: NBox(0.45, 0.30, 0.55, 0.40)),
      ],
    );
    final plan = engine.plan(ring);
    expect(plan.technique, Technique.hikkake);
    expect(plan.steps.single.tipPoint.x, closeTo(0.5, 0.02));
    expect(plan.steps.single.tipPoint.y, closeTo(0.345, 0.02));

    final plush = _sample().copyWith(
      layoutType: LayoutType.threeClaw,
      strategy: const Strategy(technique: Technique.mochiage, targetObjectId: 'p1'),
      objects: [const DetectedObject(id: 'p1', kind: ObjectKind.plush, bbox: NBox(0.3, 0.3, 0.7, 0.8))],
    );
    final pp = engine.plan(plush);
    expect(pp.steps.single.technique, Technique.mochiage);
    expect(pp.steps.single.tipPoint.x, closeTo(0.5, 0.02));
  });

  test('unknown layout yields no plan but asks for photos', () {
    final r = _sample().copyWith(layoutType: LayoutType.unknown);
    final plan = engine.plan(r);
    expect(plan.canPlan, isFalse);
    expect(plan.requestedPhotos, isNotEmpty);
  });

  test('all layout types produce a plan or a photo request, in every locale', () {
    for (final layout in LayoutType.values) {
      for (final locale in ['ko', 'ja', 'en']) {
        final r = _sample().copyWith(layoutType: layout, strategy: const Strategy());
        final plan = engine.plan(r, locale: locale);
        if (layout == LayoutType.unknown) {
          expect(plan.canPlan, isFalse);
        } else {
          expect(plan.canPlan, isTrue, reason: '$layout/$locale');
          expect(plan.steps, isNotEmpty, reason: '$layout/$locale');
          expect(plan.current!.detail, isNotEmpty);
        }
      }
    }
  });
}
