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
    LayoutType.bridgeFour: [
      Technique.tateHame,
      Technique.yokoHame,
      Technique.zurashi,
      Technique.yose,
      Technique.noriage,
      Technique.kadoOshi,
    ],
    LayoutType.bridgeMixed: [
      Technique.zurashi,
      Technique.yose,
      Technique.noriage,
      Technique.mochiage,
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
    LayoutType.hangString: [Technique.yose, Technique.hikkake, Technique.oshikomi],
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
    // User corrections come straight from drag handles; normalize them the
    // same way detected boxes are normalized on parse.
    final prizeBbox = (corrections.prizeBbox ?? prizeObj?.bbox)?.normalized();
    if (prizeBbox == null || analysis.layoutType == LayoutType.unknown) {
      return _noPlan(analysis, t, warnings);
    }
    if (prizeBbox.width < 0.01 || prizeBbox.height < 0.01) {
      warnings.add(t(
        ko: '경품 범위가 너무 작거나 사진 밖에 있습니다. 보정 모드에서 경품 위치를 다시 잡아 주세요.',
        ja: '景品の範囲が小さすぎるか写真の外にあります。補正モードで景品の箱を指定し直してください。',
        en: 'The prize region is degenerate or outside the photo. Re-draw the prize box in correction mode.',
      ));
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
        ko: '사진에서 봉을 찾지 못해 위치를 추정했습니다. 보정 모드에서 앞 봉과 안쪽 봉 위치를 바로잡아 주세요.',
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
      clawRotation: corrections.clawRotation,
    );
    final abortIf = _abortConditions(analysis, technique, t);

    final finished =
        observations.isNotEmpty && observations.last.kind == ObservationKind.dropped;
    final stuck =
        observations.isNotEmpty && observations.last.kind == ObservationKind.stuck;
    if (stuck) {
      warnings.add(t(
        ko: '상자가 끼어서 더는 움직이지 않는 상태입니다. 직원에게 처음 위치로 되돌려 달라고 부탁하세요.',
        ja: '詰みの形です。店員に「初期位置に戻してください」と依頼しましょう。',
        en: 'The prize is stuck (詰み). Ask the staff: 「初期位置に戻してください」 (please reset to the initial position).',
      ));
    }
    if (armPower == ArmPower.weak) {
      rationale.add(t(
        ko: '집게 힘이 약해 보여서, 집게발이 끝부분에 아슬아슬하게 걸리도록 조준점을 옮겼습니다. 무게중심에서 먼 곳을 걸수록 적은 힘으로도 크게 돌아갑니다.',
        ja: 'アームが弱いと観察されたため、爪を端ギリギリに掛けるよう狙いを寄せました。力点が重心から遠いほど小さな力で大きく回転します。',
        en: 'The arm looks weak, so the aim moved closer to the very edge (端ギリギリ): the farther the contact is from the centre of mass, the more it rotates per play.',
      ));
    }

    final usesOneArm = steps.any((s) => s.arm != Arm.both);
    if (usesOneArm) {
      switch (corrections.clawRotation) {
        case ClawRotation.clockwise:
          rationale.add(t(
            ko: '이 기계의 집게는 내려가면서 위에서 볼 때 시계 방향으로 약 ${options.clawRotationDeg.round()}° 돕니다. 돌아간 뒤에도 집게발이 목표에 닿도록 집게 중심을 반대쪽으로 옮겼습니다.',
            ja: 'この台のアームは下降中に（上から見て）時計回りに約${options.clawRotationDeg.round()}°回ります。回転後も爪が狙いに当たるよう、アーム中心を逆方向に補正しました。',
            en: 'This claw twists about ${options.clawRotationDeg.round()}° clockwise (seen from above) while descending; the claw centre was offset the other way so the tip still lands on the target.',
          ));
        case ClawRotation.counterClockwise:
          rationale.add(t(
            ko: '이 기계의 집게는 내려가면서 위에서 볼 때 반시계 방향으로 약 ${options.clawRotationDeg.round()}° 돕니다. 돌아간 뒤에도 집게발이 목표에 닿도록 집게 중심을 반대쪽으로 옮겼습니다.',
            ja: 'この台のアームは下降中に（上から見て）反時計回りに約${options.clawRotationDeg.round()}°回ります。回転後も爪が狙いに当たるよう、アーム中心を逆方向に補正しました。',
            en: 'This claw twists about ${options.clawRotationDeg.round()}° counter-clockwise (seen from above) while descending; the claw centre was offset the other way so the tip still lands on the target.',
          ));
        case ClawRotation.none:
          break;
        case ClawRotation.unknown:
          warnings.add(t(
            ko: '첫 판에서 집게가 내려가는 동안 어느 쪽으로 도는지(시계 방향/반시계 방향) 보고 입력하면 조준을 보정합니다.',
            ja: '1手目でアームが下降中にどちら（時計/反時計）に回るか観察して入力すると、狙いを補正します。',
            en: 'On the first play, watch which way the claw twists while descending (clockwise / counter-clockwise) and enter it to refine the aim.',
          ));
      }
    }
    if (geo.barCount >= 3) {
      rationale.add(t(
        ko: '봉이 ${geo.barCount}개인 배치입니다. 상자가 걸쳐 있는 두 봉 사이가 출구입니다. 가운데 봉에 상자가 걸리면 끼이기 쉬우니, 틈이 넓은 쪽 끝을 노려 그쪽으로 세웁니다.',
        ja: 'バーが${geo.barCount}本の設定です。箱が乗っている2本の間が落とし口で、中間のバーに箱が掛かると詰みやすいので、広い隙間側の端を狙ってそちらへ立てます。',
        en: 'This setup has ${geo.barCount} bars. The drop is the gap between the two bars the box rests on; a box caught on a middle bar tends to get stuck, so aim at the end above the wider gap.',
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
      barCount: analysis.layoutType.isBridge ? geo.barCount : 0,
      clawRotation: corrections.clawRotation,
    );
  }

  // ---------------------------------------------------------------------------
  // No-plan fallback

  AimPlan _noPlan(AnalysisResult analysis, _Tr t, List<String> warnings) {
    final requested = [...analysis.needsMorePhotos];
    if (requested.isEmpty) {
      requested.add(t(
        ko: '기계 정면에서 경품, 집게, 봉이 모두 보이게 다시 찍어 주세요.',
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
      case LayoutType.bridgeParallel || LayoutType.bridgeFour:
        if (layout == LayoutType.bridgeFour) {
          rationale.add(t(
            ko: '평행한 봉 4개에 걸친 상자: 보통 가운데 두 봉 사이가 출구이고, 바깥 봉은 기울어진 상자를 받쳐 줍니다. 상자 중심을 가운데 틈 위에 두고, 바깥 봉 위로 밀려 올라가지 않게 합니다.',
            ja: '4本橋渡し: 多くは中央2本の間が落とし口で、外側のバーは傾いた箱を受け止めます。箱の重心を中央の隙間の上に保ち、外側のバーへ乗り上げさせないようにします。',
            en: 'Four bars: the drop is usually the gap between the middle bars, and the outer bars catch a tilting box. Keep the box centred over the middle gap and do not push it up onto an outer bar.',
          ));
        }
        if (technique == Technique.tateHame || technique == Technique.yokoHame) {
          // Community rule: heavy → 縦ハメ, light → 横ハメ; and 横ハメ needs a
          // gap wider than the box width.
          final proposedTate = analysis.strategy.technique == Technique.tateHame;
          var wantYoko = !spec.isHeavy && !proposedTate;
          var forcedByGap = false;
          if (wantYoko && !geo.barsSynthesized && geo.barGapMm < spec.widthMm * 1.05) {
            // Only trust the gap when the bars were actually detected.
            wantYoko = false;
            forcedByGap = true;
          }
          if (wantYoko && geo.barsSynthesized) {
            warnings.add(t(
              ko: '사진에서 봉 간격을 확인하지 못했습니다. 실제 간격이 상자 폭(${spec.widthMm.round()}mm)보다 좁으면 눕혀서 떨어뜨리기 대신 세워서 떨어뜨리기로 바꾸세요.',
              ja: 'バー間隔を写真から確認できませんでした。実際の間隔が箱の幅(${spec.widthMm.round()}mm)より狭ければ横ハメではなく縦ハメに切り替えてください。',
              en: 'The bar gap could not be measured from the photo. If it is narrower than the box width (${spec.widthMm.round()} mm), switch from 横ハメ to 縦ハメ.',
            ));
          }
          technique = wantYoko ? Technique.yokoHame : Technique.tateHame;
          if (forcedByGap) {
            warnings.add(t(
              ko: '봉 간격(약 ${geo.barGapMm.round()}mm)이 상자 폭(${spec.widthMm.round()}mm)보다 좁아서 눕혀서 떨어뜨릴 수 없습니다. 세워서 떨어뜨리기로 진행합니다.',
              ja: 'バー間隔(約${geo.barGapMm.round()}mm)が箱の幅(${spec.widthMm.round()}mm)より狭いため横ハメはできません。縦ハメで進めます。',
              en: 'The bar gap (~${geo.barGapMm.round()} mm) is narrower than the box width (${spec.widthMm.round()} mm), so 横ハメ is impossible. Using 縦ハメ.',
            ));
          }
          rationale.add(t(
            ko: '봉에 걸친 상자: 집게 힘은 보통 상자를 들어 올리지 못하게 맞춰져 있습니다. 그래서 "집어 올리기"가 아니라 "조금씩 돌려서 봉 사이로 떨어뜨리기"가 목표입니다.',
            ja: '橋渡し: アームパワーは箱を持ち上げられないよう設定されるのが普通なので、「掴む」ではなく「少しずつ回転させてバーの間に落とす」のが目標です。',
            en: 'Bridge setup: the arm is usually too weak to lift the box, so the goal is to rotate it little by little until it drops between the bars.',
          ));
          if (technique == Technique.yokoHame) {
            rationale.add(t(
              ko: '가벼운 상자(${spec.massG?.round() ?? '~300'}g)는 눕혀서 떨어뜨리기가 유리합니다. 봉과 나란해지도록 돌려서 넓은 틈으로 빠뜨립니다.',
              ja: '軽い箱(${spec.massG?.round() ?? '約300'}g)はバーと平行になるよう回して隙間に落とす横ハメが有利です。',
              en: 'A light box (${spec.massG?.round() ?? '~300'} g) is turned parallel to the bars so it drops flat through the gap (横ハメ).',
            ));
          } else if (forcedByGap) {
            rationale.add(t(
              ko: '봉 간격이 상자 폭보다 좁아서 눕혀서는 빠지지 않습니다. 상자를 세워서 떨어뜨리는 방법으로 갑니다.',
              ja: 'バー間隔が箱の幅より狭く横では落ちないため、立てて挟む縦ハメで攻めます。',
              en: 'The gap is narrower than the box width, so it cannot drop flat; stand it up instead (縦ハメ).',
            ));
          } else if (spec.isHeavy) {
            rationale.add(t(
              ko: '무거운 상자(${spec.massG?.round() ?? '~300'}g)는 세워서 떨어뜨리기가 기본입니다.',
              ja: '重い箱(${spec.massG?.round() ?? '約300'}g)は縦ハメが定石です。',
              en: 'A heavy box (${spec.massG?.round() ?? '~300'} g) is stood up (縦ハメ).',
            ));
          } else {
            rationale.add(t(
              ko: '분석 결과 세워서 떨어뜨리기를 추천했습니다. 상자가 가볍다면 눕혀서 떨어뜨리기도 해 볼 만합니다.',
              ja: '解析結果が縦ハメを提案しています。箱が軽ければ横ハメも試せます。',
              en: 'The analysis proposed 縦ハメ. If the box is light, 横ハメ is also an option.',
            ));
          }
        }
      case LayoutType.bridgeHanoji || LayoutType.bridgeMixed:
        if (armPower == ArmPower.strong && technique == Technique.noriage) {
          technique = Technique.mochiage;
        }
        if (armPower != ArmPower.strong && technique == Technique.mochiage) {
          technique = Technique.noriage;
        }
        if (layout == LayoutType.bridgeMixed) {
          rationale.add(t(
            ko: '바깥은 평행, 안쪽은 벌어진 봉 4개: 안쪽 두 봉이 넓게 벌어진 쪽으로 상자를 옮기면 그 틈으로 빠집니다. 바깥 평행 봉이 상자 끝을 받치므로, 비뚤어지지 않게 좌우를 번갈아 옮깁니다.',
            ja: '4本 平行＋ハの字: 内側2本が広がる側へ箱を運べばその隙間から落ちます。外側の平行バーが箱の端を受けるので、斜めにならないよう左右交互に運びます。',
            en: 'Four-bar mix: move the box toward where the inner bars spread and it drops through that gap. The outer parallel bars catch the box ends, so alternate sides to keep it straight.',
          ));
          break;
        }
        rationale.add(t(
          ko: '한쪽이 벌어진 봉: 봉 사이가 넓어지는 쪽으로 상자를 돌리거나 옮기면 빠집니다. 집게 힘이 세면 들어 올리기, 약하면 안쪽 모서리를 봉 위로 올리기를 씁니다.',
          ja: '末広がり: バーが広がる側へ箱を回転・移動させれば落ちます。アームが強ければつまみ上げ、そうでなければ奥角をバーに乗せる乗り上げ。',
          en: 'Widening bars: rotate/move the box toward the wide end. Strong arm → lift; otherwise rest an inner corner on a bar (乗り上げ).',
        ));
      case LayoutType.bridgeStep:
        rationale.add(t(
          ko: '높이가 다르거나 튜브를 씌운 봉: 분홍 고무 튜브는 마찰이 커서 밀어 올리기가 잘 통하지 않습니다. 들어 올리거나 돌리는 방법으로 갑니다.',
          ja: '段差/ピンクチューブ: ゴムチューブは摩擦が大きく、ずり上げは効きません。持ち上げ・回転系で攻めます。',
          en: 'Step/pink tube: rubber tubes have high friction, so sliding does not work; lift or rotate instead.',
        ));
      case LayoutType.frontDrop:
        rationale.add(t(
          ko: '앞으로 밀어 떨어뜨리는 단: 노리는 쪽과 반대쪽 집게로 끌어당기듯 좌우를 번갈아 가며 앞으로 옮깁니다. 충분히 앞으로 나오면 튀어나온 부분을 눌러 떨어뜨립니다. 너무 일찍 누르면 판만 낭비합니다.',
          ja: '前落とし: 狙う側と反対のアームで引き寄せるように(寄せ)左右交互に前へ運び、十分手前に来たらはみ出した部分を押し込みます。早く押しすぎると無駄になります。',
          en: 'Front drop: pull the prize forward with alternating arms (寄せ), and only when it overhangs the edge push it down (押し込み). Pushing too early wastes plays.',
        ));
      case LayoutType.floorBox:
        rationale.add(t(
          ko: '바닥에 놓인 상자: 집게가 벌어졌을 때 집게발이 상자 틈이나 모서리에 닿도록 맞추고, 출구에 가까운 모서리를 들어 올려 무게중심을 바깥으로 보냅니다.',
          ja: '箱直置き: 開いた爪が箱の隙間・角に合うよう調整し、落とし口に近い角を持ち上げて重心を外に出します。',
          en: 'Box on the floor: match the open claw to a box corner/gap and lift the corner nearest the exit so the centre of mass moves out.',
        ));
      case LayoutType.hangString:
        rationale.add(t(
          ko: '끈으로 봉에 매달린 경품: 끈은 금속 고리보다 마찰이 커서 조금씩만 움직입니다. 고리의 벽 쪽을 걸어 봉 끝으로 밀고, 끝까지 오면 집게발을 고리에 넣어 빼냅니다.',
          ja: '紐吊り: 紐は金属リングより摩擦が大きく少しずつしか動きません。輪の壁側を掛けて棒の先へ押し(寄せ)、先まで来たら爪を輪に入れて外します(引っ掛け)。',
          en: 'String hang: a string grips more than a metal ring and moves only a little per play. Hook the wall side of the loop to push it toward the rod tip (寄せ), then put a tip in the loop to take it off (引っ掛け).',
        ));
      case LayoutType.threeClaw:
        rationale.add(t(
          ko: '세 발 집게로 집는 인형: 세 집게발이 인형의 무게중심을 감싸야 합니다. 두 개만 걸리면 무게를 버티지 못합니다. 확률형 기계가 많아서, 확률 한도에 이르기 전에는 옮기는 방법만 통할 수 있습니다(추정).',
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
    ClawRotation clawRotation = ClawRotation.unknown,
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
      final tipField = onBbox
          ? geo.fieldOnBbox(v, u)
          : geo.prizeBox.pointAt(u, v, 1.0);
      // Offset from the claw centre to the chosen arm's tip, in field mm.
      // When the unit twists while descending, the tip lands rotated; move
      // the centre the opposite way so the twisted tip hits the target.
      final half = options.clawOpenWidthMm / 2;
      final theta = switch (clawRotation) {
        ClawRotation.clockwise => options.clawRotationDeg * math.pi / 180,
        ClawRotation.counterClockwise => -options.clawRotationDeg * math.pi / 180,
        _ => 0.0,
      };
      final sideSign = switch (arm) {
        Arm.right => 1.0,
        Arm.left => -1.0,
        Arm.both => 0.0,
      };
      // Seen from above with X right and Y toward the player, a clockwise
      // twist moves the right tip toward the player (+Y).
      final offX = sideSign * half * math.cos(theta);
      final offY = sideSign * half * math.sin(theta);
      final fieldSpan = geo.fieldXR - geo.fieldXL;
      final dxImg = -offX / options.fieldWidthMm * fieldSpan;
      final dyImg = spec.depthMm <= 0 ? 0.0 : -offY / spec.depthMm * geo.topFaceHeightImg;
      final claw = Pt(tip.x + dxImg, tip.y + dyImg).clamp01();
      return AimStep(
        index: n,
        arm: arm,
        technique: tech,
        edge: edge,
        clawPoint: claw,
        tipPoint: tip.clamp01(),
        fieldPoint: Vec3(tipField.x - offX, tipField.y - offY, tipField.z),
        title: title,
        detail: detail,
      );
    }

    // Box sitting toward the back (user's front/back correction) → pull it
    // forward first (手前を狙う). An analysis that proposes 寄せ on the front
    // edge already routes to the yose branch below.
    final needsPullForward = layout.isBridge && geo.boxYMm < -0.12 * spec.depthMm;

    switch (technique) {
      case Technique.tateHame:
        if (needsPullForward) {
          steps.add(make(
            arm: Arm.right,
            tech: Technique.yose,
            edge: TargetEdge.frontRight,
            u: inset,
            v: 0.5 + side,
            title: t(ko: '먼저 앞쪽 끝을 끌어당기기', ja: 'まず手前の端を寄せる', en: 'First pull the front end forward (寄せ)'),
            detail: t(
              ko: '상자가 안쪽으로 치우쳐 있습니다. 오른쪽 집게발을 앞쪽 끝 윗면에 걸어, 집게가 닫히는 힘으로 앞으로 당깁니다.',
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
          title: t(ko: '오른쪽 집게발을 안쪽 끝 오른편에', ja: '右アームの爪を奥端の右側に', en: 'Right arm tip just inside the back-right end'),
          detail: t(
            ko: '집게발이 윗면 안쪽 끝부분에 아슬아슬하게 걸리면 닫힐 때 안쪽 끝이 들립니다. 그러면 상자가 앞 봉을 축으로 기울면서 앞쪽이 봉 사이로 내려갑니다.',
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
          title: t(ko: '왼쪽 집게발을 안쪽 끝 왼편에 (번갈아)', ja: '左アームの爪を奥端の左側に(交互)', en: 'Left arm tip at the back-left end (alternate)'),
          detail: t(
            ko: '반대쪽에서 같은 동작을 반복해, 상자가 한쪽으로 틀어지지 않게 조금씩 세웁니다. 세로로 끼고 나면 남은 모서리를 한 번 더 밀어 떨어뜨립니다.',
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
          title: t(ko: '안쪽 오른쪽 모서리를 밀어 돌리기 시작', ja: '奥の右角を押して回転開始', en: 'Push the back-right corner to start rotating'),
          detail: t(
            ko: '오른쪽 집게발로 안쪽 오른쪽 모서리를 걸어, 닫히는 힘으로 상자를 반시계 방향으로 돌립니다.',
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
          title: t(ko: '반대쪽 집게로 앞쪽 왼쪽 모서리', ja: '反対のアームで手前の左角', en: 'Opposite arm on the front-left corner'),
          detail: t(
            ko: '대각선 반대쪽 모서리를 밀어 계속 돌립니다. 상자의 긴 변이 봉과 나란해지면 틈으로 떨어집니다. 가로로 두 봉 위에 얹히면 끼어 버리니 한 판에 조금씩만 돌립니다.',
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
            title: t(ko: '옆면 끝에 걸어 출구 쪽으로 끌어당기기', ja: '側面の端に掛けて落とし口へ寄せる', en: 'Hook the side edge and drag toward the exit'),
            detail: t(
              ko: '출구 반대쪽 집게발을 상자 옆면 끝에 걸면, 집게가 닫히면서 상자를 출구 쪽으로 끌어당깁니다.',
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
            title: t(ko: '같은 옆면의 반대쪽 끝 (번갈아)', ja: '同じ側、別の端(交互)', en: 'Same side, other end (alternate)'),
            detail: t(
              ko: '앞쪽 끝과 안쪽 끝을 번갈아 당겨, 상자가 틀어지지 않고 그대로 옆으로 오게 합니다.',
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
            title: t(ko: '오른쪽 집게발을 안쪽 끝에 걸어 앞으로', ja: '右アームの爪を奥端に掛けて手前へ', en: 'Right arm tip on the back end, drag forward'),
            detail: t(
              ko: '안쪽 끝 윗면에 집게발을 걸면 닫힐 때 상자가 앞으로 끌려옵니다. 가벼운 쪽(보통 아래쪽 절반)을 노리면 한 판에 더 많이 움직입니다.',
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
            title: t(ko: '왼쪽 집게로 반대편 (번갈아)', ja: '左アームで反対側(交互)', en: 'Left arm on the other side (alternate)'),
            detail: t(
              ko: '좌우를 번갈아 당겨 상자가 돌아가지 않고 똑바로 앞으로 오게 합니다.',
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
              title: t(ko: '앞부분이 단 밖으로 나오면 앞 모서리를 눌러 떨어뜨리기', ja: '手前がはみ出したら前角を押し込む', en: 'Once the front overhangs, push the front edge down (押し込み)'),
              detail: t(
                ko: '상자 앞부분이 출구 위로 충분히 나온 뒤에만 집게 몸통이나 집게발로 앞 모서리를 아래로 누릅니다.',
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
          title: t(ko: '앞 모서리를 눌러 떨어뜨리기', ja: '前角を押し込む', en: 'Push the front edge down (押し込み)'),
          detail: t(
            ko: '출구 위로 나온 앞부분을 내려오는 집게로 눌러 무게중심을 바깥으로 넘깁니다.',
            ja: '落とし口の上に出た手前部分を下降するアームで押し、重心を外へ出します。',
            en: 'Press the overhanging front part with the descending claw to push the centre of mass past the edge.',
          ),
        ));
      case Technique.mochiage:
      case Technique.kadoOshi:
        final rightFirst = analysis.machine.exitSide != ExitSide.left;
        final rightEdge = layout.isBridge ? TargetEdge.backRight : TargetEdge.frontRight;
        final leftEdge = layout.isBridge ? TargetEdge.backLeft : TargetEdge.frontLeft;
        final corners = rightFirst
            ? [(Arm.right, rightEdge, 1 - inset), (Arm.left, leftEdge, inset)]
            : [(Arm.left, leftEdge, inset), (Arm.right, rightEdge, 1 - inset)];
        for (final (arm, edge, v) in corners) {
          steps.add(make(
            arm: arm,
            tech: technique,
            edge: edge,
            u: layout.isBridge ? 1 - inset : inset,
            v: v,
            title: technique == Technique.mochiage
                ? t(ko: '모서리 들어 올리기', ja: '角を持ち上げる', en: 'Lift the corner (持ち上げ)')
                : t(ko: '모서리를 눌러 기울이기', ja: '角を押して傾ける', en: 'Press the corner to tilt (角押し)'),
            detail: t(
              ko: '출구에 가까운 모서리에 집게발을 걸어 들거나 눌러서, 무게중심이 받치는 선 바깥으로 나가게 합니다. 좌우 모서리를 번갈아 노립니다.',
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
          title: t(ko: '양쪽 집게로 안쪽 모서리를 들어 봉 위로 올리기', ja: '奥角を両アームで持ち上げてバーに乗せる', en: 'Lift the inner corner with both arms onto the bar (乗り上げ)'),
          detail: t(
            ko: '상자를 완전히 들지 못해도 안쪽 끝을 살짝 들어 안쪽 봉 위에 걸치면 균형이 무너져서, 다음 판에 떨어뜨리기 쉬워집니다.',
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
          title: t(ko: '앞 모서리를 찔러 넘겨 마무리', ja: '前角を突いて仕上げ', en: 'Finish by poking the front corner (突き)'),
          detail: t(
            ko: '봉 위에 걸친 상태에서 앞 모서리를 집게발로 찔러, 상자가 자기 무게로 넘어가게 합니다.',
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
          title: t(ko: '앞 모서리 찔러 넘기기', ja: '前角を突く', en: 'Poke the front corner (突き)'),
          detail: t(
            ko: '모서리를 찔러 들어 올린 뒤, 상자가 자기 무게로 움직이게 합니다.',
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
              ? t(ko: '고리 구멍 가운데보다 살짝 안쪽에 집게발 넣기', ja: '輪の中心よりやや奥に爪を入れる', en: 'Put a claw tip slightly behind the ring centre (輪掛け)')
              : t(ko: '태그·목·팔 사이처럼 걸리는 부분에 집게발 걸기', ja: 'タグ・首・腕の間など引っ掛かる部位に爪を掛ける', en: 'Hook a tip on the tag, neck or between limbs'),
          detail: onRing
              ? t(
                  ko: '구멍은 보기보다 작습니다. 첫 판은 집게가 벌어지는 폭을 확인하는 판으로 생각하고, 움직이지 않으면 조금 당기는 쪽으로 조준을 옮깁니다.',
                  ja: '穴は見た目より小さいです。1手目は開き幅の把握用と考え、動かなければ少し寄せ気味に狙いを変えます。',
                  en: 'The hole is smaller than it looks. Treat the first play as a test of the claw opening width; if nothing moves, shift the aim slightly toward pulling.',
                )
              : t(
                  ko: '집게발 각도가 90°에 가까울수록 힘이 잘 전달됩니다. 작은 인형은 태그를 걸어 출구 쪽으로 끌어당깁니다.',
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
            ko: '운이 크게 작용하는 배치입니다. 꽝 구멍이 이미 많이 메워진 기계나, 당첨 구멍에 가까운 자리를 고릅니다.',
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
          title: t(ko: '쌓인 더미 꼭대기 근처를 눌러 무너뜨리기', ja: '山の頂上付近を押して崩す(雪崩)', en: 'Press near the top of the pile to trigger an avalanche (雪崩)'),
          detail: t(
            ko: '끌어당기기·밀기·퍼 올리기가 기본입니다. 출구 쪽으로 내려가는 비탈 방향으로 밀어서 더미를 무너뜨립니다.',
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
        title: t(ko: '세 집게발이 무게중심을 감싸도록 가운데에', ja: '重心を3本の爪で包むように中央へ', en: 'Centre the three tips around the centre of mass'),
        detail: t(
          ko: '집게발이 인형 아래로 들어갔는지 확인합니다. 출구 옆 가림판에 걸리면 반대쪽을 들어 떨어뜨립니다.',
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
    if (technique == Technique.tateHame && steps.length == 3 && steps.first.technique == Technique.yose) {
      // The pull-forward play is made once; afterwards alternate the two 縦ハメ plays.
      return played == 0 ? 0 : 1 + (played - 1) % 2;
    }
    return played % steps.length;
  }

  List<String> _abortConditions(AnalysisResult a, Technique technique, _Tr t) {
    final list = <String>[...a.strategy.abortIf];
    list.add(t(
      ko: '세 판 연속으로 아무 변화가 없으면 조준점을 바꾸거나 그만둡니다(집게 힘이 약하게 설정된 기계).',
      ja: '3手連続で変化がなければ狙いを変えるか撤退(設定が弱い台)。',
      en: 'No change in 3 consecutive plays → change the aim or walk away (weak setting).',
    ));
    if (a.layoutType.isBridge) {
      list.add(t(
        ko: '상자가 가로로 두 봉 위에 완전히 얹히면 끼인 상태입니다. 직원에게 처음 위치로 되돌려 달라고 부탁하세요.',
        ja: '箱が横で両バーに完全に乗ったら詰み。店員に初期位置戻しを依頼。',
        en: 'If the box ends up flat across both bars it is stuck (詰み); ask the staff to reset it.',
      ));
    }
    if (a.layoutType == LayoutType.ringD || a.layoutType == LayoutType.ringPera) {
      list.add(t(
        ko: '고리가 흔들리기만 하고 움직이지 않으면 바로 그만둡니다.',
        ja: 'リングが震えるだけで動かなければ即撤退。',
        en: 'If the ring only vibrates without moving, stop immediately.',
      ));
    }
    if (a.layoutType == LayoutType.hangString) {
      list.add(t(
        ko: '끈이 흔들리기만 하고 고리가 움직이지 않으면 바로 그만둡니다.',
        ja: '紐が揺れるだけで輪が動かなければ即撤退。',
        en: 'If the string only sways and the loop does not move, stop immediately.',
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
    final prize = geo.prizeBox.copyWith(label: t(ko: '경품', ja: '景品', en: 'prize'));
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
        label: t(ko: '앞 봉', ja: '手前バー', en: 'front bar'),
      ));
      cylinders.add(SceneCylinder(
        id: 'bar_back',
        p0: Vec3(-hx, -geo.barGapMm / 2, backZ),
        p1: Vec3(hx, -geo.barGapMm / 2, backZ),
        radius: options.barRadiusMm,
        material: tube ? SceneMaterial.rubberTube : SceneMaterial.metal,
        label: t(ko: '안쪽 봉', ja: '奥バー', en: 'back bar'),
      ));
      for (var i = 0; i < geo.extraBarYMm.length; i++) {
        final y = geo.extraBarYMm[i];
        cylinders.add(SceneCylinder(
          id: 'bar_extra_$i',
          p0: Vec3(-hx, y, options.barHeightMm),
          p1: Vec3(hx, y, options.barHeightMm),
          radius: options.barRadiusMm,
          material: tube ? SceneMaterial.rubberTube : SceneMaterial.metal,
          label: t(ko: '봉 ${i + 3}', ja: 'バー${i + 3}', en: 'bar ${i + 3}'),
        ));
      }
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
        label: t(ko: '받침대', ja: 'フィールド', en: 'field'),
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
        rotation: corrections.clawRotation,
      );
      markers.add(SceneMarker(
        point: current.fieldPoint,
        label: t(ko: '집게 중심', ja: 'アーム中心', en: 'claw centre'),
        arm: current.arm,
      ));
      if (current.arm != Arm.both) {
        final tipX = current.fieldPoint.x + (current.arm == Arm.right ? 1 : -1) * options.clawOpenWidthMm / 2;
        markers.add(SceneMarker(
          point: Vec3(tipX, current.fieldPoint.y, current.fieldPoint.z),
          label: t(ko: '집게발 닿는 곳', ja: '爪の接点', en: 'tip contact'),
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
    final r = p.rotation;
    final rightSide = current.arm == Arm.right;
    Pose to;
    String desc;
    switch (technique) {
      case Technique.tateHame:
        to = Pose(Vec3(pos.x, pos.y + 15, pos.z - 25), r.plus(pitchDeg: -32, yawDeg: rightSide ? -6 : 6));
        desc = t(ko: '안쪽 끝이 들리고 앞쪽이 봉 사이로 내려감', ja: '奥端が上がり前側がバーの間へ下がる', en: 'Back end rises, front slides into the gap');
      case Technique.yokoHame:
        // The hooked corner is dragged toward the claw centre: the right arm
        // turns the box counter-clockwise seen from above (negative yaw here).
        to = Pose(pos, r.plus(yawDeg: rightSide ? -35 : 35));
        desc = t(ko: '위에서 볼 때 약 35° 돌아감', ja: '上から見て約35°回転', en: 'Rotates about 35° seen from above');
      case Technique.yose:
      case Technique.zurashi:
        final dx = exit == ExitSide.left ? -50.0 : (exit == ExitSide.right ? 50.0 : 0.0);
        final dy = dx == 0 ? 45.0 : 0.0;
        to = Pose(Vec3(pos.x + dx, pos.y + dy, pos.z), p.rotation);
        desc = t(ko: '출구 쪽으로 몇 cm 이동', ja: '落とし口方向へ数cm移動', en: 'Slides a few cm toward the exit');
      case Technique.oshikomi:
        to = Pose(Vec3(pos.x, pos.y + 30, pos.z - 30), r.plus(pitchDeg: -28));
        desc = t(ko: '앞 모서리가 내려가며 떨어짐', ja: '前角が下がって落下', en: 'Front edge dips and the prize falls');
      case Technique.mochiage:
      case Technique.kadoOshi:
        to = Pose(Vec3(pos.x, pos.y, pos.z + 25), r.plus(rollDeg: rightSide ? -18 : 18));
        desc = t(ko: '모서리가 들려 기울어짐', ja: '角が持ち上がって傾く', en: 'The corner lifts and the prize tilts');
      case Technique.noriage:
        to = Pose(Vec3(pos.x, pos.y + 10, pos.z + 20), r.plus(pitchDeg: -22));
        desc = t(ko: '안쪽 끝이 안쪽 봉 위에 얹힘', ja: '奥端が奥バーに乗る', en: 'Back end rests on the back bar');
      case Technique.tsuki:
        to = Pose(Vec3(pos.x, pos.y + 25, pos.z - 15), r.plus(pitchDeg: -15));
        desc = t(ko: '찔린 모서리가 들리고 앞으로 넘어감', ja: '突かれた角が上がり前へ倒れる', en: 'Poked corner lifts and it tips forward');
      case Technique.hikkake:
        to = Pose(Vec3(pos.x, pos.y, pos.z + 60), p.rotation);
        desc = t(ko: '걸린 부분이 들려 올라감', ja: '掛かった部位が持ち上がる', en: 'The hooked part lifts');
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
      extraBars: geo.extraBarLines,
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
    required this.extraBarLines,
    required this.extraBarYMm,
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

  /// Bars other than the supporting pair (3-/4-bar setups): image lines and
  /// their estimated field Y positions.
  final List<List<Pt>> extraBarLines;
  final List<double> extraBarYMm;
  final bool barsSynthesized;

  /// Total number of bars (supporting pair + extras) when the layout is a bridge.
  int get barCount => (frontBarLine == null ? 0 : 1) + (backBarLine == null ? 0 : 1) + extraBarLines.length;

  /// Image height of the prize top face (front edge → back edge).
  double get topFaceHeightImg => (topFace[0].y - topFace[3].y).abs();
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
  /// (fx: left→right, fy: top→bottom of the bbox). The top of the bbox is the
  /// far side (奥, −Y) and the bottom the near side (手前, +Y), matching the
  /// top-face convention of [top]. Used for plush/ring targets.
  Vec3 fieldOnBbox(double fx, double fy) {
    final s = prizeBox.size;
    return prizeBox.pose.toWorld(Vec3((fx - 0.5) * s.x, (fy - 0.5) * s.y, s.z / 2));
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
    NBox? front = corrections.frontBar?.normalized();
    NBox? back = corrections.backBar?.normalized();
    final detectedBars = analysis.objects.where((o) => o.kind.isBar).map((o) => o.bbox).toList()
      ..sort((a, b) => a.cy.compareTo(b.cy));
    if (front == null || back == null) {
      if (detectedBars.length >= 2) {
        // 3-/4-bar setups: the supporting pair is the outermost bars that
        // touch the prize (between its top face and its bottom edge); fall
        // back to the outermost bars overall.
        final touching = detectedBars
            .where((b) => b.cy >= prizeBbox.y1 - 0.03 && b.cy <= prizeBbox.y2 + 0.04)
            .toList();
        final pool = touching.length >= 2 ? touching : detectedBars;
        back ??= pool.first;
        front ??= pool.last;
      } else if (detectedBars.length == 1) {
        final b = detectedBars.single;
        if (b.cy > prizeBbox.cy) {
          front ??= b;
        } else {
          back ??= b;
        }
      }
    }
    final extras = <NBox>[
      for (final b in detectedBars)
        if (b != front && b != back) b,
    ];
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
    final fieldSpan = math.max(xr - xl, 1e-3);

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
    // Extra bars: place them in the field by interpolating their image row
    // between the supporting pair (front bar = +gap/2, back bar = −gap/2).
    final extraLines = <List<Pt>>[];
    final extraY = <double>[];
    if (layout.isBridge && front != null && back != null) {
      final span = (front.cy - back.cy).abs();
      for (final b in extras) {
        extraLines.add([Pt(b.x1, b.cy), Pt(b.x2, b.cy)]);
        final f = span < 1e-6 ? 0.5 : ((front.cy - b.cy) / span);
        extraY.add((gap / 2 - f * gap).clamp(-gap / 2 - 150.0, gap / 2 + 150.0));
      }
    }
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

    final dropHole = corrections.dropHole?.normalized() ??
        (analysis.ofKind(ObjectKind.dropHole).isNotEmpty ? analysis.ofKind(ObjectKind.dropHole).first.bbox : null);
    final claw = corrections.claw?.normalized() ??
        (analysis.ofKind(ObjectKind.claw).isNotEmpty ? analysis.ofKind(ObjectKind.claw).first.bbox : null);

    return _Geometry(
      prizeBbox: prizeBbox,
      topFace: topFace,
      frontBarLine: frontLine,
      backBarLine: backLine,
      extraBarLines: extraLines,
      extraBarYMm: extraY,
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
