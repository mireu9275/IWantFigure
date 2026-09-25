/// Beginner guide for every [LayoutType] (기초 가이드): how to recognise the
/// setup in the cabinet, where to put the claw, which techniques apply, tips,
/// when to walk away and what it typically costs.
///
/// Written from docs/01_기획_기술_분석.md §3 and docs/research/domain.md §1–3, §7.
/// Japanese community terms are kept in parentheses (橋渡し, 縦ハメ, 寄せ …).
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

  /// Typical cost text, e.g. "숙련자 1,000~2,000엔 ★ 커뮤니티 참고치".
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
      LayoutType.frontDrop => Icons.arrow_downward,
      LayoutType.valleyDrop => Icons.landscape_outlined,
      LayoutType.sideDrop => Icons.arrow_forward,
      LayoutType.ringPera => Icons.label_outline,
      LayoutType.ringD => Icons.link,
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
          '박스 1개가 평행한 바 2개 위에 걸친 표준 세팅(橋渡し). 들어 올리지 말고 끝을 걸어 조금씩 돌려 떨어뜨립니다.',
          '箱1個が平行な2本のバーに掛かる標準設定（橋渡し）。持ち上げず、端に爪を掛けて少しずつ回して落とします。',
          'One box resting across two parallel bars (橋渡し), the standard figure-box setup. Do not lift it: hook an end and rotate it down bit by bit.',
        ),
        recognize: list(
          [
            '박스형 경품 1개가 서로 평행한 금속·고무 바 2개 위에 세로 또는 가로로 걸쳐 있음',
            '바 간격이 박스의 긴 변보다 좁고, 낙하구는 바 사이 아래',
            '초기 위치는 대개 살짝 안쪽(奥)으로 치우침',
            '바에 분홍·투명 튜브가 없음(있으면 段差/튜브형)',
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
            '먼저 무게를 가늠하세요: 무거운 박스는 縦ハメ(세로 끼우기), 가벼운 박스는 横ハメ(가로 끼우기)가 정석입니다.',
            '박스 중앙이 아니라 한쪽 아암의 발톱이 박스 끝에 아슬아슬하게 걸리는 지점(端ギリギリ)에 아암 중심을 맞춥니다.',
            '1수: 오른쪽 아암 발톱을 안쪽(奥) 끝 바로 안에 걸어 뒤쪽을 살짝 들어 올립니다. 박스가 앞 바를 축으로 기울면 성공입니다.',
            '2수: 왼쪽 아암으로 반대쪽 안쪽 모서리를 같은 방식으로 겁니다. 좌우를 번갈아 흔들며 조금씩 세웁니다.',
            '박스가 비스듬히 서면 뜨지 않는(무거운) 쪽을 피해 가벼운 쪽을 노려 회전을 키웁니다.',
            '마지막에는 바 사이로 빠질 때까지 세운 뒤, 남은 모서리(残存角)를 발톱으로 눌러 내려보냅니다.',
            '가벼운 박스라면 안쪽을 노린 뒤 반대 아암으로 오른쪽 앞을 걸어 가로로 만들어 떨어뜨립니다(横ハメ).',
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
            '아암 파워는 사진에 안 보입니다. 1수의 움직임 크기로 판단하세요.',
            '접촉점이 무게중심에서 멀수록 적은 힘으로 크게 돕니다. 그래서 끝(端)을 노립니다.',
            '뜨지 않는 쪽이 무거운 쪽입니다. 무거운 쪽을 아래로 세우면 縦ハメ가 쉬워집니다.',
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
            '박스가 가로로 두 바 위에 평평하게 얹혀 움직이지 않음(詰み) → 「初期位置に戻してください」 요청',
            '한쪽 발톱으로 끌어도, 안쪽·앞쪽을 들어도 3수 연속 전혀 움직이지 않음',
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
          '숙련자 1,000~2,000엔, 초심자 1,000~3,000엔 ★ 커뮤니티 참고치',
          '慣れた人 1,000〜2,000円、初心者 1,000〜3,000円 ★ コミュニティの参考値',
          '¥1,000–2,000 for experienced players, ¥1,000–3,000 for beginners ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.bridgeHanoji:
      return LayoutGuide(
        type: type,
        summary: t(
          '두 바가 한쪽으로 벌어지는 브릿지(末広がり / ハの字). 넓은 쪽으로 박스를 돌려 옮겨 빠지게 합니다.',
          '2本のバーが片側へ広がる橋渡し（末広がり / ハの字）。広い側へ箱を回して移動させ、抜けさせます。',
          'A bridge whose bars flare apart toward one end (末広がり / ハの字). Rotate and walk the box toward the wide end until it slips through.',
        ),
        recognize: list(
          [
            '두 바가 평행하지 않고 앞 또는 뒤로 갈수록 간격이 벌어짐',
            '넓은 쪽에서는 박스가 빠질 수 있을 만큼 틈이 큼',
            '박스는 보통 좁은 쪽에 걸쳐 놓여 시작',
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
            '먼저 아암 파워를 확인합니다. 1수에 박스가 거의 안 움직이면 세우기(縦ハメ)는 어렵다고 보고 옮기기 위주로 갑니다.',
            '넓은 쪽을 향해 박스를 돌립니다: 넓은 쪽과 먼 끝의 모서리에 한쪽 아암 발톱을 걸어 寄せ(끌어당기기)합니다.',
            '좌우 아암을 번갈아 쓰며 박스가 넓은 쪽으로 조금씩 이동·회전하게 합니다.',
            '아암이 강하거나 박스 속이 비어 가볍다면 つまみ上げ: 양 아암으로 박스를 집어 들어 넓은 쪽으로 옮깁니다.',
            '그렇지 않으면 乗り上げ: 양 아암으로 안쪽 모서리를 들어 한쪽 바 위에 얹어 균형을 깨뜨립니다.',
            '박스 폭보다 틈이 넓어지는 지점에 오면 안쪽 끝을 눌러 떨어뜨립니다.',
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
            '아암이 약하면 옆면을 아래로 세우는 일이 거의 없고 아주 조금씩만 어긋납니다. 회수를 각오하세요.',
            '평행형보다 보통 회수가 더 듭니다.',
            '넓은 쪽 방향을 사진에서 확실히 파악해 두세요.',
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
          ['3수 연속 밀리지도 돌지도 않음', '박스가 좁은 쪽에 가로로 꽉 껴 버림(詰み)'],
          ['3手続けてずれも回りもしない', '箱が狭い側に横向きでがっちり嵌まった（詰み）'],
          ['Three plays in a row with neither shift nor rotation', 'The box has jammed sideways at the narrow end (詰み)'],
        ),
        typicalCost: t(
          '매장 설정에 따라 다름, 대체로 평행형보다 회수 多 (2,000~4,000엔) ★ 커뮤니티 참고치',
          '店の設定次第、平行型より手数が多め（2,000〜4,000円）★ コミュニティの参考値',
          'Depends on the store setting; usually more than the parallel bridge (¥2,000–4,000) ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.bridgeStep:
      return LayoutGuide(
        type: type,
        summary: t(
          '바 높이가 다르거나(段差), X자로 교차하거나, 분홍·투명 튜브가 씌워진 브릿지. 마찰을 읽고 슬라이드와 들기를 골라 씁니다.',
          'バーの高さが違う（段差）、X字に交差する、またはピンク・透明チューブ付きの橋渡し。摩擦を読んで滑らせるか持ち上げるかを選びます。',
          'A bridge with bars at different heights (段差), crossed bars, or pink / clear tubing (ピンクチューブ). Read the friction and choose between sliding and lifting.',
        ),
        recognize: list(
          [
            '두 바의 높이가 다름(그림자·원근으로 판별)',
            '바가 X자로 교차함(クロス)',
            '바 가운데에 분홍·투명 고무 튜브가 씌워짐(색으로 즉시 판별)',
            '박스가 높은 바에 기대 비스듬히 놓인 경우가 많음',
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
            '段差(단차): 박스를 높은 바에 기대 세운 "真縦の斜めハマり" 상태를 먼저 만듭니다. 낮은 바 쪽 끝에 발톱을 걸어 끌어당깁니다.',
            '그 상태에서 ずり上げ: 박스 아래쪽 끝에 발톱을 걸고 높은 바 위로 미끄러뜨려 올립니다. 세로 자세일 때만 힘이 전달됩니다.',
            '튜브(ピンクチューブ)가 있으면 마찰이 매우 커서 미끄러지지 않습니다. 슬라이드 계열은 버리고 들기·회전으로 바꿉니다.',
            '튜브 없는 구간이 있으면 좌우 寄せ로 박스를 그쪽으로 먼저 옮깁니다.',
            '들기·회전: 양 아암으로 안쪽 모서리를 들어 바 위에 얹는 乗り上げ, 또는 한쪽 끝을 걸어 세우는 縦ハメ를 씁니다.',
            '교차형(クロス)은 교차점에서 먼 쪽(틈이 넓은 쪽)으로 박스를 돌려 옮깁니다.',
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
            '가로 상태에서 ずり上げ는 면적이 넓어 힘이 안 전달되어 실패하기 쉽습니다.',
            '튜브는 습기로 마찰이 더 세지고, 먼지·열화로 약해집니다(매장 관리에 따라 다름).',
            '"늪(沼)"이 되기 쉬운 세팅입니다. 회수 상한을 미리 정하세요.',
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
          ['2~3수 동안 전혀 미끄러지지도 들리지도 않음', '박스가 튜브 구간에 가로로 걸쳐 고정됨(詰み)'],
          ['2〜3手の間まったく滑りも持ち上がりもしない', '箱がチューブ区間に横向きで固定された（詰み）'],
          ['No slide and no lift at all for two or three plays', 'The box is pinned sideways on the tubed section (詰み)'],
        ),
        typicalCost: t(
          '설정 편차 큼. 움직이지 않으면 즉시 철수 (1,000~3,000엔 상한 권장) ★ 커뮤니티 참고치',
          '設定差が大きい。動かなければ即撤退（上限1,000〜3,000円を推奨）★ コミュニティの参考値',
          'Varies a lot by setting; walk away as soon as nothing moves (a ¥1,000–3,000 cap is sensible) ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.frontDrop:
      return LayoutGuide(
        type: type,
        summary: t(
          '박스가 평평한 단 위, 낙하구가 플레이어 쪽(手前)에 있는 前落とし. 반대쪽 아암으로 끌어당겨(寄せ) 앞으로 옮깁니다.',
          '箱が平らな台の上にあり、落とし口が手前にある前落とし。反対側のアームで寄せて手前へ運びます。',
          'The box sits on a flat shelf with the drop hole toward the player (前落とし). Pull it forward (寄せ) with the far-side arm.',
        ),
        recognize: list(
          [
            '박스가 바 없이 평평한 단·판 위에 놓여 있음',
            '낙하구가 필드 앞쪽(플레이어 쪽)에 있음',
            '박스와 낙하구 사이에 남은 거리가 보임',
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
            '노리는 쪽과 반대쪽 아암을 씁니다: 왼쪽으로 끌고 싶으면 오른쪽 아암 발톱을 박스 왼쪽 끝 뒤에 걸어 닫힘 동작으로 끌어당깁니다(寄せ).',
            '좌→우→좌 번갈아 걸어 박스를 지그재그로 앞으로 옮깁니다.',
            '경품의 가벼운 쪽(보통 하반부·발 쪽)을 노리면 한 번에 움직이는 양이 큽니다.',
            '박스 앞쪽이 낙하구 위로 충분히 튀어나올 때까지 서두르지 말고 옮깁니다.',
            '충분히 오면 튀어나온 부분을 아암 본체로 押す(밀기) 또는 뒤쪽 모서리를 持ち上げ(들기)로 넘어뜨립니다.',
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
            '너무 일찍 밀면 플레이만 낭비합니다. "쓸데없는 플레이를 줄이는 것"이 핵심입니다.',
            '발톱이 걸릴 만큼 박스 끝을 깊게 노리되, 중앙을 잡으면 안 움직입니다.',
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
          ['3수 연속 전혀 움직이지 않음(아암 파워 부족)', '박스가 벽·구조물에 걸려 앞으로 못 옴'],
          ['3手続けて全く動かない（アームパワー不足）', '箱が壁・構造物に引っ掛かって手前へ来ない'],
          ['Three plays in a row with no movement (arm too weak)', 'The box is caught on a wall or fixture and cannot come forward'],
        ),
        typicalCost: t(
          '거리에 따라 500~2,000엔 ★ 커뮤니티 참고치',
          '距離次第で500〜2,000円 ★ コミュニティの参考値',
          '¥500–2,000 depending on the distance ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.valleyDrop:
      return LayoutGuide(
        type: type,
        summary: t(
          'V자로 만나는 두 경사판 사이 틈이 낙하구인 谷落とし. 한쪽 경사면에 얹은 뒤 밀거나 찔러 넣습니다.',
          'V字に合わさる2枚の斜面の隙間が落とし口の谷落とし。片方の斜面に乗せてから押す・突きます。',
          'Two sloped boards meet in a V and the gap between them is the drop (谷落とし). Rest the box on one slope, then push or poke it in.',
        ),
        recognize: list(
          ['두 경사판이 V자로 만나고 그 틈이 낙하구', '박스가 경사판 위 또는 골짜기에 걸쳐 있음', '경사가 있어 박스가 스스로 미끄러질 수 있음'],
          ['2枚の斜面がV字に合わさり、その隙間が落とし口', '箱が斜面の上または谷に掛かっている', '傾斜があり箱が自分で滑ることがある'],
          [
            'Two sloped boards meet in a V; the gap at the bottom is the drop hole',
            'The box lies on a slope or straddles the valley',
            'Because of the slope the box can slide on its own',
          ],
        ),
        howTo: list(
          [
            '먼저 박스 방향을 정합니다: 한쪽 아암으로 끝을 걸어 세로(긴 변이 골짜기를 향하게)로 돌립니다.',
            '乗り上げ: 안쪽 끝을 들어 한쪽 경사면 위로 미끄러뜨려 얹습니다.',
            '얹힌 뒤 안쪽을 들어 올리거나(持ち上げ) 앞 모서리를 찔러(突き) 틈으로 미끄러지게 합니다.',
            '한 번에 넣으려 하지 말고 경사를 이용해 조금씩 골짜기로 보냅니다.',
            '가로로 골짜기에 완전히 끼는 자세는 반드시 피합니다(詰み).',
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
          ['패턴 자체는 단순하지만 설정 편차가 큽니다.', '경사는 아군입니다. 무게중심이 틈 쪽으로 넘어가면 스스로 떨어집니다.'],
          ['パターン自体は単純だが設定差が大きい。', '傾斜は味方。重心が隙間側へ越えれば自分で落ちる。'],
          [
            'The pattern is simple but settings vary a lot.',
            'The slope is on your side: once the centre of mass crosses the gap, gravity finishes the job.',
          ],
        ),
        abortWhen: list(
          ['박스가 골짜기에 가로로 완전히 끼어 움직이지 않음(詰み) → 초기 위치 요청', '3수 연속 얹히지 않음'],
          ['箱が谷に横向きで完全に嵌まって動かない（詰み）→ 初期位置を依頼', '3手続けて乗り上がらない'],
          ['The box is wedged sideways in the valley and will not move (詰み): ask for a reset', 'Three plays without getting it onto a slope'],
        ),
        typicalCost: t(
          '설정에 따라 1,000~3,000엔 ★ 커뮤니티 참고치',
          '設定次第で1,000〜3,000円 ★ コミュニティの参考値',
          '¥1,000–3,000 depending on the setting ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.sideDrop:
      return LayoutGuide(
        type: type,
        summary: t(
          '낙하구가 필드 좌/우 측면에 있는 横落とし. 前落とし와 같은 원리로 옆으로 끌어당깁니다.',
          '落とし口がフィールドの左右側面にある横落とし。前落としと同じ原理で横へ寄せます。',
          'The drop hole is on the left or right side of the field (横落とし). Same idea as the front drop, pulling sideways instead.',
        ),
        recognize: list(
          ['낙하구가 필드 왼쪽 또는 오른쪽 가장자리', '박스가 평평한 단 위에 놓임', '낙하구까지의 옆 방향 거리가 보임'],
          ['落とし口がフィールドの左または右の端', '箱が平らな台の上に置かれている', '落とし口までの横方向の距離が見える'],
          ['The drop hole is at the left or right edge of the field', 'The box sits on a flat shelf', 'You can see the sideways distance to the hole'],
        ),
        howTo: list(
          [
            '낙하구 쪽과 먼 쪽 끝을 노립니다: 낙하구가 왼쪽이면 오른쪽 끝의 앞·뒤 모서리를 번갈아 걸어 寄せ합니다.',
            '앞 모서리는 왼쪽 아암, 뒤 모서리는 오른쪽 아암처럼 발톱이 박스 밖에서 안으로 닫히도록 아암을 고릅니다.',
            '가벼운 쪽을 노리면 회전이 커서 한 번에 많이 옵니다.',
            '박스가 낙하구 위로 충분히 나오면 아암 본체나 발톱으로 押し(밀기)해 떨어뜨립니다.',
            '측면 벽에 닿기 전에 각도를 조금씩 보정하며 옮깁니다.',
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
          ['온라인 크레인(オンクレ)에서 초심자용으로 자주 쓰는 배치입니다.', '옆 벽에 붙으면 회전 여유가 사라지니 벽에서 떨어진 채로 옮기세요.'],
          ['オンクレで初心者向けによく使われる設定。', '横の壁に付くと回転の余裕がなくなるので、壁から離したまま運ぶ。'],
          [
            'A common beginner-friendly setup in online crane games (オンクレ).',
            'Once the box touches the side wall it can no longer rotate, so keep it off the wall while moving.',
          ],
        ),
        abortWhen: list(
          ['3수 연속 움직이지 않음', '박스가 측면 벽에 평행하게 붙어 밀리지 않음'],
          ['3手続けて動かない', '箱が側面の壁に平行に張り付いて押せない'],
          ['Three plays in a row without movement', 'The box is flat against the side wall and will not slide'],
        ),
        typicalCost: t('500~2,000엔 ★ 커뮤니티 참고치', '500〜2,000円 ★ コミュニティの参考値', '¥500–2,000 ★ community reference'),
      );

    // -------------------------------------------------------------------------
    case LayoutType.ringPera:
      return LayoutGuide(
        type: type,
        summary: t(
          '얇은 종이·플라스틱 고리(ペラ輪)에 발톱을 넣어 끌어올리는 세팅. 구멍은 보기보다 작아 1수는 개방폭 확인용입니다.',
          '薄い紙・プラスチックの輪（ペラ輪）に爪を入れて引き上げる設定。穴は見た目より小さく、1手目は開き幅の確認用です。',
          'A thin paper or plastic ring (ペラ輪) on the prize that a tip must enter to lift it. The hole is smaller than it looks; play 1 is for measuring the claw spread.',
        ),
        recognize: list(
          ['경품에 얇은 종이·플라스틱 고리(ペラ輪)가 달려 있음', '고리 구멍에 발톱을 넣어 끌어올리는 구조', '종종 경사대(坂) 위에 놓여 있음'],
          ['景品に薄い紙・プラスチックの輪（ペラ輪）が付いている', '輪の穴に爪を入れて引き上げる構造', 'よく坂（斜面台）の上に置かれている'],
          ['A thin paper or plastic ring (ペラ輪) is attached to the prize', 'The idea is to put a tip through the ring and lift', 'Often placed on a ramp (坂)'],
        ),
        howTo: list(
          [
            '1수는 捨てゲー(버리는 플레이)로 생각하고, 아암이 열렸을 때 발톱이 어디에 내려오는지 관찰합니다.',
            '2수부터 고리 구멍 바로 위에 한쪽 발톱이 오도록 아암 중심을 옮깁니다. 구멍은 보기보다 작으니 정밀하게.',
            '발톱이 구멍에 들어가면 닫힘·상승으로 고리가 걸려 경품이 끌려 올라옵니다.',
            '들어가지 않고 안 움직이면 살짝 寄せ 기미(고리를 약간 끌어당기는 각도)로 조준하면 갑자기 걸리기도 합니다.',
            '걸린 뒤에는 낙하구 쪽으로 옮겨질 때까지 같은 지점을 반복합니다.',
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
          ['구멍이 작은 대는 회피가 권장됩니다.', '발톱 두께와 고리 구멍 크기를 먼저 비교하세요.'],
          ['穴の小さい台は回避が推奨。', '爪の太さと輪の穴の大きさを先に比べる。'],
          ['Skip machines with tiny ring holes.', 'Compare the tip thickness with the ring hole before you start.'],
        ),
        abortWhen: list(
          ['발톱이 구멍보다 굵어 물리적으로 안 들어감', '3수 연속 고리를 스치기만 함'],
          ['爪が穴より太くて物理的に入らない', '3手続けて輪をかすめるだけ'],
          ['The tip is thicker than the hole and physically cannot enter', 'Three plays in a row that only brush the ring'],
        ),
        typicalCost: t(
          '개방폭 확인 1수 + 1,000엔 전후 ★ 커뮤니티 참고치',
          '開き幅確認の1手＋1,000円前後 ★ コミュニティの参考値',
          'One measuring play plus about ¥1,000 ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.ringD:
      return LayoutGuide(
        type: type,
        summary: t(
          '금속 D링·O링이 봉에 걸린 세팅(D環 / Oリング). 링 중심이 아니라 바깥쪽을 좌우 번갈아 노려 닫힘 동작으로 옮깁니다.',
          '金属のD環・Oリングが棒に掛かった設定。リングの中心ではなく外側を左右交互に狙い、閉じる動作で動かします。',
          'A metal D-ring or O-ring (D環 / Oリング) hangs on a rod. Aim at the outside of the ring, alternating sides, and let the closing motion move it.',
        ),
        recognize: list(
          ['경품에 D자·O자 금속 링이 달려 봉(棒)에 걸려 있음', 'O링은 점원이 위치를 옮길 수 있어 링 위치가 제각각', '링 구멍 크기와 봉 굵기가 핵심'],
          ['景品にD字・O字の金属リングが付いて棒に掛かっている', 'Oリングは店員が位置を動かせるためリング位置はまちまち', 'リングの穴の大きさと棒の太さが鍵'],
          [
            'A D- or O-shaped metal ring on the prize hangs from a rod (棒)',
            'O-rings can be repositioned by staff, so ring positions vary',
            'The ring hole size and rod thickness are what matter',
          ],
        ),
        howTo: list(
          [
            '1수로 아암 파워를 확인합니다. 링이 떨리기만 하면 파워가 부족한 것입니다.',
            '링 중심이 아니라 링의 바깥쪽 가장자리를 노립니다. 발톱이 닫히며 링을 낙하구 쪽으로 밀어내도록.',
            '왼쪽·오른쪽을 번갈아 걸어 링과 경품을 봉 끝(낙하구)으로 조금씩 옮깁니다(リング寄せ).',
            '들어 올리려 하지 말고 "아암이 닫히는 동작"으로 움직인다는 의식을 유지합니다.',
            '경품이 봉에 대해 세로가 되어 불안정해지면 링 중심을 뒤에서 밀어(押し) 넘깁니다.',
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
          ['아암 파워 확인이 최우선입니다.', '링이 봉에 걸리는 각도가 바뀌면 진행 방향도 바뀝니다. 사진을 다시 찍어 확인하세요.'],
          ['アームパワーの確認が最優先。', 'リングが棒に掛かる角度が変わると進む方向も変わる。写真を撮り直して確認する。'],
          ['Checking arm power comes first.', 'If the ring\'s angle on the rod changes, its travel direction changes too; re-shoot and re-check.'],
        ),
        abortWhen: list(
          ['링이 떨리기만 하고 자리를 옮기지 않음 → 즉시 철수', '경품이 봉에 걸려 링만 돌아감'],
          ['リングが震えるだけで位置が変わらない → 即撤退', '景品が棒に引っ掛かってリングだけ回る'],
          ['The ring only shivers without changing position: walk away now', 'The prize is snagged on the rod and only the ring turns'],
        ),
        typicalCost: t(
          '파워가 맞으면 500~1,500엔, 아니면 즉시 철수 ★ 커뮤니티 참고치',
          'パワーが合えば500〜1,500円、合わなければ即撤退 ★ コミュニティの参考値',
          '¥500–1,500 when the arm is strong enough; otherwise leave immediately ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.hookS:
      return LayoutGuide(
        type: type,
        summary: t(
          '아암 대신 체인+S자 훅으로 링을 낚는 釣り 세팅(S字フック). 훅을 흔들어 링에 떨어뜨리며 운 요소가 큽니다.',
          'アームの代わりにチェーン＋S字フックでリングを釣る設定。フックを揺らしてリングに落とす、運の要素が大きい台です。',
          'A chain with an S-hook replaces the claw and you fish for a ring (S字フック / 釣り). Swing the hook into the ring; luck plays a big part.',
        ),
        recognize: list(
          ['아암 대신 체인에 S자 훅이 매달려 있음', '대상은 그물·D링·O링 등 걸 수 있는 고리', '훅이 흔들리며 내려감'],
          ['アームの代わりにチェーンにS字フックが吊られている', '対象は網・D環・Oリングなど掛けられる輪', 'フックが揺れながら降りる'],
          ['An S-shaped hook hangs from a chain instead of a claw', 'The target is a net, D-ring, O-ring or similar loop', 'The hook swings as it descends'],
        ),
        howTo: list(
          [
            '조작 시간을 짧게 끊어 훅이 크게 흔들리게 합니다.',
            '방법 ①: 링 정면보다 약간 앞~절반 지점을 조준해 훅 끝을 링 안쪽에 넣고 안쪽으로 미끄러뜨려 겁니다.',
            '방법 ②: 링이 흔들릴 때 되돌아오는 방향을 읽고 바깥에서 걸리도록 타이밍을 맞춥니다.',
            '걸리면 상승·이동 중에 빠지지 않게 훅이 링 깊숙이 들어갔는지 확인합니다.',
            '안 걸리면 조준점을 조금씩 바꾸며 반복합니다.',
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
          ['운 요소가 크지만 흔들림을 이용하면 확률은 올릴 수 있습니다.', '회수 상한을 정하고 시작하세요.'],
          ['運の要素が大きいが、揺れを使えば確率は上げられる。', '手数の上限を決めてから始める。'],
          ['Luck matters a lot, but using the swing improves your odds.', 'Decide on a play limit before you start.'],
        ),
        abortWhen: list(
          ['훅이 링 크기보다 커서 들어가지 않음', '정한 회수 상한에 도달'],
          ['フックがリングより大きくて入らない', '決めた手数の上限に達した'],
          ['The hook is bigger than the ring and cannot enter', 'You have hit your play limit'],
        ),
        typicalCost: t(
          '운 의존, 상한을 정해 두세요 (1,000~2,000엔) ★ 커뮤니티 참고치',
          '運次第、上限を決めておく（1,000〜2,000円）★ コミュニティの参考値',
          'Luck-dependent; set a cap (¥1,000–2,000) ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.takoyaki:
      return LayoutGuide(
        type: type,
        summary: t(
          '핑퐁공 더미와 다코야키 판형 구멍판(たこ焼き). 높게 쌓인 곳의 공을 집어 당첨 구멍에 넣는 운 요소 큰 세팅.',
          'ピンポン玉の山とたこ焼き型の穴板。高く積まれた所の玉をつかんで当たり穴に入れる、運の要素が大きい台。',
          'A heap of ping-pong balls and a takoyaki-style hole board (たこ焼き). Grab a ball from the tallest part of the pile and hope it lands in a winning hole.',
        ),
        recognize: list(
          ['핑퐁공 무더기 + 구멍이 여러 개 뚫린 판', '당첨 구멍이 색·표시로 구분됨', '꽝 구멍 일부가 이미 채워져 있기도 함'],
          ['ピンポン玉の山＋穴がいくつも空いた板', '当たり穴が色・表示で区別されている', 'ハズレ穴の一部がすでに埋まっていることもある'],
          ['A pile of ping-pong balls plus a board with many holes', 'Winning holes are marked by colour or label', 'Some losing holes may already be filled'],
        ),
        howTo: list(
          [
            '공이 가장 높게 쌓인 곳을 노려 아암이 공을 한 개 이상 집도록 합니다.',
            '꽝 구멍이 이미 채워진 판, 당첨 구멍에 들어가기 쉬운 배치의 기계를 고릅니다.',
            '집은 공은 판 위에서 튀다가 어딘가에 안착합니다. 떨어뜨리는 위치를 당첨 구멍 근처로.',
            '時短(시간 단축)형은 남은 꽝 구멍 수를 보고 확률을 가늠합니다.',
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
          ['실력보다 운입니다. 반복 플레이 전제로 예산을 정하세요.', '공을 여러 개 집히면 기회가 늘어납니다.'],
          ['実力より運。繰り返しプレイ前提で予算を決める。', '玉を複数つかめれば機会が増える。'],
          ['This is luck more than skill; budget for repeated plays.', 'Grabbing several balls at once gives more chances.'],
        ),
        abortWhen: list(
          ['공이 낮게 흩어져 집히지 않음', '예산 상한 도달'],
          ['玉が低く散らばってつかめない', '予算の上限に達した'],
          ['The balls are scattered too low to grab', 'You have reached your budget'],
        ),
        typicalCost: t(
          '운 의존, 예산을 정해 두세요 ★ 커뮤니티 참고치',
          '運次第、予算を決めておく ★ コミュニティの参考値',
          'Luck-dependent; set a budget first ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.threeClaw:
      return LayoutGuide(
        type: type,
        summary: t(
          '3발톱 대형 유닛의 봉제인형 세팅(3本爪). 대부분 확률기이므로 임계 전엔 물리적 이동만 유효합니다.',
          '3本爪の大型ユニットでぬいぐるみを狙う設定。多くは確率機なので、天井前は物理的な移動だけが有効です。',
          'Large plush toys under a three-claw unit (3本爪). Most are payout-controlled (確率機), so before the threshold only physical movement counts.',
        ),
        recognize: list(
          ['아암 발톱이 3개, UFO 유닛이 큼', '넓은 쇼케이스에 대형 인형', '기종·アシストランプ 색이 확률기 여부의 힌트'],
          ['アームの爪が3本、UFOユニットが大きい', '広いショーケースに大型ぬいぐるみ', '機種・アシストランプの色が確率機かどうかのヒント'],
          ['The claw has three tips and the unit is large', 'Big plush toys in a wide showcase', 'The machine model and the assist-lamp colour hint at payout control'],
        ),
        howTo: list(
          [
            '인형의 무게중심·균형점을 3발톱이 감싸도록 아암 중심을 맞춥니다.',
            '발톱이 인형 아래로 들어갔는지 확인합니다. 2발톱만 걸리면 무게를 못 버팁니다.',
            '태그(タグ)가 있으면 태그에 발톱을 거는 タグ掛け도 유효합니다.',
            '임계 전에는 확률을 무시하고 寄せ·押し로 낙하구 쪽으로 물리적으로 옮깁니다(確率無視).',
            '실드(壁)에 걸리면 반대쪽을 들어 넘겨 떨어뜨립니다.',
            '발톱 휨(しなり)이 달라지거나 인형이 전보다 크게 움직이면 임계 근처 신호입니다.',
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
            '天井(임계)는 보통 1,000~7,000엔, 소매가의 1.5~2배 근처가 신호입니다.',
            'アシストランプ가 초록이면 설정 회수 초과 신호일 수 있습니다(점원 어시스트 가능성).',
            '확률기 판정은 추정일 뿐입니다.',
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
          ['寄せ·押し로도 전혀 옮겨지지 않고 아암이 항상 열림', '투입액이 정한 상한(소매가 ×2)을 넘김'],
          ['寄せ・押しでも全く動かず、アームがいつも開く', '投入額が決めた上限（小売価格×2）を超えた'],
          ['Nothing moves even with pulls and pushes and the claw always opens', 'You have spent past your limit (about 2× retail)'],
        ),
        typicalCost: t(
          '인형 1개 3,000~4,000엔 사례, 天井 1,000~7,000엔 ★ 커뮤니티 참고치',
          'ぬいぐるみ1個で3,000〜4,000円の例、天井1,000〜7,000円 ★ コミュニティの参考値',
          'Reports of ¥3,000–4,000 per plush; threshold ¥1,000–7,000 ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.twoClawDirect:
      return LayoutGuide(
        type: type,
        summary: t(
          '2발톱(2本爪) 아암으로 바닥·단 위 인형을 직접 집는 直取り. 목·다리 사이·태그 등 걸릴 부위를 노려 낙하구로 옮깁니다.',
          '2本爪アームで床・台の上のぬいぐるみを直接取る直取り。首・足の間・タグなど掛かる部位を狙って落とし口へ運びます。',
          'A two-claw arm grabs a plush lying directly on the floor or a shelf (2本爪 直取り). Hook a catchable part, such as the neck, between the legs or a tag, and walk it to the drop.',
        ),
        recognize: list(
          ['2발톱 아암, 인형이 바닥·단 위에 직접 놓임', '바·링 등 보조 구조물 없음', '실력기(実力機)일 가능성이 높아 회수 예측이 쉬움'],
          ['2本爪アーム、ぬいぐるみが床・台に直接置かれている', 'バー・リングなどの補助構造がない', '実力機の可能性が高く手数を読みやすい'],
          ['Two-tip claw; the plush lies directly on the floor or a shelf', 'No bars, rings or other fixtures', 'Likely a skill machine (実力機), so plays are predictable'],
        ),
        howTo: list(
          [
            '걸릴 부위를 고릅니다: 목, 다리 사이, 팔과 몸통 사이, 태그.',
            '소형 인형은 태그를 노려 낙하구 쪽으로 寄せ(끌어당기기)합니다.',
            '발톱 각도가 90°에 가까운 기계가 유리합니다. 1수로 발톱이 어디에 닿는지 관찰하세요.',
            '다리를 들어 낙하구 쪽으로 넘어뜨리듯(持ち上げ) 움직입니다.',
            '낙하구 가장자리까지 오면 튀어나온 부분을 걸어 떨어뜨립니다.',
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
          ['무게중심을 잡으면 들리고, 아니면 회전만 합니다. 회전도 진행입니다.', '틈에 발톱을 박는 スキマフック도 유효합니다.'],
          ['重心をつかめば上がり、外れれば回るだけ。回転も前進のうち。', '隙間に爪を差し込むスキマフックも有効。'],
          ['Catch the centre of mass and it lifts; miss it and it just rotates, which is still progress.', 'Jamming a tip into a gap (スキマフック) also works.'],
        ),
        abortWhen: list(
          ['3수 연속 발톱이 미끄러져 걸리지 않음', '인형이 벽 구석에 눌려 옮길 수 없음'],
          ['3手続けて爪が滑って掛からない', 'ぬいぐるみが壁の隅に押し付けられて動かせない'],
          ['Three plays in a row the tips slip off without catching', 'The plush is pressed into a corner and cannot be moved'],
        ),
        typicalCost: t(
          '실력기라면 500~1,500엔 ★ 커뮤니티 참고치',
          '実力機なら500〜1,500円 ★ コミュニティの参考値',
          '¥500–1,500 on a skill machine ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.pile:
      return LayoutGuide(
        type: type,
        summary: t(
          '소형 경품이 산처럼 쌓인 山積み. 寄せる·押す·すくう로 산을 무너뜨려(雪崩) 한꺼번에 떨어뜨립니다.',
          '小型景品が山のように積まれた山積み。寄せる・押す・すくうで山を崩し（雪崩）、まとめて落とします。',
          'Small prizes heaped in a pile (山積み). Pull, push and scoop to trigger an avalanche (雪崩) that drops several at once.',
        ),
        recognize: list(
          ['다수의 소형 경품(마스코트 등)이 산처럼 쌓임', '낙하구가 산의 한쪽 옆에 있음', '산의 경사가 어느 쪽으로 내려가는지 보임'],
          ['多数の小型景品（マスコットなど）が山のように積まれている', '落とし口が山の片側にある', '山の傾斜がどちらへ下がっているか見える'],
          ['Many small prizes (mascots etc.) piled into a mound', 'The drop hole is beside the pile', 'You can see which way the pile slopes down'],
        ),
        howTo: list(
          [
            '기본은 寄せる·押す·すくう 세 가지. 산의 낙하구 쪽 경사를 노립니다.',
            '아암이 상승할 때 산이 무너지도록, 산 꼭대기나 낙하구 쪽 사면의 경품을 발톱으로 걸어 들어 올립니다(雪崩 유도).',
            '주변에 같은 높이의 경품이 있으면 경사가 내려가는 쪽으로 押す(밀기).',
            '아래에서 퍼올리는 すくい로 여러 개를 한 번에 낙하구로 보냅니다.',
            '한 개씩보다 산 전체의 균형을 깨는 것을 목표로 합니다.',
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
          ['산은 위치 에너지 덩어리입니다. 무너질 방향을 먼저 읽으세요.', '대량 획득이 가능한 세팅입니다.'],
          ['山は位置エネルギーの塊。崩れる方向を先に読む。', '大量獲得が可能な設定。'],
          ['The pile is stored potential energy; read which way it will collapse first.', 'This setup can yield several prizes.'],
        ),
        abortWhen: list(
          ['산이 낮고 평평해져 무너질 여지가 없음', '3수 연속 아무것도 움직이지 않음'],
          ['山が低く平らになって崩れる余地がない', '3手続けて何も動かない'],
          ['The pile has flattened out with nothing left to collapse', 'Three plays in a row without any movement'],
        ),
        typicalCost: t(
          '500~1,500엔에 복수 획득 사례 ★ 커뮤니티 참고치',
          '500〜1,500円で複数獲得の例 ★ コミュニティの参考値',
          'Reports of several prizes for ¥500–1,500 ★ community reference',
        ),
      );

    // -------------------------------------------------------------------------
    case LayoutType.floorBox:
      return LayoutGuide(
        type: type,
        summary: t(
          '박스가 바 없이 바닥·단 위에 놓인 箱 直置き. 발톱 위치를 박스 틈에 맞추고, 대형은 横ハメ 후 角持ち上げ.',
          '箱がバーなしで床・台に置かれた箱 直置き。爪の位置を箱の隙間に合わせ、大型は横ハメ後に角持ち上げ。',
          'A box placed directly on the floor or a shelf, no bars (箱 直置き). Match the tips to the gaps around the box; big boxes get turned flat then corner-lifted (角持ち上げ).',
        ),
        recognize: list(
          ['박스형 경품이 바 없이 바닥·단 위에 놓임', '박스 주위에 발톱이 들어갈 틈(すきま)이 있음', '낙하구는 앞·옆 등 어느 방향이든 가능'],
          ['箱型景品がバーなしで床・台に置かれている', '箱の周りに爪が入る隙間がある', '落とし口は手前・横などどの方向でもあり得る'],
          ['A box-shaped prize sits on the floor or a shelf without bars', 'There are gaps (すきま) around the box where a tip can enter', 'The drop can be in front, to the side or elsewhere'],
        ),
        howTo: list(
          [
            '아암이 열렸을 때 발톱이 박스 옆 틈에 정확히 들어가도록 아암 중심을 맞춥니다.',
            '무게중심을 가늠합니다: 뜨지 않는 쪽이 무거운 쪽입니다.',
            '소형 박스: 양 발톱으로 집어 들어 올리거나(持ち上げ) 한쪽을 걸어 낙하구 쪽으로 寄せ합니다.',
            '대형 박스: 먼저 横ハメ처럼 박스를 눕혀 안정시킨 뒤, 가라앉은 모서리를 들어 올리는 角持ち上げ로 낙하구로 넘깁니다.',
            '낙하구 가장자리에 걸치면 튀어나온 모서리를 눌러 떨어뜨립니다.',
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
          ['무게중심 파악이 성패를 가릅니다.', '발톱 두께보다 틈이 좁으면 먼저 寄せ로 틈을 만드세요.'],
          ['重心の把握が成否を分ける。', '爪の太さより隙間が狭ければ、先に寄せで隙間を作る。'],
          ['Reading the centre of mass decides the outcome.', 'If the gap is narrower than the tip, make a gap first with a pull.'],
        ),
        abortWhen: list(
          ['박스가 벽에 밀착해 발톱이 들어갈 틈이 없음', '3수 연속 미동도 없음'],
          ['箱が壁に密着して爪の入る隙間がない', '3手続けて微動だにしない'],
          ['The box is flush against a wall with no gap for a tip', 'Three plays in a row without the slightest movement'],
        ),
        typicalCost: t('1,000~2,500엔 ★ 커뮤니티 참고치', '1,000〜2,500円 ★ コミュニティの参考値', '¥1,000–2,500 ★ community reference'),
      );

    // -------------------------------------------------------------------------
    case LayoutType.unknown:
      return LayoutGuide(
        type: type,
        summary: t(
          '사진만으로 배치를 판별하지 못했습니다(判別不可). 다른 각도로 다시 촬영해 주세요.',
          '写真だけでは設置パターンを判別できませんでした（判別不可）。別の角度から撮り直してください。',
          'The layout could not be identified from this photo (判別不可). Please re-shoot from a different angle.',
        ),
        recognize: list(
          ['아암·바·낙하구 중 하나 이상이 사진에 없음', '반사·역광으로 경품 윤곽이 흐림', '비스듬한 각도라 바 간격·높이를 읽을 수 없음'],
          ['アーム・バー・落とし口のいずれかが写っていない', '反射・逆光で景品の輪郭がぼやけている', '斜めの角度でバー間隔・高さが読めない'],
          ['The claw, the bars or the drop hole is missing from the photo', 'Reflections or backlight blur the prize outline', 'The angle is too oblique to read bar spacing or height'],
        ),
        howTo: list(
          [
            '유리에 밀착해 반사를 줄이고 기계 정면에서 수평으로 다시 촬영합니다.',
            '아암(アーム)·바(バー)·낙하구가 한 장에 모두 들어오게 합니다.',
            '바 높이 차·튜브 색이 보이도록 살짝 위에서 내려다보는 각도를 추가합니다.',
            '그래도 판별되지 않으면 이 가이드 목록에서 눈으로 가장 비슷한 유형을 골라 참고하세요.',
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
          ['사진 1장이면 충분하지만, 정면·수평이 중요합니다.', '대기자가 있으면 촬영은 1게임 안에 마치세요.'],
          ['写真は1枚で十分だが、正面・水平が重要。', '待っている人がいれば撮影は1ゲーム以内で。'],
          ['One photo is enough, but it must be frontal and level.', 'If others are waiting, finish shooting within one game.'],
        ),
        abortWhen: list(
          ['재촬영 후에도 판별 불가', '매장이 촬영을 금지함'],
          ['撮り直しても判別不可', '店舗が撮影を禁止している'],
          ['Still unidentified after re-shooting', 'The arcade does not allow photos'],
        ),
        typicalCost: t(
          '판별 후 해당 유형의 참고 비용을 확인하세요',
          '判別後に該当パターンの参考費用を確認してください',
          'Check the typical cost of the identified type after re-shooting',
        ),
      );
  }
}
