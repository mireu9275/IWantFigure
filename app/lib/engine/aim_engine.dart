/// Rule-based aim engine.
///
/// Takes the photo analysis (layout type + detected objects), optional user
/// corrections, the prize size and the observations from previous plays, and
/// produces a concrete plan: where the claw should go on the photo, the same
/// point in a parametric 3D scene, the play sequence and the reasoning.
///
/// The rules encode Japanese crane-game community heuristics
/// (橋渡し = hook a claw tip just inside the box end and alternate sides,
/// heavy box → 縦ハメ, light box → 横ハメ, 前落とし = 寄せ then 押し込み, …).
/// They are deliberately transparent and tunable through [EngineOptions].
library;

import 'dart:math' as math;

import '../models/analysis.dart';
import '../models/scene.dart';
import 'aim_plan.dart';
import 'inputs.dart';

export 'aim_plan.dart';
export 'inputs.dart';

class AimEngine {
  const AimEngine({this.options = EngineOptions.defaults});

  final EngineOptions options;

  /// Techniques that make sense for each layout. The first entry is the
  /// default when the analysis did not propose a valid technique.
  static const Map<LayoutType, List<Technique>> validTechniques = {
    LayoutType.bridgeParallel: [
      Technique.tateHame,
      Technique.yokoHame,
      Technique.zurashi,
      Technique.yose,
      Technique.noriage,
      Technique.kadoOshi,
    ],
    LayoutType.bridgeHanoji: [
      Technique.noriage,
      Technique.mochiage,
      Technique.yose,
      Technique.zurashi,
      Technique.tateHame,
    ],
    LayoutType.bridgeStep: [
      Technique.noriage,
      Technique.mochiage,
      Technique.zurashi,
      Technique.tateHame,
    ],
    LayoutType.frontDrop: [
      Technique.yose,
      Technique.oshikomi,
      Technique.mochiage,
      Technique.zurashi,
    ],
    LayoutType.valleyDrop: [Technique.noriage, Technique.tsuki, Technique.oshikomi],
    LayoutType.sideDrop: [Technique.yose, Technique.oshikomi, Technique.zurashi],
    LayoutType.ringPera: [Technique.hikkake, Technique.yose],
    LayoutType.ringD: [Technique.yose, Technique.hikkake, Technique.oshikomi],
    LayoutType.hookS: [Technique.hikkake],
    LayoutType.takoyaki: [Technique.otoshi],
    LayoutType.threeClaw: [Technique.mochiage, Technique.hikkake, Technique.yose],
    LayoutType.twoClawDirect: [Technique.hikkake, Technique.mochiage, Technique.yose],
    LayoutType.pile: [Technique.nadare, Technique.yose, Technique.oshikomi],
    LayoutType.floorBox: [
      Technique.kadoOshi,
      Technique.mochiage,
      Technique.yokoHame,
      Technique.yose,
    ],
    LayoutType.unknown: [],
  };

  AimPlan plan(
    AnalysisResult analysis, {
    PrizeSpec? prize,
    SceneCorrections corrections = SceneCorrections.none,
    List<Observation> observations = const [],
    String locale = 'ko',
  }) {
    final t = _Tr(locale);
    final warnings = <String>[...analysis.warnings];
    final rationale = <String>[];

    final prizeObj = analysis.targetPrize;
    final prizeBbox = corrections.prizeBbox ?? prizeObj?.bbox;
    if (prizeBbox == null || analysis.layoutType == LayoutType.unknown) {
      return _noPlan(analysis, t, warnings);
    }

    final spec = prize ??
        (prizeObj?.kind == ObjectKind.plush
            ? PrizeSpec.defaultPlush
            : PrizeSpec.defaultFigureBox);

    final geo = _Geometry.build(
      analysis: analysis,
      prizeBbox: prizeBbox,
      spec: spec,
      corrections: corrections,
      options: options,
    );
    if (geo.barsSynthesized && analysis.layoutType.isBridge) {
      warnings.add(t(
        ko: '바(バー) 위치를 사진에서 찾지 못해 추정했습니다. 보정 모드에서 앞·뒤 바를 맞춰 주세요.',
        ja: 'バーの位置を検出できなかったため推定しています。補正モードで手前・奥バーを合わせてください。',
        en: 'Bars were not detected; their position is estimated. Adjust the front/back bars in correction mode.',
      ));
    }

    final armPower = _estimateArmPower(analysis.machine.armPower, observations);
    final technique = _chooseTechnique(
      analysis: analysis,
      spec: spec,
      geo: geo,
      armPower: armPower,
      rationale: rationale,
      warnings: warnings,
      t: t,
    );

    final steps = _buildSteps(
      layout: analysis.layoutType,
      technique: technique,
      analysis: analysis,
      geo: geo,
      spec: spec,
      armPower: armPower,
      rationale: rationale,
      t: t,
    );
    final abortIf = _abortConditions(analysis, technique, t);

    final finished =
        observations.isNotEmpty && observations.last.kind == ObservationKind.dropped;
    final stuck =
        observations.isNotEmpty && observations.last.kind == ObservationKind.stuck;
    if (stuck) {
      warnings.add(t(
        ko: '詰み(막힘) 상태입니다. 점원에게 「初期位置に戻してください」(초기 위치로 돌려 주세요)라고 요청하세요.',
        ja: '詰みの形です。店員に「初期位置に戻してください」と依頼しましょう。',
        en: 'The prize is stuck (詰み). Ask the staff: 「初期位置に戻してください」 (please reset to the initial position).',
      ));
    }
    if (armPower == ArmPower.weak) {
      rationale.add(t(
        ko: '아암이 약한 것으로 관찰되어 발톱을 더 끝(端ギリギリ)에 걸도록 조준점을 옮겼습니다. 힘점이 무게중심에서 멀수록 적은 힘으로 크게 회전합니다.',
        ja: 'アームが弱いと観察されたため、爪を端ギリギリに掛けるよう狙いを寄せました。力点が重心から遠いほど小さな力で大きく回転します。',
        en: 'The arm looks weak, so the aim moved closer to the very edge (端ギリギリ): the farther the contact is from the centre of mass, the more it rotates per play.',
      ));
    }

    final currentIndex = _currentStepIndex(analysis.layoutType, technique, steps, observations);
    final current = steps.isEmpty ? null : steps[currentIndex];

    final scene = _buildScene(
      analysis: analysis,
      geo: geo,
      spec: spec,
      technique: technique,
      current: current,
      corrections: corrections,
      t: t,
    );
    final overlay = _buildOverlay(geo, technique, current);

    return AimPlan(
      layoutType: analysis.layoutType,
      technique: technique,
      confidence: analysis.confidence,
      steps: steps,
      currentStepIndex: currentIndex,
      abortIf: abortIf,
      rationale: rationale,
      warnings: warnings,
      armPowerEstimate: armPower,
      overlay: overlay,
      scene: scene,
      requestedPhotos: analysis.needsMorePhotos,
      finished: finished,
    );
  }

  // ---------------------------------------------------------------------------
  // No-plan fallback

  AimPlan _noPlan(AnalysisResult analysis, _Tr t, List<String> warnings) {
    final requested = [...analysis.needsMorePhotos];
    if (requested.isEmpty) {
      requested.add(t(
        ko: '기계 정면에서 경품과 아암, 바가 모두 보이도록 다시 촬영해 주세요.',
        ja: '景品・アーム・バーがすべて写るように正面から撮り直してください。',
        en: 'Take another photo from the front showing the prize, the claw and the bars.',
      ));
    }
    return AimPlan(
      layoutType: analysis.layoutType,
      technique: Technique.unknown,
      confidence: analysis.confidence,
      steps: const [],
      currentStepIndex: 0,
      abortIf: const [],
      rationale: const [],
      warnings: warnings,
      armPowerEstimate: analysis.machine.armPower,
      overlay: null,
      scene: const Scene3D(),
      requestedPhotos: requested,
    );
  }

  // ---------------------------------------------------------------------------
  // Arm power and technique selection

  static ArmPower _estimateArmPower(ArmPower base, List<Observation> obs) {
    var lifted = 0, big = 0, none = 0;
    for (final o in obs) {
      switch (o.kind) {
        case ObservationKind.lifted:
          lifted++;
        case ObservationKind.bigMove:
          big++;
        case ObservationKind.noMove:
          none++;
        default:
          break;
      }
    }
    if (lifted > 0) return ArmPower.strong;
    if (big > 0) return ArmPower.medium;
    if (none >= 2) return ArmPower.weak;
    return base;
  }

  Technique _chooseTechnique({
    required AnalysisResult analysis,
    required PrizeSpec spec,
    required _Geometry geo,
    required ArmPower armPower,
    required List<String> rationale,
    required List<String> warnings,
    required _Tr t,
  }) {
    final layout = analysis.layoutType;
    final valid = validTechniques[layout] ?? const <Technique>[];
    var technique = valid.contains(analysis.strategy.technique)
        ? analysis.strategy.technique
        : (valid.isEmpty ? Technique.unknown : valid.first);

    switch (layout) {
      case LayoutType.bridgeParallel:
        if (technique == Technique.tateHame || technique == Technique.yokoHame) {
          // Community rule: heavy → 縦ハメ, light → 横ハメ; and 横ハメ needs a
          // gap wider than the box width.
          final wantYoko = !spec.isHeavy && analysis.strategy.technique != Technique.tateHame;
          technique = wantYoko ? Technique.yokoHame : Technique.tateHame;
          if (technique == Technique.yokoHame && geo.barGapMm < spec.widthMm * 1.05) {
            technique = Technique.tateHame;
            warnings.add(t(
              ko: '바 간격(약 ${geo.barGapMm.round()}mm)이 박스 폭(${spec.widthMm.round()}mm)보다 좁아 横ハメ가 불가능합니다. 縦ハメ로 진행합니다.',
              ja: 'バー間隔(約${geo.barGapMm.round()}mm)が箱の幅(${spec.widthMm.round()}mm)より狭いため横ハメはできません。縦ハメで進めます。',
              en: 'The bar gap (~${geo.barGapMm.round()} mm) is narrower than the box width (${spec.widthMm.round()} mm), so 横ハメ is impossible. Using 縦ハメ.',
            ));
          }
          rationale.add(technique == Technique.tateHame
              ? t(
                  ko: '橋渡し: 아암 파워는 보통 박스를 들어 올리기에 부족하게 설정되므로 "잡기"가 아니라 "조금씩 회전시켜 바 사이로 떨어뜨리기"가 목표입니다. 무거운 박스(${spec.massG?.round() ?? '~300'}g)는 세워서 끼우는 縦ハメ가 정석입니다.',
                  ja: '橋渡し: アームパワーは箱を持ち上げられないよう設定されるのが普通なので、「掴む」ではなく「少しずつ回転させてバーの間に落とす」のが目標です。重い箱(${spec.massG?.round() ?? '約300'}g)は縦ハメが定石です。',
                  en: 'Bridge setup: the arm is usually too weak to lift the box, so the goal is to rotate it little by little until it drops between the bars. A heavy box (${spec.massG?.round() ?? '~300'} g) is stood up (縦ハメ).',
                )
              : t(
                  ko: '橋渡し: 가벼운 박스는 바에 수평이 되도록 돌려 넓은 틈으로 떨어뜨리는 横ハメ가 유리합니다.',
                  ja: '橋渡し: 軽い箱はバーと平行になるよう回して隙間に落とす横ハメが有利です。',
                  en: 'Bridge setup: a light box is turned parallel to the bars so it drops flat through the gap (横ハメ).',
                ));
        }
      case LayoutType.bridgeHanoji:
        if (armPower == ArmPower.strong && technique == Technique.noriage) {
          technique = Technique.mochiage;
        }
        if (armPower != ArmPower.strong && technique == Technique.mochiage) {
          technique = Technique.noriage;
        }
        rationale.add(t(
          ko: '末広がり: 바가 벌어지는 넓은 쪽으로 박스를 회전·이동시키면 빠집니다. 아암이 강하면 들어 올리기(つまみ上げ), 아니면 안쪽 모서리를 바 위에 얹는 乗り上げ.',
          ja: '末広がり: バーが広がる側へ箱を回転・移動させれば落ちます。アームが強ければつまみ上げ、そうでなければ奥角をバーに乗せる乗り上げ。',
          en: 'Widening bars: rotate/move the box toward the wide end. Strong arm → lift; otherwise rest an inner corner on a bar (乗り上げ).',
        ));
      case LayoutType.bridgeStep:
        rationale.add(t(
          ko: '段差/ピンクチューブ: 고무 튜브는 마찰이 커서 미끄러뜨리기(ずり上げ)가 통하지 않습니다. 들어 올리거나 회전시키는 기법으로 갑니다.',
          ja: '段差/ピンクチューブ: ゴムチューブは摩擦が大きく、ずり上げは効きません。持ち上げ・回転系で攻めます。',
          en: 'Step/pink tube: rubber tubes have high friction, so sliding does not work; lift or rotate instead.',
        ));
      case LayoutType.frontDrop:
        rationale.add(t(
          ko: '前落とし: 노리는 쪽과 반대 아암으로 끌어당기듯(寄せ) 좌우 번갈아 앞으로 옮기고, 충분히 앞에 오면 튀어나온 부분을 눌러(押し込み) 떨어뜨립니다. 서둘러 일찍 밀면 낭비입니다.',
          ja: '前落とし: 狙う側と反対のアームで引き寄せるように(寄せ)左右交互に前へ運び、十分手前に来たらはみ出した部分を押し込みます。早く押しすぎると無駄になります。',
          en: 'Front drop: pull the prize forward with alternating arms (寄せ), and only when it overhangs the edge push it down (押し込み). Pushing too early wastes plays.',
        ));
      case LayoutType.floorBox:
        rationale.add(t(
          ko: '箱直置き: 아암이 열렸을 때 발톱이 박스 틈·모서리에 맞도록 조정하고, 낙하구에 가까운 모서리를 들어 올려 무게중심을 밖으로 보냅니다.',
          ja: '箱直置き: 開いた爪が箱の隙間・角に合うよう調整し、落とし口に近い角を持ち上げて重心を外に出します。',
          en: 'Box on the floor: match the open claw to a box corner/gap and lift the corner nearest the exit so the centre of mass moves out.',
        ));
      case LayoutType.threeClaw:
        rationale.add(t(
          ko: '3本爪: 인형의 무게중심을 세 발톱이 감싸야 합니다. 발톱 두 개만 걸리면 무게를 못 견딥니다. 대부분 확률기이므로 임계 전에는 이동 기법만 유효할 수 있습니다(추정).',
          ja: '3本爪: ぬいぐるみの重心を3本の爪で包む必要があります。2本しか掛からないと持ちません。確率機が多いので天井前は移動系のみ有効なことがあります(推定)。',
          en: 'Three-claw: all three tips must wrap the plush\'s centre of mass. Many are probability machines, so before the threshold only moving techniques may work (estimate).',
        ));
      default:
        break;
    }
    return technique;
  }

  // ---------------------------------------------------------------------------
  // Steps

  List<AimStep> _buildSteps({
    required LayoutType layout,
    required Technique technique,
    required AnalysisResult analysis,
    required _Geometry geo,
    required PrizeSpec spec,
    required ArmPower armPower,
    required List<String> rationale,
    required _Tr t,
  }) {
    final inset = armPower == ArmPower.weak ? options.edgeInset * 0.5 : options.edgeInset;
    final side = options.sideOffset;
    final steps = <AimStep>[];
    var n = 0;

    AimStep make({
      required Arm arm,
      required Technique tech,
      required TargetEdge edge,
      required double u,
      required double v,
      required String title,
      required String detail,
      bool onBbox = false,
    }) {
      n++;
      final tip = onBbox ? geo.prizeBbox.at(v, u) : geo.top(u, v);
      final shift = switch (arm) {
        Arm.right => -geo.halfOpenImg,
        Arm.left => geo.halfOpenImg,
        Arm.both => 0.0,
      };
      final claw = Pt(tip.x + shift, tip.y).clamp01();
      final tipField = onBbox
          ? geo.fieldOnBbox(v, u)
          : geo.prizeBox.pointAt(u, v, 1.0);
      final fieldShift = switch (arm) {
        Arm.right => -options.clawOpenWidthMm / 2,
        Arm.left => options.clawOpenWidthMm / 2,
        Arm.both => 0.0,
      };
      return AimStep(
        index: n,
        arm: arm,
        technique: tech,
        edge: edge,
        clawPoint: claw,
        tipPoint: tip.clamp01(),
        fieldPoint: Vec3(tipField.x + fieldShift, tipField.y, tipField.z),
        title: title,
        detail: detail,
      );
    }

    // Box sitting toward the back → pull it forward first (手前を狙う).
    // Known from the user's correction, or when the analysis itself proposed
    // pulling the front edge.
    final st = analysis.strategy;
    final llmSaysPullFront = st.technique == Technique.yose &&
        (st.targetEdge == TargetEdge.front ||
            st.targetEdge == TargetEdge.frontLeft ||
            st.targetEdge == TargetEdge.frontRight);
    final needsPullForward =
        layout.isBridge && (geo.boxYMm < -0.12 * spec.depthMm || llmSaysPullFront);

    switch (technique) {
      case Technique.tateHame:
        if (needsPullForward) {
          steps.add(make(
            arm: Arm.right,
            tech: Technique.yose,
            edge: TargetEdge.frontRight,
            u: inset,
            v: 0.5 + side,
            title: t(ko: '먼저 앞쪽 끝을 당겨 오기(寄せ)', ja: 'まず手前の端を寄せる', en: 'First pull the front end forward (寄せ)'),
            detail: t(
              ko: '박스가 안쪽(奥)으로 치우쳐 있습니다. 오른쪽 아암 발톱을 앞쪽 끝 윗면에 걸어 닫히는 힘으로 手前로 당깁니다.',
              ja: '箱が奥に寄っています。右アームの爪を手前端の上面に掛け、閉じる力で手前へ引きます。',
              en: 'The box sits toward the back. Hook the right arm tip on the top of the front end so the closing motion drags it forward.',
            ),
          ));
        }
        steps.add(make(
          arm: Arm.right,
          tech: Technique.tateHame,
          edge: TargetEdge.backRight,
          u: 1 - inset,
          v: 0.5 + side,
          title: t(ko: '오른쪽 아암 끝을 안쪽(奥) 끝 오른쪽에', ja: '右アームの爪を奥端の右側に', en: 'Right arm tip just inside the back-right end'),
          detail: t(
            ko: '발톱이 윗면 안쪽 끝에 아슬아슬하게(端ギリギリ) 걸리면 닫힐 때 안쪽 끝이 들리고, 박스가 앞바를 축으로 기울어 앞쪽이 바 사이로 내려갑니다.',
            ja: '爪が上面の奥端ギリギリに掛かると、閉じる際に奥端が持ち上がり、箱が手前バーを軸に傾いて前側がバーの間へ下がります。',
            en: 'With the tip hooked just inside the back end, closing lifts that end; the box tilts on the front bar and its front slides into the gap.',
          ),
        ));
        steps.add(make(
          arm: Arm.left,
          tech: Technique.tateHame,
          edge: TargetEdge.backLeft,
          u: 1 - inset,
          v: 0.5 - side,
          title: t(ko: '왼쪽 아암 끝을 안쪽 끝 왼쪽에 (교대)', ja: '左アームの爪を奥端の左側に(交互)', en: 'Left arm tip at the back-left end (alternate)'),
          detail: t(
            ko: '반대쪽에서 같은 동작을 반복해 박스가 한쪽으로 비틀리지 않게 하면서 조금씩 세웁니다. 세로로 낀 뒤에는 남은 모서리(残存角)를 한 번 더 밀어 떨어뜨립니다.',
            ja: '反対側から同じ動作を繰り返し、箱がねじれないようにしながら少しずつ立てます。縦にハマったら残存角をもう一度押して落とします。',
            en: 'Repeat from the other side so the box does not twist, standing it up bit by bit. Once it is wedged vertically, push the remaining corner once more.',
          ),
        ));
      case Technique.yokoHame:
        steps.add(make(
          arm: Arm.right,
          tech: Technique.yokoHame,
          edge: TargetEdge.backRight,
          u: 1 - inset,
          v: 0.5 + side + 0.1,
          title: t(ko: '안쪽 오른쪽 모서리를 밀어 회전 시작', ja: '奥の右角を押して回転開始', en: 'Push the back-right corner to start rotating'),
          detail: t(
            ko: '오른쪽 아암 발톱으로 안쪽 오른쪽 모서리를 걸어 닫히는 힘으로 박스를 반시계 방향으로 돌립니다.',
            ja: '右アームの爪で奥の右角を掛け、閉じる力で箱を反時計回りに回します。',
            en: 'Hook the back-right corner with the right arm so the closing motion turns the box counter-clockwise.',
          ),
        ));
        steps.add(make(
          arm: Arm.left,
          tech: Technique.yokoHame,
          edge: TargetEdge.frontLeft,
          u: inset,
          v: 0.5 - side - 0.1,
          title: t(ko: '반대 아암으로 앞쪽 왼쪽 모서리', ja: '反対のアームで手前の左角', en: 'Opposite arm on the front-left corner'),
          detail: t(
            ko: '대각선 반대 모서리를 밀어 회전을 이어갑니다. 박스의 긴 변이 바와 평행해지면 틈으로 떨어집니다. 가로로 두 바 위에 얹히면 詰み이므로 각도를 조금씩만 줍니다.',
            ja: '対角の角を押して回転を続けます。長辺がバーと平行になれば隙間に落ちます。横で両バーに乗ると詰みなので角度は少しずつ。',
            en: 'Push the diagonally opposite corner to continue the rotation; when the long side is parallel to the bars it drops through. Turn only a little per play — flat on both bars is a dead end.',
          ),
        ));
      case Technique.yose:
      case Technique.zurashi:
        final toLeft = analysis.machine.exitSide == ExitSide.left;
        final toRight = analysis.machine.exitSide == ExitSide.right;
        if (layout == LayoutType.sideDrop || toLeft || toRight) {
          final arm = toLeft ? Arm.right : Arm.left;
          final v = toLeft ? 1 - inset : inset;
          steps.add(make(
            arm: arm,
            tech: Technique.yose,
            edge: toLeft ? TargetEdge.right : TargetEdge.left,
            u: 0.35,
            v: v,
            title: t(ko: '측면 끝에 걸어 낙하구 쪽으로 당기기', ja: '側面の端に掛けて落とし口へ寄せる', en: 'Hook the side edge and drag toward the exit'),
            detail: t(
              ko: '낙하구 반대쪽 아암의 발톱을 박스 측면 끝에 걸면 닫히는 동작이 박스를 낙하구 쪽으로 끌어당깁니다.',
              ja: '落とし口と反対側のアームの爪を側面の端に掛けると、閉じる動作が箱を落とし口へ引きます。',
              en: 'Hook the tip of the arm opposite to the exit on the side edge; the closing motion drags the box toward the exit.',
            ),
          ));
          steps.add(make(
            arm: arm,
            tech: Technique.yose,
            edge: toLeft ? TargetEdge.right : TargetEdge.left,
            u: 0.65,
            v: v,
            title: t(ko: '같은 쪽, 다른 끝 (교대)', ja: '同じ側、別の端(交互)', en: 'Same side, other end (alternate)'),
            detail: t(
              ko: '앞·뒤 끝을 번갈아 당겨 박스가 비틀리지 않게 평행 이동시킵니다.',
              ja: '前後の端を交互に寄せて、ねじれないよう平行移動させます。',
              en: 'Alternate the front and back ends so the box slides straight instead of twisting.',
            ),
          ));
        } else {
          steps.add(make(
            arm: Arm.right,
            tech: Technique.yose,
            edge: TargetEdge.backRight,
            u: 1 - inset,
            v: 0.5 + side,
            title: t(ko: '오른쪽 아암 발톱을 안쪽 끝에 걸어 앞으로', ja: '右アームの爪を奥端に掛けて手前へ', en: 'Right arm tip on the back end, drag forward'),
            detail: t(
              ko: '안쪽 끝 윗면에 발톱을 걸면 닫힐 때 박스가 手前로 끌려옵니다. 가벼운 쪽(보통 하반부)을 노리면 한 번에 더 많이 움직입니다.',
              ja: '奥端の上面に爪を掛けると閉じる際に箱が手前へ引かれます。軽い側(通常下半分)を狙うと一度に大きく動きます。',
              en: 'Hooking the top of the back end drags the box forward as the claw closes. Aiming at the lighter half moves it more per play.',
            ),
          ));
          steps.add(make(
            arm: Arm.left,
            tech: Technique.yose,
            edge: TargetEdge.backLeft,
            u: 1 - inset,
            v: 0.5 - side,
            title: t(ko: '왼쪽 아암으로 반대편 (교대)', ja: '左アームで反対側(交互)', en: 'Left arm on the other side (alternate)'),
            detail: t(
              ko: '좌우를 번갈아 당겨 박스가 돌아가지 않고 곧게 앞으로 오게 합니다.',
              ja: '左右交互に寄せて、箱が回らずまっすぐ手前に来るようにします。',
              en: 'Alternate sides so the box comes straight forward without rotating.',
            ),
          ));
          if (layout == LayoutType.frontDrop) {
            steps.add(make(
              arm: Arm.both,
              tech: Technique.oshikomi,
              edge: TargetEdge.front,
              u: inset,
              v: 0.5,
              title: t(ko: '앞이 단 밖으로 나오면 앞 모서리를 눌러 떨어뜨리기(押し込み)', ja: '手前がはみ出したら前角を押し込む', en: 'Once the front overhangs, push the front edge down (押し込み)'),
              detail: t(
                ko: '박스 앞부분이 낙하구 위로 충분히 나온 뒤에만 아암 본체나 발톱으로 앞 모서리를 아래로 누릅니다.',
                ja: '箱の手前部分が落とし口の上に十分出てから、アーム本体や爪で前角を下へ押します。',
                en: 'Only after the front part clearly overhangs the exit, press the front edge down with the claw body or tips.',
              ),
            ));
          }
        }
      case Technique.oshikomi:
        steps.add(make(
          arm: Arm.both,
          tech: Technique.oshikomi,
          edge: TargetEdge.front,
          u: inset,
          v: 0.5,
          title: t(ko: '앞 모서리를 눌러 떨어뜨리기(押し込み)', ja: '前角を押し込む', en: 'Push the front edge down (押し込み)'),
          detail: t(
            ko: '낙하구 위로 나온 앞부분을 하강하는 아암으로 눌러 무게중심을 밖으로 보냅니다.',
            ja: '落とし口の上に出た手前部分を下降するアームで押し、重心を外へ出します。',
            en: 'Press the overhanging front part with the descending claw to push the centre of mass past the edge.',
          ),
        ));
      case Technique.mochiage:
      case Technique.kadoOshi:
        final rightFirst = analysis.machine.exitSide != ExitSide.left;
        final corners = rightFirst
            ? [(Arm.right, TargetEdge.frontRight, 1 - inset), (Arm.left, TargetEdge.frontLeft, inset)]
            : [(Arm.left, TargetEdge.frontLeft, inset), (Arm.right, TargetEdge.frontRight, 1 - inset)];
        for (final (arm, edge, v) in corners) {
          steps.add(make(
            arm: arm,
            tech: technique,
            edge: edge,
            u: layout.isBridge ? 1 - inset : inset,
            v: v,
            title: technique == Technique.mochiage
                ? t(ko: '모서리를 들어 올리기(持ち上げ)', ja: '角を持ち上げる', en: 'Lift the corner (持ち上げ)')
                : t(ko: '모서리를 눌러 기울이기(角押し)', ja: '角を押して傾ける', en: 'Press the corner to tilt (角押し)'),
            detail: t(
              ko: '낙하구에 가까운 모서리에 발톱을 걸어 들거나 눌러 무게중심이 지지선 밖으로 나가게 합니다. 좌우 모서리를 번갈아 시도합니다.',
              ja: '落とし口に近い角に爪を掛けて持ち上げる/押して、重心が支点の外に出るようにします。左右の角を交互に試します。',
              en: 'Hook the corner nearest the exit and lift or press it so the centre of mass leaves the support line. Alternate the two corners.',
            ),
          ));
        }
      case Technique.noriage:
        steps.add(make(
          arm: Arm.both,
          tech: Technique.noriage,
          edge: TargetEdge.back,
          u: 0.7,
          v: 0.5,
          title: t(ko: '안쪽 모서리를 양 아암으로 들어 바 위에 얹기(乗り上げ)', ja: '奥角を両アームで持ち上げてバーに乗せる', en: 'Lift the inner corner with both arms onto the bar (乗り上げ)'),
          detail: t(
            ko: '박스를 완전히 들 수 없어도 안쪽 끝을 살짝 들어 뒤 바 위에 걸치면 균형이 깨져 다음 수에 떨어뜨리기 쉬워집니다.',
            ja: '箱を完全に持ち上げられなくても、奥端を少し持ち上げて奥バーに乗せればバランスが崩れ、次の手で落としやすくなります。',
            en: 'Even if you cannot lift the box, raising the back end onto the back bar breaks its balance and sets up the drop.',
          ),
        ));
        steps.add(make(
          arm: Arm.both,
          tech: Technique.tsuki,
          edge: TargetEdge.front,
          u: inset,
          v: 0.5,
          title: t(ko: '앞 모서리를 찔러(突き) 마무리', ja: '前角を突いて仕上げ', en: 'Finish by poking the front corner (突き)'),
          detail: t(
            ko: '얹힌 상태에서 앞쪽 모서리를 발톱으로 찔러 중력으로 넘어가게 합니다.',
            ja: '乗った状態で前角を爪で突き、重力で落とします。',
            en: 'With the box propped up, poke the front corner so gravity finishes the job.',
          ),
        ));
      case Technique.tsuki:
        steps.add(make(
          arm: Arm.both,
          tech: Technique.tsuki,
          edge: TargetEdge.front,
          u: inset,
          v: 0.5,
          title: t(ko: '앞 모서리를 찌르기(突き)', ja: '前角を突く', en: 'Poke the front corner (突き)'),
          detail: t(
            ko: '모서리를 찔러 들어 올린 뒤 중력으로 이동시킵니다.',
            ja: '角を突いて持ち上げ、重力で移動させます。',
            en: 'Poke the corner to lift it and let gravity move the box.',
          ),
        ));
      case Technique.hikkake:
        final ring = analysis.ofKind(ObjectKind.ring).isNotEmpty ? analysis.ofKind(ObjectKind.ring).first : null;
        final onRing = ring != null;
        final isPlush = layout == LayoutType.twoClawDirect || layout == LayoutType.threeClaw;
        steps.add(_withBbox(
          make,
          bbox: onRing ? ring.bbox : geo.prizeBbox,
          geo: geo,
          arm: Arm.both,
          tech: Technique.hikkake,
          edge: TargetEdge.center,
          fx: 0.5,
          fy: onRing ? 0.45 : (isPlush ? 0.35 : 0.4),
          title: onRing
              ? t(ko: '고리 구멍 중심보다 살짝 안쪽에 발톱 넣기(輪掛け)', ja: '輪の中心よりやや奥に爪を入れる', en: 'Put a claw tip slightly behind the ring centre (輪掛け)')
              : t(ko: '태그·목·팔 사이 등 걸리는 부위에 발톱 걸기', ja: 'タグ・首・腕の間など引っ掛かる部位に爪を掛ける', en: 'Hook a tip on the tag, neck or between limbs'),
          detail: onRing
              ? t(
                  ko: '구멍은 보기보다 작습니다. 첫 수는 아암 개방폭을 파악하는 용도로 생각하고, 움직이지 않으면 살짝 당기는 방향으로 조준을 바꿉니다.',
                  ja: '穴は見た目より小さいです。1手目は開き幅の把握用と考え、動かなければ少し寄せ気味に狙いを変えます。',
                  en: 'The hole is smaller than it looks. Treat the first play as a test of the claw opening width; if nothing moves, shift the aim slightly toward pulling.',
                )
              : t(
                  ko: '발톱 각도가 90°에 가까울수록 힘이 잘 전달됩니다. 소형 인형은 태그를 걸어 낙하구 쪽으로 당깁니다.',
                  ja: '爪の角度が90°に近いほど力が伝わります。小さいぬいぐるみはタグを掛けて落とし口へ寄せます。',
                  en: 'Claw tips near 90° transfer force best. For small plush, hook the tag and drag toward the exit.',
                ),
        ));
      case Technique.otoshi:
        steps.add(_withBbox(
          make,
          bbox: geo.prizeBbox,
          geo: geo,
          arm: Arm.both,
          tech: Technique.otoshi,
          edge: TargetEdge.center,
          fx: 0.5,
          fy: 0.3,
          title: t(ko: '가장 높게 쌓인 곳을 집기', ja: '一番高く積まれた所を掴む', en: 'Grab where the pile is highest'),
          detail: t(
            ko: '운 요소가 큰 설정입니다. 꽝 구멍이 이미 채워진 판이나 당첨 구멍에 가까운 위치를 고릅니다.',
            ja: '運要素の大きい設定です。ハズレ穴が埋まっている台や当たり穴に近い位置を選びます。',
            en: 'Luck-based setup. Prefer trays whose losing holes are already filled, and positions near the winning holes.',
          ),
        ));
      case Technique.nadare:
        steps.add(_withBbox(
          make,
          bbox: geo.prizeBbox,
          geo: geo,
          arm: Arm.both,
          tech: Technique.nadare,
          edge: TargetEdge.center,
          fx: 0.5,
          fy: 0.25,
          title: t(ko: '산 꼭대기 근처를 눌러 무너뜨리기(雪崩)', ja: '山の頂上付近を押して崩す(雪崩)', en: 'Press near the top of the pile to trigger an avalanche (雪崩)'),
          detail: t(
            ko: '寄せる·押す·すくう가 기본입니다. 경사가 낙하구 쪽으로 내려가는 방향으로 밀어 포텐셜 에너지를 무너뜨립니다.',
            ja: '寄せる・押す・すくうが基本。落とし口へ下る斜面の方向へ押して崩します。',
            en: 'Pull, push or scoop toward the exit so the slope collapses in that direction.',
          ),
        ));
      case Technique.unknown:
        break;
    }

    if (layout == LayoutType.threeClaw && technique == Technique.mochiage) {
      steps.clear();
      n = 0;
      steps.add(_withBbox(
        make,
        bbox: geo.prizeBbox,
        geo: geo,
        arm: Arm.both,
        tech: Technique.mochiage,
        edge: TargetEdge.center,
        fx: 0.5,
        fy: 0.55,
        title: t(ko: '무게중심을 세 발톱이 감싸도록 중앙에', ja: '重心を3本の爪で包むように中央へ', en: 'Centre the three tips around the centre of mass'),
        detail: t(
          ko: '발톱이 인형 아래로 들어갔는지 확인합니다. 실드(壁)에 걸리면 반대쪽을 들어 떨어뜨립니다.',
          ja: '爪がぬいぐるみの下に入ったか確認。シールドに掛かったら反対側を持ち上げて落とします。',
          en: 'Check that the tips go under the plush. If it catches on a shield, lift the opposite side to drop it.',
        ),
      ));
    }
    return steps;
  }

  /// Builds a step whose contact point is defined on an arbitrary bbox
  /// (rings, plush) instead of the box top face.
  AimStep _withBbox(
    AimStep Function({
      required Arm arm,
      required Technique tech,
      required TargetEdge edge,
      required double u,
      required double v,
      required String title,
      required String detail,
      bool onBbox,
    }) make, {
    required NBox bbox,
    required _Geometry geo,
    required Arm arm,
    required Technique tech,
    required TargetEdge edge,
    required double fx,
    required double fy,
    required String title,
    required String detail,
  }) {
    // Express the bbox point as a fraction of the prize bbox so `make` can use
    // its onBbox path (prize bbox frame).
    final p = bbox.at(fx, fy);
    final pb = geo.prizeBbox;
    final v = pb.width == 0 ? 0.5 : ((p.x - pb.x1) / pb.width);
    final u = pb.height == 0 ? 0.5 : ((p.y - pb.y1) / pb.height);
    return make(
      arm: arm,
      tech: tech,
      edge: edge,
      u: u,
      v: v,
      title: title,
      detail: detail,
      onBbox: true,
    );
  }

  static int _currentStepIndex(
    LayoutType layout,
    Technique technique,
    List<AimStep> steps,
    List<Observation> observations,
  ) {
    if (steps.isEmpty) return 0;
    final played = observations.where((o) => o.kind != ObservationKind.stuck).length;
    if (layout == LayoutType.frontDrop && steps.length == 3) {
      final moves = observations
          .where((o) => o.kind == ObservationKind.bigMove || o.kind == ObservationKind.smallMove)
          .length;
      if (moves >= 3) return 2;
      return played % 2;
    }
    if (technique == Technique.noriage && steps.length == 2) {
      final lifted = observations.any((o) => o.kind == ObservationKind.lifted || o.kind == ObservationKind.bigMove);
      return lifted ? 1 : 0;
    }
    return played % steps.length;
  }

  List<String> _abortConditions(AnalysisResult a, Technique technique, _Tr t) {
    final list = <String>[...a.strategy.abortIf];
    list.add(t(
      ko: '3수 연속 아무 변화가 없으면 조준점을 바꾸거나 철수합니다(설정이 약한 대).',
      ja: '3手連続で変化がなければ狙いを変えるか撤退(設定が弱い台)。',
      en: 'No change in 3 consecutive plays → change the aim or walk away (weak setting).',
    ));
    if (a.layoutType.isBridge) {
      list.add(t(
        ko: '박스가 가로로 두 바 위에 완전히 얹히면 詰み입니다. 점원에게 초기 위치 복귀를 요청하세요.',
        ja: '箱が横で両バーに完全に乗ったら詰み。店員に初期位置戻しを依頼。',
        en: 'If the box ends up flat across both bars it is stuck (詰み); ask the staff to reset it.',
      ));
    }
    if (a.layoutType == LayoutType.ringD || a.layoutType == LayoutType.ringPera) {
      list.add(t(
        ko: '링이 떨리기만 하고 이동하지 않으면 즉시 철수합니다.',
        ja: 'リングが震えるだけで動かなければ即撤退。',
        en: 'If the ring only vibrates without moving, stop immediately.',
      ));
    }
    return list;
  }

  // ---------------------------------------------------------------------------
  // Scene and overlay

  Scene3D _buildScene({
    required AnalysisResult analysis,
    required _Geometry geo,
    required PrizeSpec spec,
    required Technique technique,
    required AimStep? current,
    required SceneCorrections corrections,
    required _Tr t,
  }) {
    final layout = analysis.layoutType;
    final prize = geo.prizeBox;
    final boxes = <SceneBox>[prize];
    final cylinders = <SceneCylinder>[];
    SceneDropHole? hole;

    if (layout.isBridge) {
      final tube = layout == LayoutType.bridgeStep ||
          analysis.objects.any((o) => o.kind == ObjectKind.tubeBar);
      final hx = options.fieldWidthMm / 2;
      final backZ = layout == LayoutType.bridgeStep ? options.barHeightMm + 25 : options.barHeightMm;
      cylinders.add(SceneCylinder(
        id: 'bar_front',
        p0: Vec3(-hx, geo.barGapMm / 2, options.barHeightMm),
        p1: Vec3(hx, geo.barGapMm / 2, options.barHeightMm),
        radius: options.barRadiusMm,
        material: tube ? SceneMaterial.rubberTube : SceneMaterial.metal,
        label: t(ko: '앞 바(手前バー)', ja: '手前バー', en: 'front bar'),
      ));
      cylinders.add(SceneCylinder(
        id: 'bar_back',
        p0: Vec3(-hx, -geo.barGapMm / 2, backZ),
        p1: Vec3(hx, -geo.barGapMm / 2, backZ),
        radius: options.barRadiusMm,
        material: tube ? SceneMaterial.rubberTube : SceneMaterial.metal,
        label: t(ko: '뒤 바(奥バー)', ja: '奥バー', en: 'back bar'),
      ));
      hole = SceneDropHole(
        xMin: geo.boxXMm - options.fieldWidthMm * 0.3,
        xMax: geo.boxXMm + options.fieldWidthMm * 0.3,
        yMin: -geo.barGapMm / 2 + options.barRadiusMm,
        yMax: geo.barGapMm / 2 - options.barRadiusMm,
      );
    } else {
      // Platform the prize rests on; the drop hole is at the exit side.
      final w = options.fieldWidthMm, d = options.fieldDepthMm;
      boxes.add(SceneBox(
        id: 'platform',
        pose: Pose(Vec3(0, 0, 20)),
        size: Vec3(w, d, 40),
        material: SceneMaterial.acrylic,
        label: t(ko: '필드', ja: 'フィールド', en: 'field'),
      ));
      hole = switch (analysis.machine.exitSide) {
        ExitSide.left => SceneDropHole(xMin: -w / 2 - 120, xMax: -w / 2, yMin: -d / 2, yMax: d / 2),
        ExitSide.right => SceneDropHole(xMin: w / 2, xMax: w / 2 + 120, yMin: -d / 2, yMax: d / 2),
        ExitSide.back => SceneDropHole(xMin: -w / 2, xMax: w / 2, yMin: -d / 2 - 120, yMax: -d / 2),
        ExitSide.center => SceneDropHole(xMin: -100, xMax: 100, yMin: -100, yMax: 100),
        _ => SceneDropHole(xMin: -w / 2, xMax: w / 2, yMin: d / 2, yMax: d / 2 + 120),
      };
    }

    final markers = <SceneMarker>[];
    SceneClaw? claw;
    if (current != null) {
      claw = SceneClaw(
        center: current.fieldPoint,
        clawCount: analysis.machine.clawCount == 3 ? 3 : 2,
        openWidthMm: options.clawOpenWidthMm,
        restHeightMm: options.clawRestHeightMm,
      );
      markers.add(SceneMarker(
        point: current.fieldPoint,
        label: t(ko: '아암 중심', ja: 'アーム中心', en: 'claw centre'),
        arm: current.arm,
      ));
      if (current.arm != Arm.both) {
        final tipX = current.fieldPoint.x + (current.arm == Arm.right ? 1 : -1) * options.clawOpenWidthMm / 2;
        markers.add(SceneMarker(
          point: Vec3(tipX, current.fieldPoint.y, current.fieldPoint.z),
          label: t(ko: '발톱 접점', ja: '爪の接点', en: 'tip contact'),
          arm: current.arm,
          primary: false,
        ));
      }
    }

    final motion = _predictMotion(prize, technique, spec, layout, analysis.machine.exitSide, current, t);

    return Scene3D(
      fieldWidthMm: options.fieldWidthMm,
      fieldDepthMm: options.fieldDepthMm,
      cylinders: cylinders,
      boxes: boxes,
      claw: claw,
      dropHole: hole,
      markers: markers,
      motion: motion,
      camera: CameraHint(target: Vec3(prize.pose.position.x, 0, prize.pose.position.z * 0.6)),
    );
  }

  SceneMotion? _predictMotion(
    SceneBox prize,
    Technique technique,
    PrizeSpec spec,
    LayoutType layout,
    ExitSide exit,
    AimStep? current,
    _Tr t,
  ) {
    if (current == null) return null;
    final p = prize.pose;
    final pos = p.position;
    final rightSide = current.arm == Arm.right;
    Pose to;
    String desc;
    switch (technique) {
      case Technique.tateHame:
        to = Pose(Vec3(pos.x, pos.y + 15, pos.z - 25), Rotation(pitchDeg: -32, yawDeg: rightSide ? -6 : 6));
        desc = t(ko: '안쪽 끝이 들리고 앞쪽이 바 사이로 내려감', ja: '奥端が上がり前側がバーの間へ下がる', en: 'Back end rises, front slides into the gap');
      case Technique.yokoHame:
        to = Pose(pos, Rotation(yawDeg: rightSide ? 35 : -35));
        desc = t(ko: '위에서 보아 약 35° 회전', ja: '上から見て約35°回転', en: 'Rotates about 35° seen from above');
      case Technique.yose:
      case Technique.zurashi:
        final dx = exit == ExitSide.left ? -50.0 : (exit == ExitSide.right ? 50.0 : 0.0);
        final dy = dx == 0 ? 45.0 : 0.0;
        to = Pose(Vec3(pos.x + dx, pos.y + dy, pos.z), p.rotation);
        desc = t(ko: '낙하구 방향으로 수 cm 이동', ja: '落とし口方向へ数cm移動', en: 'Slides a few cm toward the exit');
      case Technique.oshikomi:
        to = Pose(Vec3(pos.x, pos.y + 30, pos.z - 30), const Rotation(pitchDeg: -28));
        desc = t(ko: '앞 모서리가 내려가며 낙하', ja: '前角が下がって落下', en: 'Front edge dips and the prize falls');
      case Technique.mochiage:
      case Technique.kadoOshi:
        to = Pose(Vec3(pos.x, pos.y, pos.z + 25), Rotation(rollDeg: rightSide ? -18 : 18));
        desc = t(ko: '모서리가 들려 기울어짐', ja: '角が持ち上がって傾く', en: 'The corner lifts and the prize tilts');
      case Technique.noriage:
        to = Pose(Vec3(pos.x, pos.y + 10, pos.z + 20), const Rotation(pitchDeg: -22));
        desc = t(ko: '안쪽 끝이 뒤 바 위에 얹힘', ja: '奥端が奥バーに乗る', en: 'Back end rests on the back bar');
      case Technique.tsuki:
        to = Pose(Vec3(pos.x, pos.y + 25, pos.z - 15), const Rotation(pitchDeg: -15));
        desc = t(ko: '찔린 모서리가 들리고 앞으로 넘어감', ja: '突かれた角が上がり前へ倒れる', en: 'Poked corner lifts and it tips forward');
      case Technique.hikkake:
        to = Pose(Vec3(pos.x, pos.y, pos.z + 60), p.rotation);
        desc = t(ko: '걸린 부위가 들려 올라감', ja: '掛かった部位が持ち上がる', en: 'The hooked part lifts');
      case Technique.otoshi:
      case Technique.nadare:
        to = Pose(Vec3(pos.x, pos.y + 30, pos.z - 10), p.rotation);
        desc = t(ko: '앞쪽으로 무너져 내림', ja: '手前へ崩れる', en: 'Collapses toward the front');
      case Technique.unknown:
        return null;
    }
    return SceneMotion(boxId: prize.id, from: p, to: to, description: desc);
  }

  OverlayGeometry _buildOverlay(_Geometry geo, Technique technique, AimStep? current) {
    Pt? from, to;
    if (current != null) {
      from = geo.top(0.5, 0.5);
      final len = geo.prizeBbox.height * 0.35;
      to = switch (technique) {
        Technique.tateHame => Pt(from.x, from.y + len * 0.6),
        Technique.yokoHame => Pt(from.x + (current.arm == Arm.right ? -len : len), from.y + len * 0.3),
        Technique.yose || Technique.zurashi || Technique.oshikomi || Technique.otoshi || Technique.nadare || Technique.tsuki =>
          Pt(from.x, from.y + len),
        Technique.mochiage || Technique.kadoOshi || Technique.noriage || Technique.hikkake =>
          Pt(from.x, from.y - len * 0.6),
        Technique.unknown => from,
      };
    }
    return OverlayGeometry(
      prizeBbox: geo.prizeBbox,
      topFace: geo.topFace,
      frontBar: geo.frontBarLine,
      backBar: geo.backBarLine,
      dropHole: geo.dropHole,
      claw: geo.claw,
      motionFrom: from,
      motionTo: to?.clamp01(),
      barsSynthesized: geo.barsSynthesized,
    );
  }
}

// -----------------------------------------------------------------------------
// Geometry derived from the analysis

class _Geometry {
  _Geometry({
    required this.prizeBbox,
    required this.topFace,
    required this.frontBarLine,
    required this.backBarLine,
    required this.barsSynthesized,
    required this.dropHole,
    required this.claw,
    required this.fieldXL,
    required this.fieldXR,
    required this.boxXMm,
    required this.boxYMm,
    required this.boxZMm,
    required this.barGapMm,
    required this.prizeBox,
    required this.halfOpenImg,
  });

  final NBox prizeBbox;

  /// front-left, front-right, back-right, back-left
  final List<Pt> topFace;
  final List<Pt>? frontBarLine;
  final List<Pt>? backBarLine;
  final bool barsSynthesized;
  final NBox? dropHole;
  final NBox? claw;

  /// Image x-range that corresponds to the full field width.
  final double fieldXL;
  final double fieldXR;
  final double boxXMm;
  final double boxYMm;
  final double boxZMm;
  final double barGapMm;
  final SceneBox prizeBox;

  /// Half of the claw opening, in normalized image x units.
  final double halfOpenImg;

  /// Point on the prize top face: [u] 0 = front edge … 1 = back edge,
  /// [v] 0 = left … 1 = right.
  Pt top(double u, double v) {
    final f = _lerp(topFace[0], topFace[1], v);
    final b = _lerp(topFace[3], topFace[2], v);
    return _lerp(f, b, u);
  }

  /// Field position of a point given as fractions of the prize bbox
  /// (fx: left→right, fy: top→bottom of the bbox). Used for plush/ring targets.
  Vec3 fieldOnBbox(double fx, double fy) {
    final s = prizeBox.size;
    return prizeBox.pose.toWorld(Vec3((fx - 0.5) * s.x, (0.5 - fy) * s.y, s.z / 2));
  }

  static Pt _lerp(Pt a, Pt b, double t) => Pt(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);

  static _Geometry build({
    required AnalysisResult analysis,
    required NBox prizeBbox,
    required PrizeSpec spec,
    required SceneCorrections corrections,
    required EngineOptions options,
  }) {
    final layout = analysis.layoutType;
    final isPlush = analysis.targetPrize?.kind == ObjectKind.plush;
    final ratio = (corrections.topFaceRatio ?? (isPlush ? 0.5 : options.defaultTopFaceRatio)).clamp(0.1, 0.8);
    final topH = prizeBbox.height * ratio;
    final yTopBottom = prizeBbox.y1 + topH;
    final inset = prizeBbox.width * 0.05;
    final topFace = <Pt>[
      Pt(prizeBbox.x1, yTopBottom),
      Pt(prizeBbox.x2, yTopBottom),
      Pt(prizeBbox.x2 - inset, prizeBbox.y1),
      Pt(prizeBbox.x1 + inset, prizeBbox.y1),
    ];

    // Bars ------------------------------------------------------------------
    NBox? front = corrections.frontBar;
    NBox? back = corrections.backBar;
    if (front == null || back == null) {
      final bars = analysis.objects.where((o) => o.kind.isBar).map((o) => o.bbox).toList()
        ..sort((a, b) => a.cy.compareTo(b.cy));
      if (bars.length >= 2) {
        back ??= bars.first;
        front ??= bars.last;
      } else if (bars.length == 1) {
        final b = bars.single;
        if (b.cy > prizeBbox.cy) {
          front ??= b;
        } else {
          back ??= b;
        }
      }
    }
    var synthesized = false;
    if (layout.isBridge) {
      if (front == null) {
        synthesized = true;
        front = NBox(prizeBbox.x1 - prizeBbox.width * 0.6, prizeBbox.y2 - 0.01, prizeBbox.x2 + prizeBbox.width * 0.6, prizeBbox.y2 + 0.01).normalized();
      }
      if (back == null) {
        synthesized = true;
        final y = prizeBbox.y1 + topH * 0.45;
        back = NBox(prizeBbox.x1 - prizeBbox.width * 0.6, y - 0.01, prizeBbox.x2 + prizeBbox.width * 0.6, y + 0.01).normalized();
      }
    }
    List<Pt>? frontLine = front == null ? null : [Pt(front.x1, front.cy), Pt(front.x2, front.cy)];
    List<Pt>? backLine = back == null ? null : [Pt(back.x1, back.cy), Pt(back.x2, back.cy)];

    // Field extent in the image ---------------------------------------------
    double xl, xr;
    if (front != null && back != null) {
      xl = math.min(front.x1, back.x1);
      xr = math.max(front.x2, back.x2);
    } else {
      xl = prizeBbox.cx - prizeBbox.width * 2.0;
      xr = prizeBbox.cx + prizeBbox.width * 2.0;
    }
    if (xr - xl < prizeBbox.width * 1.5) {
      xl = prizeBbox.cx - prizeBbox.width * 1.5;
      xr = prizeBbox.cx + prizeBbox.width * 1.5;
    }
    final fieldSpan = xr - xl;

    // Metric placement ---------------------------------------------------------
    final boxX = ((prizeBbox.cx - xl) / fieldSpan - 0.5) * options.fieldWidthMm;
    double gap = spec.depthMm * options.defaultBarGapRatio;
    if (front != null && back != null && !synthesized && topH > 0) {
      // Bar spacing and the top face are foreshortened similarly, so their
      // image ratio approximates gap / depth. Rough, hence the clamp.
      final spacing = (front.cy - back.cy).abs();
      gap = (spec.depthMm * spacing / topH).clamp(spec.depthMm * 0.35, spec.depthMm * 0.9);
    }
    // Front/back position cannot be read from a single front photo
    // (perspective bias), so it is 0 unless the user says otherwise.
    final boxY = (corrections.boxYOffsetMm ?? 0).clamp(-0.4 * spec.depthMm, 0.4 * spec.depthMm);
    final double boxZ;
    if (layout.isBridge) {
      boxZ = options.barHeightMm + options.barRadiusMm + spec.heightMm / 2;
    } else {
      boxZ = 40 + spec.heightMm / 2;
    }
    final prizeBox = SceneBox(
      id: 'prize',
      pose: Pose(Vec3(boxX, boxY, boxZ), Rotation(yawDeg: corrections.yawDeg ?? 0)),
      size: Vec3(spec.widthMm, spec.depthMm, spec.heightMm),
      material: isPlush ? SceneMaterial.plush : SceneMaterial.cardboard,
      label: spec.name,
    );

    final dropHole = corrections.dropHole ??
        (analysis.ofKind(ObjectKind.dropHole).isNotEmpty ? analysis.ofKind(ObjectKind.dropHole).first.bbox : null);
    final claw = corrections.claw ??
        (analysis.ofKind(ObjectKind.claw).isNotEmpty ? analysis.ofKind(ObjectKind.claw).first.bbox : null);

    return _Geometry(
      prizeBbox: prizeBbox,
      topFace: topFace,
      frontBarLine: frontLine,
      backBarLine: backLine,
      barsSynthesized: synthesized,
      dropHole: dropHole,
      claw: claw,
      fieldXL: xl,
      fieldXR: xr,
      boxXMm: boxX,
      boxYMm: boxY,
      boxZMm: boxZ,
      barGapMm: gap,
      prizeBox: prizeBox,
      halfOpenImg: options.clawOpenWidthMm / 2 / options.fieldWidthMm * fieldSpan,
    );
  }
}

// -----------------------------------------------------------------------------
// Tiny translation helper (engine strings are produced in the app locale).

class _Tr {
  const _Tr(this.locale);
  final String locale;

  String call({required String ko, required String ja, required String en}) {
    final code = locale.toLowerCase();
    if (code.startsWith('ja')) return ja;
    if (code.startsWith('en')) return en;
    return ko;
  }
}
