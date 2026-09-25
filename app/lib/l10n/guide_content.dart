/// Beginner guide for every [LayoutType] (기초 가이드): how to recognise the
/// setup in the cabinet, where to put the claw, which techniques apply, tips,
/// when to walk away and what it typically costs.
///
/// Written from docs/01_기획_기술_분석.md §3 and docs/research/domain.md §1–3, §7.
/// Japanese and English text keep the Japanese community terms in parentheses
/// (橋渡し, 縦ハメ, 寄せ …); Korean text is plain Korean (see CLAUDE.md rule 7).
/// Cost figures marked ★ are community reference values, never promises.
/// No text here may promise a win.
library;

import 'package:flutter/material.dart';

import '../models/analysis.dart';
import 'strings.dart';

/// Guide content for one layout type in one language.
class LayoutGuide {
  const LayoutGuide({
    required this.type,
    required this.summary,
    required this.recognize,
    required this.howTo,
    required this.techniques,
    required this.tips,
    required this.abortWhen,
    required this.typicalCost,
  });

  final LayoutType type;

  /// One line shown in the list.
  final String summary;

  /// What to look for in the cabinet (3–6 bullets).
  final List<String> recognize;

  /// Beginner steps: where to put the claw, which arm, what should happen (4–8).
  final List<String> howTo;

  /// Techniques that apply (empty only for [LayoutType.unknown]).
  final List<Technique> techniques;

  /// Practical hints (2–4).
  final List<String> tips;

  /// Conditions under which to stop playing (2–3).
  final List<String> abortWhen;

  /// Typical cost text, e.g. "숙련자 1,000~2,000엔 ★ 참고값".
  final String typicalCost;

  /// Every string of the guide, for checks.
  List<String> get allText => [summary, ...recognize, ...howTo, ...tips, ...abortWhen, typicalCost];
}

/// Material icon shown next to a layout type in the guide list (icons
/// render on every device and font, unlike emoji).
IconData layoutIcon(LayoutType t) => switch (t) {
      LayoutType.bridgeParallel => Icons.view_column_outlined,
      LayoutType.bridgeHanoji => Icons.architecture,
      LayoutType.bridgeStep => Icons.stairs_outlined,
      LayoutType.bridgeFour => Icons.reorder,
      LayoutType.bridgeMixed => Icons.call_merge,
      LayoutType.frontDrop => Icons.arrow_downward,
      LayoutType.valleyDrop => Icons.landscape_outlined,
      LayoutType.sideDrop => Icons.arrow_forward,
      LayoutType.ringPera => Icons.label_outline,
      LayoutType.ringD => Icons.link,
      LayoutType.hangString => Icons.cable,
      LayoutType.hookS => Icons.phishing,
      LayoutType.takoyaki => Icons.grid_on,
      LayoutType.threeClaw => Icons.toys_outlined,
      LayoutType.twoClawDirect => Icons.pan_tool_alt_outlined,
      LayoutType.pile => Icons.terrain,
      LayoutType.floorBox => Icons.inventory_2_outlined,
      LayoutType.unknown => Icons.help_outline,
    };

T _pick<T>(AppLocale l, T ko, T ja, T en) => switch (l) {
      AppLocale.ko => ko,
      AppLocale.ja => ja,
      AppLocale.en => en,
    };

/// The guide for [type] in the language of [s].
LayoutGuide guideFor(LayoutType type, S s) {
  final l = s.locale;
  String t(String ko, String ja, String en) => _pick(l, ko, ja, en);
  List<String> list(List<String> ko, List<String> ja, List<String> en) => _pick(l, ko, ja, en);

  switch (type) {
    // -------------------------------------------------------------------------
    case LayoutType.bridgeParallel:
      return LayoutGuide(
        type: type,
        summary: t(
          '상자 하나가 평행한 봉 2개 위에 걸쳐 있는 가장 흔한 배치입니다. 들어 올리려 하지 말고, 상자 끝을 집게발로 걸어 조금씩 돌려서 떨어뜨립니다.',
          '箱1個が平行な2本のバーに掛かる標準設定（橋渡し）。持ち上げず、端に爪を掛けて少しずつ回して落とします。',
          'One box resting across two parallel bars (橋渡し), the standard figure-box setup. Do not lift it: hook an end and rotate it down bit by bit.',
        ),
        recognize: list(
          [
            '상자 경품 하나가 평행한 금속·고무 봉 2개 위에 세로 또는 가로로 걸쳐 있음',
            '봉 사이 간격이 상자의 긴 변보다 좁고, 출구는 봉 사이 아래쪽',
            '처음에는 대개 상자가 안쪽으로 살짝 치우쳐 있음',
            '봉에 분홍·투명 튜브가 씌워져 있지 않음 (씌워져 있으면 "높이가 다르거나 튜브를 씌운 봉" 유형)',
          ],
          [
            '箱型の景品1個が平行な金属・ゴムのバー2本に縦または横に掛かっている',
            'バー間隔が箱の長辺より狭く、落とし口はバーの間の下',
            '初期位置はたいてい気持ち奥寄り',
            'バーにピンク・透明のチューブがない（あれば段差/チューブ型）',
          ],
          [
            'One box-shaped prize lies lengthwise or sideways across two parallel metal or rubber bars',
            'The bar gap is narrower than the long side of the box; the drop hole is the gap below',
            'The starting position is usually shifted slightly toward the back (奥)',
            'No pink or clear tubing on the bars (that would be the stepped / tube type)',
          ],
        ),
        howTo: list(
          [
            '먼저 무게를 가늠합니다. 무거운 상자는 세워서 떨어뜨리기, 가벼운 상자는 눕혀서 떨어뜨리기가 기본입니다.',
            '상자 한가운데가 아니라, 한쪽 집게발이 상자 끝부분에 아슬아슬하게 걸리는 곳에 집게 중심을 맞춥니다.',
            '첫 판: 오른쪽 집게발을 상자 안쪽 끝 바로 안에 걸어 안쪽을 살짝 들어 올립니다. 상자가 앞 봉을 축으로 기울면 성공입니다.',
            '두 번째 판: 왼쪽 집게로 반대쪽 안쪽 모서리를 같은 방법으로 겁니다. 좌우를 번갈아 흔들며 조금씩 세웁니다.',
            '상자가 비스듬히 서면, 잘 들리지 않는 무거운 쪽은 피하고 가벼운 쪽을 노려 더 크게 돌립니다.',
            '마지막에는 봉 사이로 빠질 만큼 세운 뒤, 걸려 있는 남은 모서리를 집게발로 눌러 떨어뜨립니다.',
            '가벼운 상자라면 안쪽을 노린 뒤 반대쪽 집게로 오른쪽 앞을 걸어, 상자를 눕혀서 떨어뜨립니다.',
          ],
          [
            'まず重さを見極める: 重い箱は縦ハメ、軽い箱は横ハメが定石。',
            '箱の中央ではなく、片方のアームの爪が箱の端ギリギリに掛かる位置にアーム中心を合わせる。',
            '1手目: 右アームの爪を奥の端のすぐ内側に掛け、奥側を少し持ち上げる。箱が手前バーを軸に傾けば成功。',
            '2手目: 左アームで反対側の奥角を同じように掛ける。左右交互に揺らして少しずつ立てる。',
            '箱が斜めに立ったら、浮かない（重い）側を避けて軽い側を狙い、回転を大きくする。',
            '最後はバーの間に落ちるまで立て、残った角（残存角）を爪で押して落とす。',
            '軽い箱なら奥を狙った後、反対のアームで右手前を掛けて横にして落とす（横ハメ）。',
          ],
          [
            'Judge the weight first: heavy boxes are stood up (縦ハメ), light boxes are turned flat (横ハメ).',
            'Aim the claw centre so one arm\'s tip lands just inside the very end of the box (端ギリギリ), not at the middle.',
            'Play 1: hook the right arm\'s tip just inside the back (奥) end and lift the back a little. Success looks like the box tilting on the front bar.',
            'Play 2: hook the opposite back corner with the left arm the same way. Alternate sides to rock the box upright bit by bit.',
            'Once the box stands at an angle, avoid the side that does not lift (the heavy side) and aim at the light side to rotate more.',
            'Finally stand it up until it slips between the bars, then press the remaining corner (残存角) down with a tip.',
            'For a light box, aim at the back first, then hook the front-right with the other arm to turn it flat (横ハメ).',
          ],
        ),
        techniques: const [Technique.tateHame, Technique.yokoHame, Technique.kadoOshi, Technique.yose, Technique.oshikomi],
        tips: list(
          [
            '집게 힘은 사진으로는 알 수 없습니다. 첫 판에 상자가 얼마나 움직이는지 보고 판단하세요.',
            '집게발이 닿는 곳이 무게중심에서 멀수록 작은 힘으로도 크게 돕니다. 그래서 끝부분을 노립니다.',
            '잘 들리지 않는 쪽이 무거운 쪽입니다. 무거운 쪽을 아래로 해서 세우면 세워서 떨어뜨리기가 쉬워집니다.',
          ],
          [
            'アームパワーは写真では分からない。1手目の動きの大きさで判断する。',
            '接点が重心から遠いほど小さな力で大きく回る。だから端を狙う。',
            '浮かない側が重い側。重い側を下にして立てると縦ハメが楽になる。',
          ],
          [
            'Arm power is invisible in a photo: judge it from how much the box moves on play 1.',
            'The farther the contact point is from the centre of mass, the more it rotates per play, which is why you aim at the end.',
            'The side that does not lift is the heavy side; standing it heavy-side-down makes 縦ハメ easier.',
          ],
        ),
        abortWhen: list(
          [
            '상자가 두 봉 위에 가로로 평평하게 얹혀 꼼짝하지 않음(끼임) → 직원에게 처음 위치로 돌려 달라고 요청',
            '한쪽 집게발로 끌어도, 안쪽이나 앞쪽을 들어도 3판 연속 전혀 움직이지 않음',
          ],
          [
            '箱が横向きで2本のバーに平らに乗って動かない（詰み）→「初期位置に戻してください」と依頼',
            '片爪で寄せても、奥・手前を持ち上げても3手続けて全く動かない',
          ],
          [
            'The box lies flat across both bars and will not move (詰み): ask the staff 「初期位置に戻してください」',
            'Three plays in a row with no movement at all, whether pulling with one tip or lifting the back or front',
          ],
        ),
        typicalCost: t(
          '숙련자 1,000~2,000엔, 초보자 1,000~3,000엔 ★ 참고값',
          '慣れた人 1,000〜2,000円、初心者 1,000〜3,000円 ★ コミュニティの参考値',
          '¥1,000–2,000 for experienced players, ¥1,000–3,000 for beginners ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.bridgeHanoji:
      return LayoutGuide(
        type: type,
        summary: t(
          '두 봉 사이가 한쪽으로 갈수록 벌어지는 배치입니다. 상자를 돌려 가며 넓은 쪽으로 옮겨 빠지게 합니다.',
          '2本のバーが片側へ広がる橋渡し（末広がり / ハの字）。広い側へ箱を回して移動させ、抜けさせます。',
          'A bridge whose bars flare apart toward one end (末広がり / ハの字). Rotate and walk the box toward the wide end until it slips through.',
        ),
        recognize: list(
          [
            '두 봉이 평행하지 않고, 앞쪽이나 안쪽으로 갈수록 간격이 넓어짐',
            '넓은 쪽은 상자가 빠질 수 있을 만큼 틈이 큼',
            '상자는 보통 좁은 쪽에 걸쳐진 채로 시작',
          ],
          [
            '2本のバーが平行でなく、手前または奥へ行くほど間隔が広がる',
            '広い側では箱が抜けるほど隙間が大きい',
            '箱はたいてい狭い側に掛けた状態でスタート',
          ],
          [
            'The two bars are not parallel; the gap widens toward the front or the back',
            'At the wide end the gap is big enough for the box to fall through',
            'The box usually starts resting over the narrow end',
          ],
        ),
        howTo: list(
          [
            '먼저 집게 힘을 확인합니다. 첫 판에 상자가 거의 움직이지 않으면 세워서 떨어뜨리기는 어렵다고 보고, 옮기는 쪽으로 갑니다.',
            '상자를 넓은 쪽으로 돌립니다. 넓은 쪽에서 먼 끝의 모서리에 한쪽 집게발을 걸어 끌어당깁니다.',
            '좌우 집게를 번갈아 써서 상자가 넓은 쪽으로 조금씩 옮겨지며 돌아가게 합니다.',
            '집게 힘이 세거나 상자 속이 비어 가볍다면 들어 올리기: 양쪽 집게로 상자를 집어 넓은 쪽으로 옮깁니다.',
            '그렇지 않으면 봉 위로 올리기: 양쪽 집게로 안쪽 모서리를 들어 한쪽 봉 위에 올려 균형을 무너뜨립니다.',
            '틈이 상자 폭보다 넓어지는 곳까지 오면 안쪽 끝을 눌러 떨어뜨립니다.',
          ],
          [
            'まずアームパワーを確認。1手目でほぼ動かなければ縦ハメは難しいと見て、移動中心に切り替える。',
            '広い側へ箱を回す: 広い側から遠い端の角に片方の爪を掛けて寄せる。',
            '左右のアームを交互に使い、箱が広い側へ少しずつ移動・回転するようにする。',
            'アームが強い、または箱の中身が軽ければつまみ上げ: 両アームで箱をつまんで広い側へ運ぶ。',
            'そうでなければ乗り上げ: 両アームで奥の角を持ち上げ、片方のバーに乗せてバランスを崩す。',
            '隙間が箱の幅より広くなる位置まで来たら、奥の端を押して落とす。',
          ],
          [
            'Check arm power first. If the box barely moves on play 1, treat standing it up (縦ハメ) as unlikely and focus on moving it.',
            'Rotate the box toward the wide end: hook one tip on the corner farthest from the wide end and pull (寄せ).',
            'Alternate left and right arms so the box shifts and turns toward the wide end a little each play.',
            'With a strong arm or a hollow, light box, pinch-lift (つまみ上げ): grab it with both arms and carry it toward the wide end.',
            'Otherwise ride it up (乗り上げ): lift a back corner with both arms and rest it on one bar to break its balance.',
            'Once the gap is wider than the box, press the back end down to drop it.',
          ],
        ),
        techniques: const [Technique.yose, Technique.noriage, Technique.mochiage, Technique.zurashi],
        tips: list(
          [
            '집게 힘이 약하면 상자가 옆면으로 서는 일은 거의 없고 아주 조금씩만 밀립니다. 판 수가 많이 들 각오를 하세요.',
            '평행한 봉보다 보통 판 수가 더 듭니다.',
            '어느 쪽이 넓은지 사진으로 먼저 확실히 확인해 두세요.',
          ],
          [
            'アームが弱いと側面を下にして立つことはほぼなく、ごくわずかにずれるだけ。手数を覚悟する。',
            '平行型より手数が多くなりがち。',
            'どちらが広い側かを写真でしっかり把握しておく。',
          ],
          [
            'With a weak arm the box almost never stands on its side; it just creeps a little. Expect more plays.',
            'Usually takes more plays than the parallel type.',
            'Make sure which end is the wide one before you start.',
          ],
        ),
        abortWhen: list(
          ['3판 연속 밀리지도 돌지도 않음', '상자가 좁은 쪽에 가로로 꽉 끼어 움직이지 않음(끼임)'],
          ['3手続けてずれも回りもしない', '箱が狭い側に横向きでがっちり嵌まった（詰み）'],
          ['Three plays in a row with neither shift nor rotation', 'The box has jammed sideways at the narrow end (詰み)'],
        ),
        typicalCost: t(
          '매장 설정에 따라 다름. 대체로 평행한 봉보다 더 듦 (2,000~4,000엔) ★ 참고값',
          '店の設定次第、平行型より手数が多め（2,000〜4,000円）★ コミュニティの参考値',
          'Depends on the store setting; usually more than the parallel bridge (¥2,000–4,000) ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.bridgeStep:
      return LayoutGuide(
        type: type,
        summary: t(
          '봉 높이가 서로 다르거나, X자로 교차하거나, 분홍·투명 고무 튜브를 씌운 배치입니다. 얼마나 미끄러운지 보고 밀어 옮길지 들어 올릴지 고릅니다.',
          'バーの高さが違う（段差）、X字に交差する、またはピンク・透明チューブ付きの橋渡し。摩擦を読んで滑らせるか持ち上げるかを選びます。',
          'A bridge with bars at different heights (段差), crossed bars, or pink / clear tubing (ピンクチューブ). Read the friction and choose between sliding and lifting.',
        ),
        recognize: list(
          [
            '두 봉의 높이가 다름 (그림자와 원근으로 구분)',
            '봉이 X자로 교차함',
            '봉 가운데에 분홍·투명 고무 튜브가 씌워져 있음 (색으로 바로 구분)',
            '상자가 높은 봉에 기대어 비스듬히 놓인 경우가 많음',
          ],
          [
            '2本のバーの高さが違う（影・遠近で判別）',
            'バーがX字に交差している（クロス）',
            'バーの中央にピンク・透明のゴムチューブが被さっている（色ですぐ分かる）',
            '箱が高い方のバーにもたれて斜めに置かれていることが多い',
          ],
          [
            'The two bars are at different heights (judge by shadows and perspective)',
            'The bars cross in an X (クロス)',
            'Pink or clear rubber tubing covers the middle of the bars (instantly visible by colour)',
            'The box often starts leaning at an angle against the higher bar',
          ],
        ),
        howTo: list(
          [
            '높이가 다른 봉: 먼저 상자를 높은 봉에 기대어 세로로 비스듬히 서게 만듭니다. 낮은 봉 쪽 끝에 집게발을 걸어 끌어당깁니다.',
            '그 상태에서 밀어 올리기: 상자 아래쪽 끝에 집게발을 걸어 높은 봉 위로 미끄러뜨려 올립니다. 상자가 세로로 서 있을 때만 힘이 전달됩니다.',
            '분홍 고무 튜브가 있으면 마찰이 아주 커서 미끄러지지 않습니다. 밀어 옮기는 방법은 버리고 들어 올리기나 돌리기로 바꿉니다.',
            '튜브가 없는 구간이 있으면 좌우로 끌어당겨 상자를 먼저 그쪽으로 옮깁니다.',
            '들어 올리기·돌리기: 양쪽 집게로 안쪽 모서리를 들어 봉 위로 올리거나, 한쪽 끝을 걸어 세워서 떨어뜨립니다.',
            'X자로 교차한 봉은 교차점에서 먼 쪽(틈이 넓은 쪽)으로 상자를 돌려 옮깁니다.',
          ],
          [
            '段差: 箱を高いバーにもたれさせた「真縦の斜めハマり」をまず作る。低いバー側の端に爪を掛けて寄せる。',
            'その状態でずり上げ: 箱の下側の端に爪を掛け、高いバーの上へ滑らせて上げる。縦姿勢のときだけ力が伝わる。',
            'ピンクチューブがあると摩擦が非常に大きく滑らない。スライド系は捨て、持ち上げ・回転に切り替える。',
            'チューブのない区間があれば、左右の寄せで箱を先にそちらへ移す。',
            '持ち上げ・回転: 両アームで奥の角を持ち上げてバーに乗せる乗り上げ、または片端を掛けて立てる縦ハメを使う。',
            'クロス型は交差点から遠い側（隙間が広い側）へ箱を回して移す。',
          ],
          [
            'Stepped (段差): first make the box lean upright against the higher bar (真縦の斜めハマり) by hooking the end near the lower bar and pulling.',
            'Then slide it up (ずり上げ): hook the lower end of the box and slide it up onto the higher bar. Force only transfers while the box is upright.',
            'Pink tubing means very high friction: nothing slides. Drop the sliding techniques and switch to lifting or rotating.',
            'If part of the bar has no tubing, first pull (寄せ) the box left or right onto that section.',
            'Lifting / rotating: ride a back corner up onto the bar with both arms (乗り上げ), or hook one end and stand the box up (縦ハメ).',
            'Crossed bars (クロス): rotate and move the box away from the crossing point, toward the wider gap.',
          ],
        ),
        techniques: const [Technique.zurashi, Technique.noriage, Technique.tateHame, Technique.mochiage],
        tips: list(
          [
            '상자가 가로로 누워 있으면 닿는 면이 넓어 힘이 잘 전달되지 않아 밀어 올리기가 실패하기 쉽습니다.',
            '튜브는 습하면 마찰이 더 세지고, 먼지가 끼거나 낡으면 약해집니다 (매장 관리에 따라 다름).',
            '돈이 계속 들어가기 쉬운 배치입니다. 몇 판까지 할지 미리 정하세요.',
          ],
          [
            '横向きでのずり上げは面積が広くて力が伝わらず失敗しやすい。',
            'チューブは湿気で摩擦が強くなり、ほこり・劣化で弱くなる（店の管理次第）。',
            '「沼」になりやすい設定。手数の上限を先に決めておく。',
          ],
          [
            'Sliding a box that lies flat rarely works: the wide contact area soaks up the force.',
            'Tubing grips harder when damp and less when dusty or worn (depends on the store).',
            'This setting easily becomes a money pit (沼). Set a play limit before you start.',
          ],
        ),
        abortWhen: list(
          ['2~3판 동안 전혀 미끄러지지도 들리지도 않음', '상자가 튜브 구간에 가로로 걸쳐 꼼짝하지 않음(끼임)'],
          ['2〜3手の間まったく滑りも持ち上がりもしない', '箱がチューブ区間に横向きで固定された（詰み）'],
          ['No slide and no lift at all for two or three plays', 'The box is pinned sideways on the tubed section (詰み)'],
        ),
        typicalCost: t(
          '설정에 따라 차이가 큼. 움직이지 않으면 바로 그만두기 (상한 1,000~3,000엔 권장) ★ 참고값',
          '設定差が大きい。動かなければ即撤退（上限1,000〜3,000円を推奨）★ コミュニティの参考値',
          'Varies a lot by setting; walk away as soon as nothing moves (a ¥1,000–3,000 cap is sensible) ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.bridgeFour:
      return LayoutGuide(
        type: type,
        summary: t(
          '평행한 봉 4개가 있는 배치입니다. 보통 가운데 두 봉에 상자가 걸쳐 있고 그 사이가 출구이며, 바깥 봉은 상자가 기울 때 받쳐 줍니다. 가운데 틈으로 세워서 떨어뜨립니다.',
          '平行なバーが4本の設定（4本橋渡し）。多くは中央の2本に箱が掛かり、その間が落とし口で、外側のバーは箱が傾いたときの受けになる。中央の隙間へ立てて落とす。',
          'Four parallel bars (4本橋渡し). Usually the box rests on the middle two, the gap between them is the drop, and the outer bars catch the box when it tilts. Stand it up into the middle gap.',
        ),
        recognize: list(
          [
            '평행한 봉이 4개(가운데 2개 + 양 끝 2개)이고, 상자가 가운데 두 봉 위에 걸쳐 있음',
            '출구는 가운데 두 봉 사이. 바깥쪽 틈은 좁거나 막혀 있어 떨어지지 않음',
            '바깥 봉이 가운데 봉보다 높거나 낮을 수 있음 (높이 차이가 있으면 "높이가 다르거나 튜브를 씌운 봉" 가이드도 참고)',
            '상자 끝이 바깥 봉 가까이 있으면, 그쪽으로 기울어도 바깥 봉에 받쳐 되돌아옴',
          ],
          [
            '平行なバーが4本（中央2本＋両端2本）で、箱は中央の2本に掛かっている',
            '落とし口は中央2本の間。外側の隙間は狭いか塞がっていて落ちない',
            '外側のバーが中央より高い・低いこともある（段差があれば段差・チューブ型のガイドも参考に）',
            '箱の端が外側のバーの近くにあると、その側に傾いても外側のバーに受け止められて戻る',
          ],
          [
            'Four parallel bars (two in the middle, one at each end); the box rests across the middle two',
            'The drop is the gap between the middle bars; the outer gaps are narrow or blocked',
            'The outer bars may sit higher or lower than the middle ones (if so, see the stepped/tube guide too)',
            'If a box end is near an outer bar, tilting that way only lands it on the outer bar and it comes back',
          ],
        ),
        howTo: list(
          [
            '먼저 상자가 어느 두 봉에 얹혀 있고 어느 틈이 출구인지 확인합니다. 보통 가운데 두 봉 사이입니다.',
            '기본은 세워서 떨어뜨리기입니다. 상자 끝부분에 한쪽 집게발을 걸어 들어 올리고, 좌우를 번갈아 가며 가운데 틈 쪽으로 조금씩 기울입니다.',
            '바깥 봉 쪽으로 너무 밀면 상자가 바깥 봉에 올라타 끼이기 쉽습니다. 상자 중심을 가운데 틈 위에 두세요.',
            '상자 한쪽 끝이 가운데 틈으로 빠져 비스듬히 서면, 위로 올라간 끝을 걸어 더 세웁니다.',
            '거의 섰는데 모서리가 봉에 걸려 있으면, 남은 모서리를 집게발로 눌러 떨어뜨립니다.',
            '가운데 틈이 상자 폭보다 넓으면 평행한 봉 2개일 때처럼 눕혀서 떨어뜨리기도 쓸 수 있습니다.',
          ],
          [
            'まず箱がどの2本に乗り、どの隙間が落とし口かを確認する。多くは中央2本の間。',
            '基本は縦ハメ。箱の端（端ギリギリ）に片方の爪を掛けて持ち上げ、左右交互に中央の隙間側へ少しずつ傾ける。',
            '外側のバーの方へ押しすぎると、箱が外側のバーに乗り上げて詰みやすい。箱の重心を中央の隙間の上に保つ。',
            '箱の片端が中央の隙間に落ちて斜めに立ったら、上がった端を掛けてさらに立てる。',
            'ほぼ立ったのに角がバーに引っ掛かっていれば、残った角（残存角）を爪で押して落とす。',
            '中央の隙間が箱の幅より広ければ、平行の橋渡しと同じく横ハメも使える。',
          ],
          [
            'First check which two bars carry the box and which gap is the drop; usually the gap between the middle bars.',
            'The default is 縦ハメ: hook one tip just inside the box end (端ギリギリ), lift, and alternate sides to tilt it little by little toward the middle gap.',
            'Pushing it toward an outer bar tends to leave it riding on that bar, stuck (詰み). Keep the box\'s centre over the middle gap.',
            'Once one end slips into the middle gap and the box leans, hook the raised end to stand it up further.',
            'If it is almost upright but a corner still catches on a bar, press that remaining corner (残存角) down with a tip.',
            'If the middle gap is wider than the box, 横ハメ works too, as on a parallel bridge.',
          ],
        ),
        techniques: const [Technique.tateHame, Technique.yokoHame, Technique.kadoOshi, Technique.yose],
        tips: list(
          [
            '봉이 많을수록 상자가 걸릴 곳도 많습니다. 한 판마다 상자가 어느 봉에 닿아 있는지 보세요.',
            '바깥 봉은 "받침"입니다. 상자 끝이 바깥 봉에 닿아 있으면 그쪽으로는 떨어지지 않습니다.',
            '가운데 틈이 좁을수록 세워서 떨어뜨리기 말고는 방법이 거의 없습니다.',
          ],
          [
            'バーが多いほど箱が引っ掛かる場所も多い。一手ごとに箱がどのバーに触れているかを見る。',
            '外側のバーは「受け」。箱の端が外側のバーに触れたら、その方向には落ちない。',
            '中央の隙間が狭いほど、縦ハメ以外の手はほぼない。',
          ],
          [
            'More bars mean more places to snag; after each play check which bars the box touches.',
            'The outer bars are catchers: once a box end touches one, it cannot fall that way.',
            'The narrower the middle gap, the more 縦ハメ is the only option.',
          ],
        ),
        abortWhen: list(
          [
            '상자가 바깥 봉과 가운데 봉에 평평하게 얹힘(끼임) → 직원에게 처음 위치로 돌려 달라고 요청',
            '3판 연속 상자가 기울지 않음',
          ],
          [
            '箱が外側と中央のバーに水平に乗った → 詰み。店員に初期位置戻しを依頼',
            '3手続けて箱が傾かない',
          ],
          [
            'The box lies flat across an outer and a middle bar: stuck (詰み), ask the staff to reset it',
            'The box does not tilt for three plays in a row',
          ],
        ),
        typicalCost: t(
          '평행한 봉 2개와 비슷한 1,000~3,000엔 정도로 추정 ★',
          '平行の橋渡しと同程度の1,000〜3,000円ほどと推定 ★',
          'Estimated ¥1,000–3,000, similar to a parallel bridge ★',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.bridgeMixed:
      return LayoutGuide(
        type: type,
        summary: t(
          '봉 4개 중 바깥 두 개는 평행하고, 안쪽 두 개는 한쪽으로 벌어지는 배치입니다. 안쪽 봉이 넓어지는 쪽으로 상자를 옮긴 뒤 그 틈으로 떨어뜨립니다.',
          '外側2本は平行、内側2本は片側へ広がる4本の複合設定（4本 平行＋ハの字）。内側のバーが広がる側へ箱を運び、その隙間から落とす。',
          'A four-bar mix (4本 平行＋ハの字): the outer two bars are parallel and the inner two flare out to one side. Move the box toward where the inner bars widen, then drop it through that gap.',
        ),
        recognize: list(
          [
            '봉이 4개: 바깥 두 개는 평행하고, 안쪽 두 개는 한쪽 끝으로 갈수록 벌어짐',
            '출구는 안쪽 두 봉 사이. 넓어지는 쪽일수록 떨어지기 쉬움',
            '바깥 평행 봉이 상자 끝을 받쳐 주어 좁은 쪽에서는 잘 빠지지 않음',
            '상자는 대개 좁은 쪽이나 가운데에서 시작',
          ],
          [
            'バーが4本：外側2本は平行で、内側2本は片端に向かって広がる',
            '落とし口は内側2本の間。広がる側ほど落ちやすい',
            '外側の平行バーが箱の端を受け、狭い側では落ちにくい',
            '箱はたいてい狭い側か中央から始まる',
          ],
          [
            'Four bars: the outer two are parallel, the inner two spread apart toward one end',
            'The drop is between the inner bars; the wider it gets, the easier the box drops',
            'The outer parallel bars catch the box ends, so it will not drop at the narrow side',
            'The box usually starts at the narrow side or in the middle',
          ],
        ),
        howTo: list(
          [
            '안쪽 두 봉이 어느 쪽으로 벌어지는지 먼저 확인합니다. 그쪽이 상자를 보낼 방향입니다.',
            '상자의 좁은 쪽 끝에 한쪽 집게발을 걸고, 집게가 닫히는 힘으로 상자를 넓은 쪽으로 밀어 옮깁니다.',
            '좌우를 번갈아 걸어 상자가 비뚤어지지 않게 조금씩 끌어당깁니다.',
            '안쪽 틈이 상자 폭에 가까워지면 상자가 기울기 시작합니다. 올라간 쪽 끝을 걸어 더 기울입니다.',
            '한쪽이 틈으로 빠져 비스듬히 걸리면 위쪽 끝을 눌러 떨어뜨립니다.',
            '집게 힘이 세면 좁은 쪽 끝을 들어 넓은 쪽으로 옮기는 들어 올리기도 됩니다.',
          ],
          [
            '内側の2本がどちらへ広がるかをまず確認。そちらが箱を運ぶ方向。',
            '箱の狭い側の端に片方の爪を掛け、閉じる力で箱を広い側へ押し出す（ずらし）。',
            '左右交互に掛け、箱が斜めにならないよう少しずつ運ぶ（寄せ）。',
            '内側の隙間が箱の幅に近づくと箱が傾き始める。上がった側の端を掛けてさらに傾ける。',
            '片側が隙間に落ちて斜めに引っ掛かったら、上の端を押して落とす。',
            'アームが強ければ、狭い側の端を持ち上げて広い側へ運ぶ持ち上げも使える。',
          ],
          [
            'First see which way the inner bars spread; that is where the box has to go.',
            'Hook one tip on the box end at the narrow side and let the closing push shove it toward the wide end (ずらし).',
            'Alternate sides so it moves straight, a little at a time (寄せ).',
            'As the inner gap nears the box width the box starts to tilt; hook the raised end to tilt it more.',
            'When one side has dropped into the gap and it hangs at an angle, press the upper end down.',
            'With a strong arm, lifting the narrow-side end and carrying it toward the wide end (持ち上げ) also works.',
          ],
        ),
        techniques: const [Technique.zurashi, Technique.yose, Technique.tateHame, Technique.mochiage],
        tips: list(
          [
            '바깥 평행 봉은 상자가 도는 것을 막습니다. 상자가 비뚤어지면 끝이 바깥 봉에 걸려 멈춥니다.',
            '넓은 쪽으로 갈수록 한 판에 움직이는 양이 커집니다. 마지막 몇 판은 조금씩 조절하세요.',
            '안쪽 봉이 조금만 벌어져 있다면 평행한 봉 2개일 때처럼 세워서 떨어뜨리는 편이 빠를 수 있습니다.',
          ],
          [
            '外側の平行バーは箱の回転を妨げる。斜めになると端が外側のバーに引っ掛かって止まる。',
            '広い側へ行くほど一手の移動量が大きくなる。最後の数手は小さく調整する。',
            '内側の広がりが小さければ、平行の橋渡しのように縦ハメで攻めた方が早いこともある。',
          ],
          [
            'The outer parallel bars keep the box from turning; if it goes crooked an end snags on an outer bar and stops.',
            'The nearer the wide end, the more each play moves it; keep the last few plays small.',
            'If the inner bars barely spread, treating it like a parallel bridge (縦ハメ) may be faster.',
          ],
        ),
        abortWhen: list(
          [
            '상자 끝이 바깥 봉에 걸려 3판 연속 움직이지 않음',
            '상자가 넓은 쪽으로 가지 않고 좁은 쪽으로 되돌아감',
          ],
          [
            '箱の端が外側のバーに引っ掛かり、3手続けて動かない',
            '箱が広い側へ進まず、狭い側へ戻ってしまう',
          ],
          [
            'A box end snags on an outer bar and the box does not move for three plays',
            'The box keeps sliding back to the narrow side instead of toward the wide end',
          ],
        ),
        typicalCost: t(
          '1,000~3,000엔 정도로 추정 ★',
          '1,000〜3,000円ほどと推定 ★',
          'Estimated ¥1,000–3,000 ★',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.frontDrop:
      return LayoutGuide(
        type: type,
        summary: t(
          '평평한 단 위에 상자가 있고 출구가 플레이어 쪽(앞쪽)에 있는 배치입니다. 반대쪽 집게로 끌어당겨 상자를 앞으로 옮깁니다.',
          '箱が平らな台の上にあり、落とし口が手前にある前落とし。反対側のアームで寄せて手前へ運びます。',
          'The box sits on a flat shelf with the drop hole toward the player (前落とし). Pull it forward (寄せ) with the far-side arm.',
        ),
        recognize: list(
          [
            '상자가 봉 없이 평평한 단이나 판 위에 놓여 있음',
            '출구가 기계 앞쪽(플레이어 쪽)에 있음',
            '상자와 출구 사이의 남은 거리가 보임',
          ],
          [
            '箱がバーなしで平らな台・板の上に置かれている',
            '落とし口がフィールドの手前（プレイヤー側）にある',
            '箱と落とし口の間に残り距離が見える',
          ],
          [
            'The box rests on a flat shelf or board, no bars',
            'The drop hole is at the front of the field, on the player\'s side',
            'You can see how much distance remains between the box and the hole',
          ],
        ),
        howTo: list(
          [
            '옮기고 싶은 방향의 반대쪽 집게를 씁니다. 왼쪽으로 끌고 싶으면 오른쪽 집게발을 상자 왼쪽 끝 뒤에 걸어, 집게가 닫히는 힘으로 끌어당깁니다.',
            '왼쪽→오른쪽→왼쪽으로 번갈아 걸어 상자를 지그재그로 앞으로 옮깁니다.',
            '경품의 가벼운 쪽(보통 아래쪽 절반이나 발 쪽)을 노리면 한 번에 많이 움직입니다.',
            '상자 앞부분이 출구 위로 충분히 튀어나올 때까지 서두르지 말고 옮깁니다.',
            '충분히 나왔으면 튀어나온 부분을 집게 몸체로 누르거나, 뒤쪽 모서리를 들어 올려 넘어뜨립니다.',
          ],
          [
            '狙う側と反対のアームを使う: 左へ寄せたいなら右アームの爪を箱の左端の奥に掛け、閉じる動作で引き寄せる（寄せ）。',
            '左→右→左と交互に掛けて、箱をジグザグに手前へ運ぶ。',
            '景品の軽い側（たいてい下半身・足側）を狙うと一度に動く量が大きい。',
            '箱の手前側が落とし口の上に十分はみ出すまで、焦らず運ぶ。',
            '十分来たら、はみ出した部分をアーム本体で押す、または奥の角を持ち上げて倒す。',
          ],
          [
            'Use the arm on the opposite side from where you want to pull: to draw the left end forward, hook the right arm\'s tip behind the left end and let the closing motion pull it (寄せ).',
            'Alternate left, right, left to zigzag the box forward.',
            'Aiming at the light side of the prize (usually the lower half or feet) moves it farther per play.',
            'Keep walking it forward, without rushing, until the front overhangs the hole enough.',
            'Then push the overhang with the claw body (押す) or lift a back corner (持ち上げ) to topple it in.',
          ],
        ),
        techniques: const [Technique.yose, Technique.oshikomi, Technique.mochiage],
        tips: list(
          [
            '너무 일찍 밀면 판만 낭비합니다. 쓸데없는 판을 줄이는 것이 핵심입니다.',
            '집게발이 걸릴 만큼 상자 끝을 깊게 노리세요. 가운데를 잡으면 움직이지 않습니다.',
          ],
          [
            '早く押しすぎるとプレイの無駄。「無駄なプレイを減らす」のが核心。',
            '爪が掛かる程度に箱の端を深めに狙う。中央をつかんでも動かない。',
          ],
          [
            'Pushing too early just wastes plays; the whole game is cutting wasted plays.',
            'Aim deep enough at the end for the tip to catch; grabbing the middle moves nothing.',
          ],
        ),
        abortWhen: list(
          ['3판 연속 전혀 움직이지 않음 (집게 힘 부족)', '상자가 벽이나 구조물에 걸려 앞으로 오지 않음'],
          ['3手続けて全く動かない（アームパワー不足）', '箱が壁・構造物に引っ掛かって手前へ来ない'],
          ['Three plays in a row with no movement (arm too weak)', 'The box is caught on a wall or fixture and cannot come forward'],
        ),
        typicalCost: t(
          '거리에 따라 500~2,000엔 ★ 참고값',
          '距離次第で500〜2,000円 ★ コミュニティの参考値',
          '¥500–2,000 depending on the distance ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.valleyDrop:
      return LayoutGuide(
        type: type,
        summary: t(
          'V자로 만나는 경사판 두 개 사이의 틈이 출구인 배치입니다. 상자를 한쪽 경사면에 올린 뒤 밀거나 찔러서 틈으로 넣습니다.',
          'V字に合わさる2枚の斜面の隙間が落とし口の谷落とし。片方の斜面に乗せてから押す・突きます。',
          'Two sloped boards meet in a V and the gap between them is the drop (谷落とし). Rest the box on one slope, then push or poke it in.',
        ),
        recognize: list(
          ['경사판 두 개가 V자로 만나고, 그 사이 틈이 출구', '상자가 경사판 위나 골에 걸쳐 있음', '경사가 있어 상자가 저절로 미끄러질 수 있음'],
          ['2枚の斜面がV字に合わさり、その隙間が落とし口', '箱が斜面の上または谷に掛かっている', '傾斜があり箱が自分で滑ることがある'],
          [
            'Two sloped boards meet in a V; the gap at the bottom is the drop hole',
            'The box lies on a slope or straddles the valley',
            'Because of the slope the box can slide on its own',
          ],
        ),
        howTo: list(
          [
            '먼저 상자 방향을 잡습니다. 한쪽 집게로 끝을 걸어, 긴 변이 골을 향하도록 세로로 돌립니다.',
            '경사면에 올리기: 안쪽 끝을 들어 한쪽 경사면 위로 미끄러뜨려 올립니다.',
            '올라간 뒤에는 안쪽을 들어 올리거나 앞 모서리를 찔러서 틈으로 미끄러지게 합니다.',
            '한 번에 넣으려 하지 말고 경사를 이용해 조금씩 골 쪽으로 보냅니다.',
            '상자가 골에 가로로 완전히 끼는 자세는 꼭 피합니다. 한번 끼면 더는 움직이지 않습니다.',
          ],
          [
            'まず箱の向きを決める: 片方のアームで端を掛け、縦（長辺が谷を向く）に回す。',
            '乗り上げ: 奥の端を持ち上げて片方の斜面へ滑らせて乗せる。',
            '乗ったら奥を持ち上げる、または手前の角を突いて隙間へ滑らせる。',
            '一度に入れようとせず、傾斜を使って少しずつ谷へ送る。',
            '横向きで谷に完全に嵌まる姿勢は必ず避ける（詰み）。',
          ],
          [
            'Set the orientation first: hook an end with one arm and turn the box lengthwise so its long side points into the valley.',
            'Ride it up (乗り上げ): lift the back end and slide it onto one slope.',
            'Once it rests there, lift the back (持ち上げ) or poke the front corner (突き) so it slides toward the gap.',
            'Do not try to sink it in one play; let the slope carry it a little at a time.',
            'Never let it wedge sideways across the valley (詰み).',
          ],
        ),
        techniques: const [Technique.noriage, Technique.tsuki, Technique.oshikomi],
        tips: list(
          ['방식 자체는 단순하지만 기계 설정에 따라 차이가 큽니다.', '경사는 내 편입니다. 무게중심이 틈 쪽으로 넘어가면 저절로 떨어집니다.'],
          ['パターン自体は単純だが設定差が大きい。', '傾斜は味方。重心が隙間側へ越えれば自分で落ちる。'],
          [
            'The pattern is simple but settings vary a lot.',
            'The slope is on your side: once the centre of mass crosses the gap, gravity finishes the job.',
          ],
        ),
        abortWhen: list(
          ['상자가 골에 가로로 완전히 끼어 움직이지 않음(끼임) → 처음 위치로 돌려 달라고 요청', '3판 연속 경사면에 올라가지 않음'],
          ['箱が谷に横向きで完全に嵌まって動かない（詰み）→ 初期位置を依頼', '3手続けて乗り上がらない'],
          ['The box is wedged sideways in the valley and will not move (詰み): ask for a reset', 'Three plays without getting it onto a slope'],
        ),
        typicalCost: t(
          '설정에 따라 1,000~3,000엔 ★ 참고값',
          '設定次第で1,000〜3,000円 ★ コミュニティの参考値',
          '¥1,000–3,000 depending on the setting ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.sideDrop:
      return LayoutGuide(
        type: type,
        summary: t(
          '출구가 기계 왼쪽이나 오른쪽 옆에 있는 배치입니다. 앞으로 떨어뜨리는 배치와 같은 원리로 옆으로 끌어당깁니다.',
          '落とし口がフィールドの左右側面にある横落とし。前落としと同じ原理で横へ寄せます。',
          'The drop hole is on the left or right side of the field (横落とし). Same idea as the front drop, pulling sideways instead.',
        ),
        recognize: list(
          ['출구가 기계 안 왼쪽 또는 오른쪽 가장자리에 있음', '상자가 평평한 단 위에 놓여 있음', '출구까지의 옆 방향 거리가 보임'],
          ['落とし口がフィールドの左または右の端', '箱が平らな台の上に置かれている', '落とし口までの横方向の距離が見える'],
          ['The drop hole is at the left or right edge of the field', 'The box sits on a flat shelf', 'You can see the sideways distance to the hole'],
        ),
        howTo: list(
          [
            '출구에서 먼 쪽 끝을 노립니다. 출구가 왼쪽이면 상자 오른쪽 끝의 앞·뒤 모서리를 번갈아 걸어 끌어당깁니다.',
            '앞 모서리는 왼쪽 집게, 안쪽 모서리는 오른쪽 집게처럼, 집게발이 상자 바깥에서 안쪽으로 닫히도록 집게를 고릅니다.',
            '가벼운 쪽을 노리면 크게 돌아서 한 번에 많이 옵니다.',
            '상자가 출구 위로 충분히 나오면 집게 몸체나 집게발로 눌러 떨어뜨립니다.',
            '옆 벽에 닿기 전에 각도를 조금씩 바로잡으며 옮깁니다.',
          ],
          [
            '落とし口から遠い側の端を狙う: 落とし口が左なら右端の手前・奥の角を交互に掛けて寄せる。',
            '手前の角は左アーム、奥の角は右アームのように、爪が箱の外から内へ閉じるようにアームを選ぶ。',
            '軽い側を狙うと回転が大きく、一度にたくさん動く。',
            '箱が落とし口の上に十分出たら、アーム本体や爪で押して落とす。',
            '側面の壁に当たる前に角度を少しずつ補正しながら運ぶ。',
          ],
          [
            'Aim at the end farthest from the hole: if the hole is on the left, alternate the front and back corners of the right end and pull (寄せ).',
            'Choose the arm so its tip closes from outside the box inward: left arm for the front corner, right arm for the back corner, and so on.',
            'Aiming at the light side gives more rotation and more travel per play.',
            'When enough of the box overhangs the hole, push it in (押し) with the claw body or a tip.',
            'Correct the angle a little each play so it does not jam against the side wall.',
          ],
        ),
        techniques: const [Technique.yose, Technique.oshikomi],
        tips: list(
          ['온라인 인형뽑기에서 초보자용으로 자주 나오는 배치입니다.', '옆 벽에 붙으면 돌릴 여유가 없어지니, 벽에서 떨어진 채로 옮기세요.'],
          ['オンクレで初心者向けによく使われる設定。', '横の壁に付くと回転の余裕がなくなるので、壁から離したまま運ぶ。'],
          [
            'A common beginner-friendly setup in online crane games (オンクレ).',
            'Once the box touches the side wall it can no longer rotate, so keep it off the wall while moving.',
          ],
        ),
        abortWhen: list(
          ['3판 연속 움직이지 않음', '상자가 옆 벽에 나란히 붙어 밀리지 않음'],
          ['3手続けて動かない', '箱が側面の壁に平行に張り付いて押せない'],
          ['Three plays in a row without movement', 'The box is flat against the side wall and will not slide'],
        ),
        typicalCost: t('500~2,000엔 ★ 참고값', '500〜2,000円 ★ コミュニティの参考値', '¥500–2,000 ★ community reference'),
      );

    // -------------------------------------------------------------------------
    case LayoutType.ringPera:
      return LayoutGuide(
        type: type,
        summary: t(
          '얇은 종이·플라스틱 고리에 집게발을 넣어 끌어올리는 배치입니다. 구멍이 보기보다 작으니 첫 판은 집게가 벌어지는 폭을 확인하는 데 씁니다.',
          '薄い紙・プラスチックの輪（ペラ輪）に爪を入れて引き上げる設定。穴は見た目より小さく、1手目は開き幅の確認用です。',
          'A thin paper or plastic ring (ペラ輪) on the prize that a tip must enter to lift it. The hole is smaller than it looks; play 1 is for measuring the claw spread.',
        ),
        recognize: list(
          ['경품에 얇은 종이·플라스틱 고리가 달려 있음', '고리 구멍에 집게발을 넣어 끌어올리는 구조', '경사대 위에 놓여 있는 경우가 많음'],
          ['景品に薄い紙・プラスチックの輪（ペラ輪）が付いている', '輪の穴に爪を入れて引き上げる構造', 'よく坂（斜面台）の上に置かれている'],
          ['A thin paper or plastic ring (ペラ輪) is attached to the prize', 'The idea is to put a tip through the ring and lift', 'Often placed on a ramp (坂)'],
        ),
        howTo: list(
          [
            '첫 판은 버리는 판으로 생각하고, 집게가 벌어졌을 때 집게발이 어디에 내려오는지 봅니다.',
            '두 번째 판부터는 한쪽 집게발이 고리 구멍 바로 위에 오도록 집게 중심을 옮깁니다. 구멍이 보기보다 작으니 정확하게 맞추세요.',
            '집게발이 구멍에 들어가면 집게가 닫히고 올라가면서 고리가 걸려 경품이 끌려 올라옵니다.',
            '들어가지 않고 움직이지도 않으면 고리를 살짝 끌어당기는 각도로 조준해 보세요. 갑자기 걸리기도 합니다.',
            '걸리기 시작하면 출구 쪽으로 옮겨질 때까지 같은 곳을 반복해서 노립니다.',
          ],
          [
            '1手目は捨てゲーと考え、アームが開いたとき爪がどこに降りるか観察する。',
            '2手目から輪の穴の真上に片方の爪が来るようアーム中心をずらす。穴は見た目より小さいので精密に。',
            '爪が穴に入れば、閉じ・上昇で輪が掛かり景品が引き上げられる。',
            '入らず動かないときは、少し寄せ気味（輪をやや引く角度）に狙うと急に掛かることがある。',
            '掛かった後は落とし口側へ運ばれるまで同じ位置を繰り返す。',
          ],
          [
            'Treat play 1 as a throwaway (捨てゲー): watch exactly where each tip lands when the claw opens.',
            'From play 2, move the claw centre so one tip comes down right over the ring hole. The hole is smaller than it looks, so be precise.',
            'If the tip enters the hole, the closing and rising motion catches the ring and drags the prize up.',
            'If it will not go in and nothing moves, aim with a slight pull (寄せ) angle on the ring; it sometimes catches suddenly.',
            'Once it catches, repeat the same spot until the prize is carried to the drop.',
          ],
        ),
        techniques: const [Technique.hikkake, Technique.yose],
        tips: list(
          ['구멍이 작은 기계는 피하는 것이 좋습니다.', '집게발 두께와 고리 구멍 크기를 먼저 비교하세요.'],
          ['穴の小さい台は回避が推奨。', '爪の太さと輪の穴の大きさを先に比べる。'],
          ['Skip machines with tiny ring holes.', 'Compare the tip thickness with the ring hole before you start.'],
        ),
        abortWhen: list(
          ['집게발이 구멍보다 굵어서 아예 들어가지 않음', '3판 연속 고리를 스치기만 함'],
          ['爪が穴より太くて物理的に入らない', '3手続けて輪をかすめるだけ'],
          ['The tip is thicker than the hole and physically cannot enter', 'Three plays in a row that only brush the ring'],
        ),
        typicalCost: t(
          '폭 확인용 첫 판 + 1,000엔 안팎 ★ 참고값',
          '開き幅確認の1手＋1,000円前後 ★ コミュニティの参考値',
          'One measuring play plus about ¥1,000 ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.ringD:
      return LayoutGuide(
        type: type,
        summary: t(
          '금속 D링·O링으로 봉에 걸린 경품입니다. 링 가운데가 아니라 바깥쪽을 좌우 번갈아 노려, 집게가 닫히는 힘으로 옮깁니다.',
          '金属のD環・Oリングが棒に掛かった設定。リングの中心ではなく外側を左右交互に狙い、閉じる動作で動かします。',
          'A metal D-ring or O-ring (D環 / Oリング) hangs on a rod. Aim at the outside of the ring, alternating sides, and let the closing motion move it.',
        ),
        recognize: list(
          ['경품에 D자·O자 금속 링이 달려 봉에 걸려 있음', 'O링은 직원이 위치를 옮길 수 있어서 링 위치가 기계마다 다름', '링 구멍 크기와 봉 굵기가 핵심'],
          ['景品にD字・O字の金属リングが付いて棒に掛かっている', 'Oリングは店員が位置を動かせるためリング位置はまちまち', 'リングの穴の大きさと棒の太さが鍵'],
          [
            'A D- or O-shaped metal ring on the prize hangs from a rod (棒)',
            'O-rings can be repositioned by staff, so ring positions vary',
            'The ring hole size and rod thickness are what matter',
          ],
        ),
        howTo: list(
          [
            '첫 판으로 집게 힘을 확인합니다. 링이 떨리기만 한다면 힘이 부족한 것입니다.',
            '링 가운데가 아니라 링 바깥쪽 가장자리를 노립니다. 집게발이 닫히면서 링을 출구 쪽으로 밀어내도록 합니다.',
            '왼쪽·오른쪽을 번갈아 걸어 링과 경품을 봉 끝(출구 쪽)으로 조금씩 옮깁니다.',
            '들어 올리려 하지 말고, 집게가 닫히는 동작으로 옮긴다고 생각하세요.',
            '경품이 봉에 세로로 매달려 불안정해지면 링 가운데를 뒤에서 밀어 넘깁니다.',
          ],
          [
            '1手目でアームパワーを確認。リングが震えるだけならパワー不足。',
            'リングの中心ではなく外側の縁を狙う。爪が閉じながらリングを落とし口側へ押し出すように。',
            '左右交互に掛けて、リングと景品を棒の端（落とし口）へ少しずつ運ぶ（リング寄せ）。',
            '持ち上げようとせず、「アームが閉じる動作」で動かす意識を保つ。',
            '景品が棒に対して縦になって不安定になったら、リングの中心を奥から押して落とす。',
          ],
          [
            'Use play 1 to check arm power: if the ring only shivers, the arm is too weak.',
            'Aim at the outer edge of the ring, not its centre, so the closing tips shove the ring toward the drop.',
            'Alternate left and right to walk the ring and prize along the rod toward the end (リング寄せ).',
            'Do not try to lift; keep thinking "the closing motion moves it".',
            'When the prize hangs lengthwise and unstable on the rod, push the ring centre from behind (押し) to tip it off.',
          ],
        ),
        techniques: const [Technique.yose, Technique.oshikomi],
        tips: list(
          ['집게 힘 확인이 가장 먼저입니다.', '링이 봉에 걸린 각도가 바뀌면 옮길 방향도 바뀝니다. 사진을 다시 찍어 확인하세요.'],
          ['アームパワーの確認が最優先。', 'リングが棒に掛かる角度が変わると進む方向も変わる。写真を撮り直して確認する。'],
          ['Checking arm power comes first.', 'If the ring\'s angle on the rod changes, its travel direction changes too; re-shoot and re-check.'],
        ),
        abortWhen: list(
          ['링이 떨리기만 하고 자리를 옮기지 않음 → 바로 그만두기', '경품이 봉에 걸린 채 링만 돌아감'],
          ['リングが震えるだけで位置が変わらない → 即撤退', '景品が棒に引っ掛かってリングだけ回る'],
          ['The ring only shivers without changing position: walk away now', 'The prize is snagged on the rod and only the ring turns'],
        ),
        typicalCost: t(
          '집게 힘이 충분하면 500~1,500엔, 아니면 바로 그만두기 ★ 참고값',
          'パワーが合えば500〜1,500円、合わなければ即撤退 ★ コミュニティの参考値',
          '¥500–1,500 when the arm is strong enough; otherwise leave immediately ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.hangString:
      return LayoutGuide(
        type: type,
        summary: t(
          '경품이 끈 고리로 봉에 매달린 배치입니다. 끈은 금속 링보다 부드럽고 잘 미끄러지지 않으니, 고리를 봉 끝 쪽으로 조금씩 밀거나 집게발을 고리에 넣어 봉 끝으로 넘깁니다.',
          '景品が紐の輪で棒に吊られた設定（紐吊り）。紐は金属のD環より柔らかく滑りにくいので、輪を棒の先へ少しずつ押すか、爪を輪に入れて棒の先から外す。',
          'The prize hangs from a rod by a string loop (紐吊り). A string is softer than a metal D-ring and slides less, so push the loop toward the rod tip a little at a time, or put a tip into the loop and take it off the end.',
        ),
        recognize: list(
          [
            '경품(상자·인형)에 달린 끈이나 고리가 봉에 걸려 매달려 있음',
            '봉은 한쪽 끝이 벽에 고정되어 있고, 다른 끝(보통 출구 쪽)은 비어 있음',
            '금속 링이 아니라 끈·리본이라 휘어지고 봉에 감기기도 함',
            '봉 끝에 걸림 돌기나 턱이 있으면 그 너머로 넘겨야 함',
          ],
          [
            '景品（箱・ぬいぐるみ）に付いた紐や輪が棒に掛かって吊られている',
            '棒は片端が壁に固定され、もう片端（多くは落とし口側）が空いている',
            '金属リング（D環）ではなく紐・リボンなので、曲がったり棒に巻き付いたりする',
            '棒の先に止めの突起や段があれば、それを越えさせる必要がある',
          ],
          [
            'A string or loop on the prize (box or plush) hangs over a rod',
            'The rod is fixed to the wall at one end; the other end (usually over the drop) is free',
            'It is a string or ribbon, not a metal ring (D環), so it bends and can wrap around the rod',
            'If the rod tip has a stopper bump or step, the loop has to be lifted over it',
          ],
        ),
        howTo: list(
          [
            '첫 판으로 집게 힘과 끈이 얼마나 미끄러지는지 확인합니다. 끈만 흔들린다면 힘이 부족한 것입니다.',
            '끈 고리의 벽 쪽 부분에 집게발을 걸어, 집게가 닫히는 힘으로 고리를 봉 끝 쪽으로 밉니다.',
            '좌우를 번갈아 걸어 고리와 경품을 봉 끝까지 조금씩 옮깁니다.',
            '고리가 봉 끝 가까이 오면 집게발 끝을 고리 안에 넣고 들어 올려, 봉 끝이나 돌기 너머로 넘깁니다.',
            '끈이 봉에 감기거나 꼬이면 반대 방향으로 한 번 걸어 풀어 줍니다.',
          ],
          [
            '1手目でアームパワーと紐の滑り具合を確認。紐が揺れるだけならパワー不足。',
            '紐の輪の壁側を爪で掛け、閉じる力で輪を棒の先へ押す（寄せ）。',
            '左右交互に掛け、輪と景品を棒の先まで少しずつ運ぶ。',
            '輪が棒の先に近づいたら、爪の先を輪に入れて持ち上げ、棒の先や止めの突起を越えさせる（引っ掛け）。',
            '紐が棒に巻き付いたりねじれたりしたら、逆向きに一度掛けてほどく。',
          ],
          [
            'Use play 1 to check the arm power and how easily the string slides; if the string only sways, the arm is too weak.',
            'Hook the wall side of the loop with a tip and let the closing motion push the loop toward the rod tip (寄せ).',
            'Alternate sides to walk the loop and prize to the end of the rod.',
            'Near the end, put a tip inside the loop and lift it over the rod tip or the stopper (引っ掛け).',
            'If the string wraps or twists around the rod, hook it once the other way to undo it.',
          ],
        ),
        techniques: const [Technique.yose, Technique.hikkake],
        tips: list(
          [
            '끈은 금속 링보다 마찰이 커서 한 판에 움직이는 양이 작습니다. 서두르지 마세요.',
            '경품이 무거울수록 끈이 봉에 눌려 잘 미끄러지지 않습니다.',
            '고리가 크면 집게발을 넣기 쉽고, 작으면 미는 쪽으로 갑니다.',
          ],
          [
            '紐は金属リングより摩擦が大きく、一手の移動量が小さい。焦らない。',
            '景品が重いほど紐が棒に押し付けられて滑りにくい。',
            '輪が大きければ爪を入れやすく、小さければ押し中心で攻める。',
          ],
          [
            'A string has more friction than a metal ring, so each play moves it less; do not rush.',
            'The heavier the prize, the harder the string presses on the rod and the less it slides.',
            'A big loop is easy to get a tip into; with a small loop, rely on pushing.',
          ],
        ),
        abortWhen: list(
          [
            '끈이 흔들리기만 하고 고리가 움직이지 않음 → 바로 그만두기',
            '끈이 봉에 감겨 풀리지 않음 → 직원에게 요청',
          ],
          [
            '紐が揺れるだけで輪が動かない → 即撤退',
            '紐が棒に巻き付いてほどけない → 店員に依頼',
          ],
          [
            'The string only sways and the loop does not move: walk away now',
            'The string has wrapped around the rod and will not come loose: ask the staff',
          ],
        ),
        typicalCost: t(
          '집게 힘이 충분하면 500~2,000엔 정도로 추정, 아니면 바로 그만두기 ★',
          'パワーが合えば500〜2,000円ほどと推定、合わなければ即撤退 ★',
          'Estimated ¥500–2,000 when the arm is strong enough; otherwise leave immediately ★',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.hookS:
      return LayoutGuide(
        type: type,
        summary: t(
          '집게 대신 체인에 달린 S자 고리로 링을 낚는 배치입니다. 고리를 흔들어 링에 걸어야 해서 운이 크게 작용합니다.',
          'アームの代わりにチェーン＋S字フックでリングを釣る設定。フックを揺らしてリングに落とす、運の要素が大きい台です。',
          'A chain with an S-hook replaces the claw and you fish for a ring (S字フック / 釣り). Swing the hook into the ring; luck plays a big part.',
        ),
        recognize: list(
          ['집게 대신 체인에 S자 고리가 매달려 있음', '노리는 대상은 그물·D링·O링처럼 걸 수 있는 링', 'S자 고리가 흔들리면서 내려감'],
          ['アームの代わりにチェーンにS字フックが吊られている', '対象は網・D環・Oリングなど掛けられる輪', 'フックが揺れながら降りる'],
          ['An S-shaped hook hangs from a chain instead of a claw', 'The target is a net, D-ring, O-ring or similar loop', 'The hook swings as it descends'],
        ),
        howTo: list(
          [
            '조작을 짧게 끊어서 S자 고리가 크게 흔들리게 합니다.',
            '방법 ①: 링 정면보다 살짝 앞~절반쯤을 조준해, 고리 끝을 링 안쪽에 넣고 안으로 미끄러뜨려 겁니다.',
            '방법 ②: 링이 흔들렸다가 돌아오는 방향을 읽고, 바깥에서 걸리도록 타이밍을 맞춥니다.',
            '걸리면 올라가거나 옮겨지는 중에 빠지지 않도록 고리가 링 깊숙이 들어갔는지 확인합니다.',
            '걸리지 않으면 조준점을 조금씩 바꾸며 다시 해 봅니다.',
          ],
          [
            '操作時間を短く切ってフックを大きく揺らす。',
            '方法①: リング正面よりやや手前〜半分の位置を狙い、フックの先をリングの内側に入れて奥へ滑らせて掛ける。',
            '方法②: リングが揺れているとき、戻ってくる方向を読んで外側から掛かるようタイミングを合わせる。',
            '掛かったら上昇・移動中に外れないよう、フックがリングの奥まで入ったか確認する。',
            '掛からなければ狙いを少しずつ変えて繰り返す。',
          ],
          [
            'Tap the controls briefly so the hook swings wide.',
            'Method 1: aim slightly in front of the ring (up to halfway), drop the hook tip inside the ring and slide it in to catch.',
            'Method 2: read the ring\'s swing and time the hook to catch from outside as it comes back.',
            'Once hooked, make sure the hook sits deep in the ring so it does not slip during the lift.',
            'If it misses, nudge the aim point a little each play and repeat.',
          ],
        ),
        techniques: const [Technique.hikkake],
        tips: list(
          ['운이 크게 작용하지만, 흔들림을 잘 이용하면 확률을 높일 수 있습니다.', '몇 판까지 할지 정하고 시작하세요.'],
          ['運の要素が大きいが、揺れを使えば確率は上げられる。', '手数の上限を決めてから始める。'],
          ['Luck matters a lot, but using the swing improves your odds.', 'Decide on a play limit before you start.'],
        ),
        abortWhen: list(
          ['S자 고리가 링 구멍보다 커서 들어가지 않음', '정해 둔 판 수에 도달'],
          ['フックがリングより大きくて入らない', '決めた手数の上限に達した'],
          ['The hook is bigger than the ring and cannot enter', 'You have hit your play limit'],
        ),
        typicalCost: t(
          '운에 좌우되니 상한을 정해 두세요 (1,000~2,000엔) ★ 참고값',
          '運次第、上限を決めておく（1,000〜2,000円）★ コミュニティの参考値',
          'Luck-dependent; set a cap (¥1,000–2,000) ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.takoyaki:
      return LayoutGuide(
        type: type,
        summary: t(
          '탁구공 더미와 다코야키 판처럼 구멍이 뚫린 판이 있는 배치입니다. 높이 쌓인 곳의 공을 집어 당첨 구멍에 넣는 방식이라 운이 크게 작용합니다.',
          'ピンポン玉の山とたこ焼き型の穴板。高く積まれた所の玉をつかんで当たり穴に入れる、運の要素が大きい台。',
          'A heap of ping-pong balls and a takoyaki-style hole board (たこ焼き). Grab a ball from the tallest part of the pile and hope it lands in a winning hole.',
        ),
        recognize: list(
          ['탁구공 더미 + 구멍이 여러 개 뚫린 판', '당첨 구멍이 색이나 표시로 구분됨', '꽝 구멍 일부가 이미 채워져 있기도 함'],
          ['ピンポン玉の山＋穴がいくつも空いた板', '当たり穴が色・表示で区別されている', 'ハズレ穴の一部がすでに埋まっていることもある'],
          ['A pile of ping-pong balls plus a board with many holes', 'Winning holes are marked by colour or label', 'Some losing holes may already be filled'],
        ),
        howTo: list(
          [
            '공이 가장 높이 쌓인 곳을 노려, 집게가 공을 한 개 이상 집도록 합니다.',
            '꽝 구멍이 이미 채워져 있거나, 당첨 구멍에 들어가기 쉬운 배치의 기계를 고릅니다.',
            '집은 공은 판 위에서 튀다가 어딘가에 들어갑니다. 공을 떨어뜨리는 위치를 당첨 구멍 근처로 잡으세요.',
            '시간 단축형 기계는 남은 꽝 구멍 수를 보고 확률을 가늠합니다.',
          ],
          [
            '玉が一番高く積まれた所を狙い、アームが玉を1個以上つかむようにする。',
            'ハズレ穴がすでに埋まった板、当たり穴に入りやすい配置の台を選ぶ。',
            'つかんだ玉は板の上で跳ねてどこかに収まる。落とす位置を当たり穴の近くに。',
            '時短型は残りのハズレ穴の数で確率を見積もる。',
          ],
          [
            'Aim at the tallest part of the pile so the claw picks up at least one ball.',
            'Pick a machine where losing holes are already filled or the layout favours the winning holes.',
            'A picked ball bounces on the board before settling; release it near a winning hole.',
            'On time-saver (時短) boards, estimate the odds from how many losing holes remain.',
          ],
        ),
        techniques: const [Technique.otoshi],
        tips: list(
          ['실력보다 운입니다. 여러 판 할 생각으로 예산을 정하세요.', '공을 여러 개 집을수록 기회가 늘어납니다.'],
          ['実力より運。繰り返しプレイ前提で予算を決める。', '玉を複数つかめれば機会が増える。'],
          ['This is luck more than skill; budget for repeated plays.', 'Grabbing several balls at once gives more chances.'],
        ),
        abortWhen: list(
          ['공이 낮게 흩어져 집히지 않음', '정해 둔 예산에 도달'],
          ['玉が低く散らばってつかめない', '予算の上限に達した'],
          ['The balls are scattered too low to grab', 'You have reached your budget'],
        ),
        typicalCost: t(
          '운에 좌우되니 예산을 정해 두세요 ★ 참고값',
          '運次第、予算を決めておく ★ コミュニティの参考値',
          'Luck-dependent; set a budget first ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.threeClaw:
      return LayoutGuide(
        type: type,
        summary: t(
          '큰 세 발 집게로 인형을 집는 배치입니다. 대부분 확률형 기계라서, 확률 한도에 이르기 전에는 인형을 조금씩 옮기는 것만 효과가 있습니다.',
          '3本爪の大型ユニットでぬいぐるみを狙う設定。多くは確率機なので、天井前は物理的な移動だけが有効です。',
          'Large plush toys under a three-claw unit (3本爪). Most are payout-controlled (確率機), so before the threshold only physical movement counts.',
        ),
        recognize: list(
          ['집게발이 3개이고 집게 유닛이 큼', '넓은 진열장 안에 큰 인형', '기계 종류와 보조 램프 색이 확률형 기계인지 알려 주는 단서'],
          ['アームの爪が3本、UFOユニットが大きい', '広いショーケースに大型ぬいぐるみ', '機種・アシストランプの色が確率機かどうかのヒント'],
          ['The claw has three tips and the unit is large', 'Big plush toys in a wide showcase', 'The machine model and the assist-lamp colour hint at payout control'],
        ),
        howTo: list(
          [
            '세 집게발이 인형의 무게중심을 감싸도록 집게 중심을 맞춥니다.',
            '집게발이 인형 아래로 들어갔는지 확인합니다. 집게발 2개만 걸리면 무게를 버티지 못합니다.',
            '태그가 있으면 태그에 집게발을 거는 방법도 좋습니다.',
            '확률 한도에 이르기 전에는 확률은 신경 쓰지 말고, 끌어당기기·밀기로 인형을 출구 쪽으로 옮깁니다.',
            '가림막 벽에 걸리면 반대쪽을 들어 넘겨 떨어뜨립니다.',
            '집게발이 휘는 정도가 달라지거나 인형이 전보다 크게 움직이면 확률 한도가 가까워졌다는 신호일 수 있습니다.',
          ],
          [
            'ぬいぐるみの重心・バランス点を3本の爪が包むようにアーム中心を合わせる。',
            '爪がぬいぐるみの下に入ったか確認。2本しか掛からないと重さに耐えない。',
            'タグがあればタグに爪を掛けるタグ掛けも有効。',
            '天井前は確率を無視し、寄せ・押しで落とし口側へ物理的に運ぶ（確率無視）。',
            'シールド（壁）に掛かったら反対側を持ち上げて越えさせて落とす。',
            '爪のしなりが変わる、ぬいぐるみが前より大きく動く、は天井が近い合図。',
          ],
          [
            'Centre the claw so all three tips wrap around the plush\'s centre of mass.',
            'Check that the tips go under the plush; two tips alone cannot hold the weight.',
            'If there is a tag, hooking the tag (タグ掛け) also works.',
            'Before the threshold, ignore the odds and physically shove the plush toward the drop with pulls and pushes (確率無視).',
            'If it catches on a shield wall, lift the far side to tip it over.',
            'Signs the threshold is near: the tips flex differently, or the plush moves more than before.',
          ],
        ),
        techniques: const [Technique.mochiage, Technique.hikkake, Technique.yose, Technique.oshikomi],
        tips: list(
          [
            '확률 한도는 보통 1,000~7,000엔이며, 정가의 1.5~2배쯤이 기준입니다.',
            '보조 램프가 초록색이면 설정된 판 수를 넘겼다는 신호일 수 있습니다 (직원이 도와줄 수도 있음).',
            '확률형 기계인지는 어디까지나 추정입니다.',
          ],
          [
            '天井は普通1,000〜7,000円、小売価格の1.5〜2倍あたりが合図。',
            'アシストランプが緑なら設定回数超過の合図かも（店員アシストの可能性）。',
            '確率機かどうかの判定はあくまで推定。',
          ],
          [
            'The threshold (天井) is usually ¥1,000–7,000; around 1.5–2× retail price is a common sign.',
            'A green assist lamp may mean the set play count was exceeded (staff may assist).',
            'Whether it is payout-controlled is only an estimate.',
          ],
        ),
        abortWhen: list(
          ['끌어당기거나 밀어도 전혀 옮겨지지 않고, 집게가 매번 힘없이 벌어짐', '넣은 돈이 정해 둔 상한(정가의 2배)을 넘음'],
          ['寄せ・押しでも全く動かず、アームがいつも開く', '投入額が決めた上限（小売価格×2）を超えた'],
          ['Nothing moves even with pulls and pushes and the claw always opens', 'You have spent past your limit (about 2× retail)'],
        ),
        typicalCost: t(
          '인형 1개에 3,000~4,000엔 든 사례, 확률 한도 1,000~7,000엔 ★ 참고값',
          'ぬいぐるみ1個で3,000〜4,000円の例、天井1,000〜7,000円 ★ コミュニティの参考値',
          'Reports of ¥3,000–4,000 per plush; threshold ¥1,000–7,000 ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.twoClawDirect:
      return LayoutGuide(
        type: type,
        summary: t(
          '두 발 집게로 바닥이나 단 위의 인형을 바로 집는 배치입니다. 목·다리 사이·태그처럼 걸리는 부분을 노려 출구로 옮깁니다.',
          '2本爪アームで床・台の上のぬいぐるみを直接取る直取り。首・足の間・タグなど掛かる部位を狙って落とし口へ運びます。',
          'A two-claw arm grabs a plush lying directly on the floor or a shelf (2本爪 直取り). Hook a catchable part, such as the neck, between the legs or a tag, and walk it to the drop.',
        ),
        recognize: list(
          ['집게발이 2개이고, 인형이 바닥이나 단 위에 바로 놓여 있음', '봉·링 같은 보조 구조물이 없음', '실력형 기계일 가능성이 높아 몇 판이 들지 예상하기 쉬움'],
          ['2本爪アーム、ぬいぐるみが床・台に直接置かれている', 'バー・リングなどの補助構造がない', '実力機の可能性が高く手数を読みやすい'],
          ['Two-tip claw; the plush lies directly on the floor or a shelf', 'No bars, rings or other fixtures', 'Likely a skill machine (実力機), so plays are predictable'],
        ),
        howTo: list(
          [
            '걸릴 부분을 고릅니다: 목, 다리 사이, 팔과 몸통 사이, 태그.',
            '작은 인형은 태그를 노려 출구 쪽으로 끌어당깁니다.',
            '집게발 각도가 90°에 가까운 기계가 유리합니다. 첫 판에 집게발이 어디에 닿는지 보세요.',
            '다리를 들어 출구 쪽으로 넘어뜨리듯이 움직입니다.',
            '출구 가장자리까지 오면 튀어나온 부분을 걸어 떨어뜨립니다.',
          ],
          [
            '掛かる部位を選ぶ: 首、足の間、腕と胴の間、タグ。',
            '小型ならタグを狙って落とし口側へ寄せる。',
            '爪の角度が90°に近い台が有利。1手目で爪がどこに当たるか観察する。',
            '足を持ち上げて落とし口側へ倒すように動かす（持ち上げ）。',
            '落とし口の縁まで来たら、はみ出た部分を掛けて落とす。',
          ],
          [
            'Pick a catchable part: the neck, between the legs, between an arm and the body, or a tag.',
            'For small plushes, aim at the tag and pull (寄せ) toward the drop.',
            'Tips angled close to 90° work best; watch where they land on play 1.',
            'Lift the legs (持ち上げ) so the plush tips over toward the drop.',
            'At the edge of the drop, hook the overhanging part to finish.',
          ],
        ),
        techniques: const [Technique.hikkake, Technique.mochiage, Technique.yose],
        tips: list(
          ['무게중심을 잡으면 들리고, 아니면 돌기만 합니다. 도는 것도 진전입니다.', '틈에 집게발을 꽂아 거는 방법도 좋습니다.'],
          ['重心をつかめば上がり、外れれば回るだけ。回転も前進のうち。', '隙間に爪を差し込むスキマフックも有効。'],
          ['Catch the centre of mass and it lifts; miss it and it just rotates, which is still progress.', 'Jamming a tip into a gap (スキマフック) also works.'],
        ),
        abortWhen: list(
          ['3판 연속 집게발이 미끄러져 걸리지 않음', '인형이 벽 구석에 눌려 옮길 수 없음'],
          ['3手続けて爪が滑って掛からない', 'ぬいぐるみが壁の隅に押し付けられて動かせない'],
          ['Three plays in a row the tips slip off without catching', 'The plush is pressed into a corner and cannot be moved'],
        ),
        typicalCost: t(
          '실력형 기계라면 500~1,500엔 ★ 참고값',
          '実力機なら500〜1,500円 ★ コミュニティの参考値',
          '¥500–1,500 on a skill machine ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.pile:
      return LayoutGuide(
        type: type,
        summary: t(
          '작은 경품이 산처럼 쌓인 배치입니다. 끌어당기기·밀기·퍼 올리기로 산을 무너뜨려 한꺼번에 떨어뜨립니다.',
          '小型景品が山のように積まれた山積み。寄せる・押す・すくうで山を崩し（雪崩）、まとめて落とします。',
          'Small prizes heaped in a pile (山積み). Pull, push and scoop to trigger an avalanche (雪崩) that drops several at once.',
        ),
        recognize: list(
          ['작은 경품(마스코트 등) 여러 개가 산처럼 쌓여 있음', '출구가 산 한쪽 옆에 있음', '산이 어느 쪽으로 기울어 내려가는지 보임'],
          ['多数の小型景品（マスコットなど）が山のように積まれている', '落とし口が山の片側にある', '山の傾斜がどちらへ下がっているか見える'],
          ['Many small prizes (mascots etc.) piled into a mound', 'The drop hole is beside the pile', 'You can see which way the pile slopes down'],
        ),
        howTo: list(
          [
            '기본은 끌어당기기·밀기·퍼 올리기 세 가지입니다. 산에서 출구 쪽 경사면을 노립니다.',
            '집게가 올라갈 때 산이 무너지도록, 꼭대기나 출구 쪽 경사면의 경품을 집게발로 걸어 들어 올립니다.',
            '주변에 같은 높이의 경품이 있으면 경사가 내려가는 쪽으로 밉니다.',
            '아래에서 퍼 올려 여러 개를 한 번에 출구로 보냅니다.',
            '하나씩 노리기보다 산 전체의 균형을 무너뜨리는 것을 목표로 합니다.',
          ],
          [
            '基本は寄せる・押す・すくうの3つ。山の落とし口側の斜面を狙う。',
            'アーム上昇時に山が崩れるよう、山の頂上や落とし口側斜面の景品を爪で掛けて持ち上げる（雪崩を誘う）。',
            '周りに同じ高さの景品があれば、傾斜が下がる方向へ押す。',
            '下からすくうすくいで複数をまとめて落とし口へ送る。',
            '1個ずつより山全体のバランスを崩すことを目標にする。',
          ],
          [
            'The basics are pull, push and scoop. Aim at the slope facing the drop.',
            'Hook a prize on the top or the drop-side slope and lift so the pile collapses when the claw rises (trigger the 雪崩).',
            'When neighbours sit at the same height, push toward the downhill side.',
            'Scooping from underneath (すくい) sends several toward the drop at once.',
            'Aim to break the balance of the whole pile rather than taking one at a time.',
          ],
        ),
        techniques: const [Technique.nadare, Technique.yose, Technique.oshikomi],
        tips: list(
          ['쌓인 산은 언제든 무너질 수 있는 상태입니다. 어느 쪽으로 무너질지 먼저 읽으세요.', '한 번에 여러 개를 얻을 수도 있는 배치입니다.'],
          ['山は位置エネルギーの塊。崩れる方向を先に読む。', '大量獲得が可能な設定。'],
          ['The pile is stored potential energy; read which way it will collapse first.', 'This setup can yield several prizes.'],
        ),
        abortWhen: list(
          ['산이 낮고 평평해져 무너질 여지가 없음', '3판 연속 아무것도 움직이지 않음'],
          ['山が低く平らになって崩れる余地がない', '3手続けて何も動かない'],
          ['The pile has flattened out with nothing left to collapse', 'Three plays in a row without any movement'],
        ),
        typicalCost: t(
          '500~1,500엔에 여러 개를 얻은 사례 ★ 참고값',
          '500〜1,500円で複数獲得の例 ★ コミュニティの参考値',
          'Reports of several prizes for ¥500–1,500 ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.floorBox:
      return LayoutGuide(
        type: type,
        summary: t(
          '상자가 봉 없이 바닥이나 단 위에 바로 놓인 배치입니다. 집게발이 상자 옆 틈에 들어가게 맞추고, 큰 상자는 눕힌 뒤 모서리를 들어 올립니다.',
          '箱がバーなしで床・台に置かれた箱 直置き。爪の位置を箱の隙間に合わせ、大型は横ハメ後に角持ち上げ。',
          'A box placed directly on the floor or a shelf, no bars (箱 直置き). Match the tips to the gaps around the box; big boxes get turned flat then corner-lifted (角持ち上げ).',
        ),
        recognize: list(
          ['상자 경품이 봉 없이 바닥이나 단 위에 놓여 있음', '상자 주위에 집게발이 들어갈 틈이 있음', '출구는 앞이나 옆 등 어느 방향이든 될 수 있음'],
          ['箱型景品がバーなしで床・台に置かれている', '箱の周りに爪が入る隙間がある', '落とし口は手前・横などどの方向でもあり得る'],
          ['A box-shaped prize sits on the floor or a shelf without bars', 'There are gaps (すきま) around the box where a tip can enter', 'The drop can be in front, to the side or elsewhere'],
        ),
        howTo: list(
          [
            '집게가 벌어졌을 때 집게발이 상자 옆 틈에 정확히 들어가도록 집게 중심을 맞춥니다.',
            '무게중심을 가늠합니다. 잘 들리지 않는 쪽이 무거운 쪽입니다.',
            '작은 상자: 양쪽 집게발로 집어 들어 올리거나, 한쪽을 걸어 출구 쪽으로 끌어당깁니다.',
            '큰 상자: 먼저 눕혀서 떨어뜨릴 때처럼 상자를 눕혀 안정시킨 뒤, 내려앉은 모서리를 들어 올려 출구로 넘깁니다.',
            '출구 가장자리에 걸치면 튀어나온 모서리를 눌러 떨어뜨립니다.',
          ],
          [
            'アームが開いたとき、爪が箱の横の隙間に正確に入るようアーム中心を合わせる。',
            '重心を見極める: 浮かない側が重い側。',
            '小型の箱: 両爪でつかんで持ち上げる、または片側を掛けて落とし口側へ寄せる。',
            '大型の箱: まず横ハメのように箱を寝かせて安定させ、沈んだ角を持ち上げる角持ち上げで落とし口へ越えさせる。',
            '落とし口の縁に掛かったら、はみ出た角を押して落とす。',
          ],
          [
            'Line up the claw so the open tips drop precisely into the gaps beside the box.',
            'Find the centre of mass: the side that does not lift is the heavy side.',
            'Small box: grab and lift with both tips (持ち上げ), or hook one side and pull toward the drop (寄せ).',
            'Large box: first lay it flat and stable (like 横ハメ), then lift the sunken corner (角持ち上げ) to roll it toward the drop.',
            'Once it hangs over the edge, press the overhanging corner to drop it.',
          ],
        ),
        techniques: const [Technique.mochiage, Technique.yose, Technique.yokoHame, Technique.kadoOshi],
        tips: list(
          ['무게중심을 제대로 읽는 것이 가장 중요합니다.', '틈이 집게발 두께보다 좁으면 먼저 끌어당겨서 틈을 만드세요.'],
          ['重心の把握が成否を分ける。', '爪の太さより隙間が狭ければ、先に寄せで隙間を作る。'],
          ['Reading the centre of mass decides the outcome.', 'If the gap is narrower than the tip, make a gap first with a pull.'],
        ),
        abortWhen: list(
          ['상자가 벽에 딱 붙어 집게발이 들어갈 틈이 없음', '3판 연속 조금도 움직이지 않음'],
          ['箱が壁に密着して爪の入る隙間がない', '3手続けて微動だにしない'],
          ['The box is flush against a wall with no gap for a tip', 'Three plays in a row without the slightest movement'],
        ),
        typicalCost: t('1,000~2,500엔 ★ 참고값', '1,000〜2,500円 ★ コミュニティの参考値', '¥1,000–2,500 ★ community reference'),
      );

    // -------------------------------------------------------------------------
    case LayoutType.unknown:
      return LayoutGuide(
        type: type,
        summary: t(
          '사진만으로는 배치를 알아보지 못했습니다. 다른 각도에서 다시 촬영해 주세요.',
          '写真だけでは設置パターンを判別できませんでした（判別不可）。別の角度から撮り直してください。',
          'The layout could not be identified from this photo (判別不可). Please re-shoot from a different angle.',
        ),
        recognize: list(
          ['집게·봉·출구 중 하나 이상이 사진에 없음', '반사나 역광 때문에 경품 윤곽이 흐림', '비스듬한 각도라 봉 간격이나 높이를 알 수 없음'],
          ['アーム・バー・落とし口のいずれかが写っていない', '反射・逆光で景品の輪郭がぼやけている', '斜めの角度でバー間隔・高さが読めない'],
          ['The claw, the bars or the drop hole is missing from the photo', 'Reflections or backlight blur the prize outline', 'The angle is too oblique to read bar spacing or height'],
        ),
        howTo: list(
          [
            '유리에 바짝 대어 반사를 줄이고, 기계 정면에서 수평으로 다시 촬영합니다.',
            '집게·봉·출구가 한 장에 모두 들어오게 찍습니다.',
            '봉 높이 차이나 튜브 색이 보이도록 살짝 위에서 내려다본 사진을 한 장 더 찍습니다.',
            '그래도 알아보지 못하면 이 가이드 목록에서 눈으로 가장 비슷한 유형을 골라 참고하세요.',
          ],
          [
            'ガラスに密着して反射を減らし、筐体の正面から水平に撮り直す。',
            'アーム・バー・落とし口が1枚に全部入るようにする。',
            'バーの高さの差・チューブの色が見えるよう、少し上から見下ろす角度も追加する。',
            'それでも判別できなければ、このガイド一覧から目で一番近いパターンを選んで参考にする。',
          ],
          [
            'Hold the phone against the glass to cut reflections and re-shoot from the front, level.',
            'Get the claw (アーム), bars (バー) and drop hole into one frame.',
            'Add a slightly elevated angle so bar height differences and tube colours are visible.',
            'If it still cannot be identified, pick the closest-looking type from this guide list by eye.',
          ],
        ),
        techniques: const [],
        tips: list(
          ['사진은 1장이면 충분하지만, 정면에서 수평으로 찍는 것이 중요합니다.', '기다리는 사람이 있으면 촬영은 한 판 하는 동안 끝내세요.'],
          ['写真は1枚で十分だが、正面・水平が重要。', '待っている人がいれば撮影は1ゲーム以内で。'],
          ['One photo is enough, but it must be frontal and level.', 'If others are waiting, finish shooting within one game.'],
        ),
        abortWhen: list(
          ['다시 촬영해도 알아볼 수 없음', '매장에서 촬영을 금지함'],
          ['撮り直しても判別不可', '店舗が撮影を禁止している'],
          ['Still unidentified after re-shooting', 'The arcade does not allow photos'],
        ),
        typicalCost: t(
          '유형을 확인한 뒤 그 유형의 참고 비용을 보세요',
          '判別後に該当パターンの参考費用を確認してください',
          'Check the typical cost of the identified type after re-shooting',
        ),
      );
  }
}
