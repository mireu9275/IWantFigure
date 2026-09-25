/// Map-free, switch-based localization for the app UI.
///
/// Every user-visible string lives here so that the rest of the code never
/// hard-codes Korean/Japanese/English text. Japanese and English text keep the
/// Japanese arcade terms players use (縦ハメ, 橋渡し, 手前バー …); Korean text is
/// plain Korean (봉, 집게, 집게발 …) and shows the Japanese name only once, on
/// the guide page ([guideJapaneseName]).
/// No string here may promise a win (「必ず取れる」 is never used).
library;

import 'package:flutter/widgets.dart';

import '../engine/inputs.dart';
import '../models/analysis.dart';
import '../services/api_client.dart' show AnalyzeApi;

/// Supported UI languages.
enum AppLocale {
  ko('ko', '한국어'),
  ja('ja', '日本語'),
  en('en', 'English');

  const AppLocale(this.code, this.nativeName);

  /// BCP-47 style code sent to the server and to the aim engine.
  final String code;

  /// Name of the language in that language (for the picker).
  final String nativeName;

  static AppLocale fromCode(String? code) {
    final c = (code ?? '').toLowerCase();
    if (c.startsWith('ja')) return AppLocale.ja;
    if (c.startsWith('en')) return AppLocale.en;
    return AppLocale.ko;
  }
}

/// Inherited widget that carries the current [S] down the tree.
class LocaleScope extends InheritedWidget {
  const LocaleScope({super.key, required this.strings, required super.child});

  final S strings;

  static S? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.strings;

  @override
  bool updateShouldNotify(LocaleScope oldWidget) =>
      oldWidget.strings.locale != strings.locale;
}

/// Localized strings. Obtain with `S.of(context)`; falls back to [S.current]
/// (set by the settings store) when no [LocaleScope] is above the widget.
class S {
  const S(this.locale);

  final AppLocale locale;

  /// Locale used when no [LocaleScope] is present (e.g. in dialogs built
  /// outside the widget tree or in unit tests).
  static S current = const S(AppLocale.ko);

  static S of(BuildContext context) => LocaleScope.maybeOf(context) ?? current;

  /// Language code passed to the server and the engine.
  String get code => locale.code;

  String _t(String ko, String ja, String en) => switch (locale) {
        AppLocale.ko => ko,
        AppLocale.ja => ja,
        AppLocale.en => en,
      };

  // ---------------------------------------------------------------------------
  // Generic

  String get appName => 'IWantFigure';
  String get ok => _t('확인', 'OK', 'OK');
  String get cancel => _t('취소', 'キャンセル', 'Cancel');
  String get save => _t('저장', '保存', 'Save');
  String get delete => _t('삭제', '削除', 'Delete');
  String get retry => _t('다시 시도', '再試行', 'Retry');
  String get undo => _t('되돌리기', '元に戻す', 'Undo');
  String get close => _t('닫기', '閉じる', 'Close');
  String get back => _t('뒤로', '戻る', 'Back');
  String get done => _t('완료', '完了', 'Done');
  String get apply => _t('적용', '適用', 'Apply');
  String get reset => _t('초기화', 'リセット', 'Reset');
  String get yes => _t('예', 'はい', 'Yes');
  String get no => _t('아니요', 'いいえ', 'No');
  String get unknown => _t('알 수 없음', '不明', 'Unknown');
  String get estimated => _t('추정', '推定', 'estimated');

  // ---------------------------------------------------------------------------
  // Home

  String get homeTagline => _t(
        '크레인 게임 기계 사진을 찍으면 어디를 노리면 좋을지 알려 드립니다',
        'クレーンゲームの写真から「どこを狙うか」を提案します',
        'Photograph a crane game (クレーンゲーム) and get a suggested aim point',
      );
  String get takePhoto => _t('촬영', '撮影', 'Camera');
  String get pickFromGallery => _t('갤러리', 'ギャラリー', 'Gallery');
  String get mockModeChip => _t('모의 분석 모드', 'モック解析モード', 'Mock analysis');
  String get mockResultBanner => _t(
        '모의 분석 결과입니다. 올린 사진은 분석하지 않고, 미리 준비한 예시 결과를 보여 줍니다. 실제로 분석하려면 설정에서 모의 분석 모드를 끄고 서버를 연결하세요.',
        'モック解析の結果です。撮った写真は解析せず、例の結果を表示しています。実際の解析は設定でモック解析モードをオフにしてサーバーに接続してください。',
        'Mock analysis: your photo was not analysed; this is a sample result. Turn off mock mode in Settings and connect a server for a real analysis.',
      );

  /// Guide page (Korean only): the Japanese community name, for talking to
  /// staff or searching Japanese guides.
  String guideJapaneseName(String name) => _t('일본 명칭: $name', '日本での呼び名: $name', 'Japanese name: $name');

  String get mockModeChipHint => _t(
        '서버 없이 미리 준비한 예시 결과를 보여 줍니다. 설정에서 바꿀 수 있습니다.',
        'サーバーなしでサンプル結果を使います。設定で変更できます。',
        'Uses a bundled sample result instead of a server. Change it in Settings.',
      );
  String get shootingGuideTitle => _t('촬영 가이드', '撮影ガイド', 'Shooting guide');
  List<String> get shootingGuideItems => [
        _t('휴대폰을 유리에 바짝 대면 반사가 줄어듭니다', 'ガラスに密着させて反射を減らす', 'Hold the phone against the glass to reduce reflections'),
        _t('기계 정면에서 수평을 맞춰 찍으세요', '筐体の正面から、水平に撮る', 'Shoot from the front of the cabinet, level with the floor'),
        _t('집게와 봉이 모두 보이게 찍으세요', 'アームとバーが両方写るように', 'Keep both the claw (アーム) and the bars (バー) in frame'),
        _t('다른 손님의 얼굴이 나오지 않게 하세요', '他のお客さんの顔が写らないように', 'Do not capture other customers\' faces'),
        _t('매장에서 촬영해도 되는지 먼저 확인하세요', '店舗の撮影ルールを先に確認', 'Check the arcade\'s photo rules first'),
        _t('기다리는 사람이 있으면 한 판만 하고 양보하세요', '待っている人がいれば1ゲーム以内で', 'If others are waiting, finish within one game'),
        _t('사진은 한 장이면 충분합니다 (빠른 분석)', '写真は1枚で十分です（すばやく解析）', 'One photo is enough (quick analysis)'),
      ];
  String get hideGuide => _t('가이드 숨기기', 'ガイドを隠す', 'Hide guide');
  String get historyTitle => _t('지난 기록', '履歴', 'History');
  String get historyEmpty => _t(
        '아직 기록이 없습니다. 사진을 찍어서 시작해 보세요.',
        'まだ履歴がありません。写真を撮って始めましょう。',
        'No sessions yet. Take a photo to start.',
      );
  String get deleteHistoryTitle => _t('기록을 삭제할까요?', '履歴を削除しますか？', 'Delete this record?');
  String get pickFailed => _t('사진을 불러오지 못했습니다', '写真を読み込めませんでした', 'Could not load the photo');

  // ---------------------------------------------------------------------------
  // Analyzing

  String get analyzingTitle => _t('분석 중', '解析中', 'Analyzing');
  String get stagePrepare => _t('사진 준비', '写真を準備', 'Preparing photo');
  String get stageBlur => _t('얼굴 가리기', '顔をぼかす', 'Hiding faces');
  String facesBlurred(int n) => n == 0
      ? _t('감지된 얼굴 없음', '顔は検出されませんでした', 'No faces detected')
      : _t('얼굴 $n개를 가렸습니다', '顔を$n件ぼかしました', 'Hid $n face(s)');
  String get blurFaces => _t('얼굴 자동 가리기', '顔を自動でぼかす', 'Blur faces automatically');
  String get consentTitle => _t('시작하기 전에', 'はじめる前に', 'Before you start');
  String get consentBody => _t(
        '어디를 노릴지 추천하기 위해, 찍은 기계 사진을 분석 서버와 미국에 있는 AI 서비스(Google 또는 Anthropic)로 보냅니다. 서버는 사진을 저장하지 않습니다.\n\n'
            '보내기 전에 기기 안에서 사람 얼굴을 자동으로 가립니다. 다른 손님이 찍히지 않게 주의하고, 매장의 촬영 규정을 지켜 주세요.\n\n'
            '추천은 참고용이며 경품 획득을 보장하지 않습니다. 모의 모드에서는 사진을 보내지 않습니다.',
        '狙い所を提案するため、撮影した筐体の写真は解析サーバーと米国のAIサービス（Google または Anthropic）へ送信されます。サーバーは写真を保存しません。\n\n'
            '送信前に端末内で人の顔を自動的にぼかします。他のお客様が写らないよう注意し、店舗の撮影ルールを守ってください。\n\n'
            '提案は参考情報であり、景品の獲得を保証するものではありません。モックモードでは写真は送信されません。',
        'To recommend where to aim, the photo of the machine is sent to our analysis server and to an AI service in the United States (Google or Anthropic). The server does not store photos.\n\n'
            'Faces are blurred on your device before upload. Avoid photographing other customers and follow the arcade\'s photo rules.\n\n'
            'Recommendations are advisory and do not guarantee a prize. In mock mode no photo is sent.',
      );
  String get consentAgree => _t('동의하고 시작', '同意して始める', 'Agree and start');
  String get consentMockOnly => _t('모의 모드로만 사용', 'モックモードのみ使う', 'Use mock mode only');
  String get blurFacesHint => _t(
        '사진을 보내거나 저장하기 전에 기기 안에서 사람 얼굴을 모자이크합니다. 다른 손님의 개인정보를 지키려면 켜 두세요.',
        '送信・保存の前に端末内で人の顔をモザイク処理します。他のお客様のプライバシー保護のためオンのままにしてください。',
        'Pixelates faces on the device before upload and storage. Keep it on to protect other customers\' privacy.',
      );
  String get stageServer => _t('서버에서 분석', 'サーバーで解析', 'Server analysis');
  String get stageAim => _t('조준 위치 계산', '狙いを計算', 'Computing aim');
  String get analyzeFailed => _t('분석에 실패했습니다', '解析に失敗しました', 'Analysis failed');
  String get switchToMock => _t('모의 모드로 전환', 'モックモードに切替', 'Switch to mock mode');
  String get errorNetwork => _t(
        '서버에 연결할 수 없습니다. 네트워크와 서버 주소를 확인하세요.',
        'サーバーに接続できません。ネットワークとサーバーURLを確認してください。',
        'Cannot reach the server. Check the network and the server URL.',
      );
  String get errorTimeout {
    final sec = AnalyzeApi.defaultTimeout.inSeconds;
    return _t(
      '서버가 $sec초 안에 응답하지 않았습니다.',
      'サーバーの応答がありません（$sec秒超過）。',
      'The server did not respond within $sec seconds.',
    );
  }

  String errorServer(int status, String message) => _t(
        '서버 오류 ($status): $message',
        'サーバーエラー ($status): $message',
        'Server error ($status): $message',
      );
  String get errorUnauthorized => _t(
        '서버가 앱 키를 거부했습니다. 설정에서 앱 키(X-App-Key)를 확인하세요.',
        'サーバーがアプリキーを拒否しました。設定でアプリキー (X-App-Key) を確認してください。',
        'The server rejected the app key. Check the app key (X-App-Key) in Settings.',
      );
  String get errorRateLimited => _t(
        '요청이 너무 많습니다. 잠시 후 다시 시도하세요.',
        'リクエストが多すぎます。しばらくしてから再試行してください。',
        'Too many requests. Please try again in a moment.',
      );
  String get errorProviderNotConfigured => _t(
        '서버에 분석용 AI(LLM)가 설정되어 있지 않습니다. 서버 관리자에게 문의하거나 모의 모드를 사용하세요.',
        'サーバーに解析プロバイダ (LLM) が設定されていません。サーバー管理者に確認するか、モックモードを使ってください。',
        'The server has no analysis provider (LLM) configured. Contact the server admin or use mock mode.',
      );
  String errorProvider(String detail) => _t(
        '분석 AI 오류: $detail',
        '解析プロバイダのエラー: $detail',
        'Analysis provider error: $detail',
      );
  String get errorBadResponse => _t(
        '서버 응답을 읽을 수 없습니다.',
        'サーバーの応答を解釈できません。',
        'The server response could not be parsed.',
      );

  // ---------------------------------------------------------------------------
  // Result

  String get tabPhoto => _t('사진', '写真', 'Photo');
  String get tab3d => '3D';
  String get tabExplain => _t('설명', '説明', 'Explain');
  String get correct => _t('보정', '補正', 'Adjust');
  String get correctHint => _t(
        '모서리·봉·윗면 경계를 끌어서 사진에 맞추세요',
        '角・バー・上面の境界をドラッグして合わせてください',
        'Drag the corners, bars and top-face edge to match the photo',
      );
  String get prizeInfo => _t('경품 정보', '景品情報', 'Prize');
  String get currentStep => _t('이번 판', '今回のプレイ', 'This play');
  String stepOf(int index, int total) => _t('$index/$total판', '$index/$total 手目', 'Step $index/$total');
  String get afterPlay => _t('해 보니 어땠나요?', 'プレイ後の結果は？', 'What happened after the play?');
  String get finishedBanner => _t(
        '경품이 떨어졌습니다! 완료를 눌러 기록을 저장하세요.',
        '景品が落ちました！「完了」を押して記録を保存しましょう。',
        'The prize dropped! Tap Done to save the record.',
      );
  String get giveUp => _t('실패/포기', '失敗/あきらめる', 'Fail / give up');
  String get noPlanTitle => _t('조준 위치를 계산하지 못했습니다', '狙い位置を計算できませんでした', 'Could not compute an aim point');
  String get playsCount => _t('플레이 횟수', 'プレイ回数', 'Number of plays');
  String get yenSpent => _t('쓴 금액 (엔)', '使った金額（円）', 'Amount spent (yen)');
  String get saveResultTitle => _t('결과 저장', '結果を保存', 'Save result');
  String get outcomeSuccess => _t('획득', '獲得', 'Won');
  String get outcomeFail => _t('실패', '失敗', 'Failed');
  String get outcomeOpen => _t('진행 중', '進行中', 'Open');
  String get readOnlyBanner => _t('저장된 기록 (읽기 전용)', '保存済みの記録（読み取り専用）', 'Saved record (read-only)');
  String get savedToHistory => _t('기록에 저장했습니다', '履歴に保存しました', 'Saved to history');
  String saveFailed(String detail) => _t(
        '기록을 저장하지 못했습니다: $detail',
        '記録を保存できませんでした: $detail',
        'Could not save the record: $detail',
      );

  // Explanation tab
  String get sectionSummary => _t('요약', '概要', 'Summary');
  String get layoutType => _t('배치 유형', '設置パターン', 'Layout type');
  String get confidence => _t('신뢰도', '信頼度', 'Confidence');
  String get technique => _t('기법', 'テクニック', 'Technique');
  String get sectionRationale => _t('여기를 노리는 이유', 'なぜこの位置か', 'Why this point');
  String get sectionSteps => _t('플레이 순서', 'プレイ手順', 'Play sequence');
  String get sectionAbort => _t('그만둘 때', '撤退条件', 'When to stop');
  String get sectionWarnings => _t('주의', '注意', 'Warnings');
  String get sectionRequestedPhotos => _t('추가로 필요한 사진', '追加で必要な写真', 'More photos requested');
  String get sectionMachine => _t('기계 정보', '筐体情報', 'Machine');
  String get sectionAnalysis => _t('분석 정보', '解析情報', 'Analysis');
  String get clawCount => _t('집게발 수', 'アーム数', 'Claw arms');
  String get armPower => _t('집게 힘', 'アームパワー', 'Arm power');
  String get assistLamp => _t('보조 램프', 'アシストランプ', 'Assist lamp');
  String get exitSide => _t('출구 위치', '落とし口の位置', 'Exit side');
  String get provider => _t('분석 AI', '解析プロバイダ', 'Provider');
  String get latency => _t('응답 시간', '応答時間', 'Latency');
  String get analysisIdLabel => _t('분석 ID', '解析ID', 'Analysis ID');
  String get llmExplanation => _t('AI 설명', 'AI の説明', 'AI explanation');
  String get expectedMotion => _t('예상 움직임', '予想される動き', 'Expected motion');
  String get disclaimerShort => _t(
        '참고용 추천이며 획득을 보장하지 않습니다. 매장 규정을 지켜 주세요.',
        '参考情報です。獲得を保証するものではありません。店舗ルールを守りましょう。',
        'For reference only. This does not guarantee a win; follow the arcade\'s rules.',
      );

  // Overlay labels
  String get labelFrontBar => _t('앞 봉', '手前バー', 'Front bar (手前バー)');
  String get labelBackBar => _t('안쪽 봉', '奥バー', 'Back bar (奥バー)');
  String get labelClawCenter => _t('집게 중심', 'アーム中心', 'Claw centre');
  String get labelTip => _t('집게발', '爪先', 'Tip');
  String get labelDropHole => _t('출구', '落とし口', 'Drop hole');
  String get labelClaw => _t('집게', 'アーム', 'Claw');
  String get labelPrize => _t('경품', '景品', 'Prize');
  String get labelOtherPrize => _t('다른 경품', 'ほかの景品', 'Other prize');
  String get labelTopFace => _t('윗면', '上面', 'Top face');
  String get labelMotion => _t('예상 이동', '予想の動き', 'Expected motion');
  String get barsEstimated => _t('봉 위치는 추정값', 'バー位置は推定', 'Bars estimated');

  /// Label for the n-th bar in a 3-/4-bar setup (bars 1 and 2 are the
  /// front/back pair).
  String labelExtraBar(int n) => _t('$n번 봉', 'バー$n', 'Bar $n');

  /// Short word next to the curved-arrow glyph on the overlay.
  String labelRotation(ClawRotation r) => switch (r) {
        ClawRotation.clockwise => _t('시계 방향', '時計回り', 'CW'),
        ClawRotation.counterClockwise => _t('반시계 방향', '反時計回り', 'CCW'),
        ClawRotation.none => _t('회전 없음', '回転なし', 'No twist'),
        ClawRotation.unknown => unknown,
      };

  // Claw rotation (observed by the player on the first play)
  String get clawRotationTitle => _t('집게가 도는 방향 (내려갈 때)', 'アームの回転（下降時）', 'Claw twist while descending');
  String get clawRotationHint => _t(
        '첫 판에서 집게가 내려가면서 어느 쪽으로 도는지 보고 고르세요 (위에서 봤을 때 기준)',
        '1手目でアームが下降中にどちらへ回るかを見て選んでください（上から見て）',
        'Watch which way the claw twists while descending on the first play (seen from above)',
      );
  String clawRotationLabel(ClawRotation r) => switch (r) {
        ClawRotation.unknown => _t('모름', '不明', 'Unknown'),
        ClawRotation.none => _t('없음', 'なし', 'None'),
        ClawRotation.clockwise => _t('시계 방향', '時計回り', 'Clockwise'),
        ClawRotation.counterClockwise => _t('반시계 방향', '反時計回り', 'Counter-clockwise'),
      };

  /// Compact chip text for the step card, e.g. "시계" (shown next to a rotation icon).
  String clawRotationShort(ClawRotation r) => switch (r) {
        ClawRotation.clockwise => _t('시계 방향 회전', '時計', 'CW'),
        ClawRotation.counterClockwise => _t('반시계 방향 회전', '反時計', 'CCW'),
        ClawRotation.none => _t('회전 없음', '回転なし', 'No twist'),
        ClawRotation.unknown => unknown,
      };

  // ---------------------------------------------------------------------------
  // Layout-type guide (기초 가이드)

  String get guideTitle => _t('배치 유형 가이드', '設置パターンガイド', 'Layout guide');
  String get guideSubtitle {
    final n = LayoutType.values.length;
    return _t(
      '$n가지 배치를 구별하고, 배치마다 어디를 노리는지 알아보세요',
      '$n種類の設置パターンと狙い方を学ぶ',
      'Recognise $n layouts and learn where to aim at each',
    );
  }

  String get guideOpenThis => _t('이 유형 가이드 보기', 'このパターンのガイドを見る', 'View guide for this layout');
  String get guideAboutLayout => _t('배치 유형 가이드 열기', '設置パターンのガイドを開く', 'Open the layout guide');
  String get guideRecognize => _t('구별하는 법', '見分け方', 'How to recognise it');
  String get guideHowTo => _t('노리는 법', '狙い方', 'How to aim');
  String get guideTechniques => _t('기법', 'テクニック', 'Techniques');
  String get guideTips => _t('팁', 'コツ', 'Tips');
  String get guideAbort => _t('이럴 땐 그만두기', 'こうなったら撤退', 'When to walk away');
  String get guideCost => _t('참고 비용', '参考費用', 'Typical cost');
  String get guideCostNote => _t(
        '★ 표시는 공략 커뮤니티에서 모은 참고값이며, 매장·경품·설정에 따라 크게 달라집니다.',
        '★はコミュニティの参考値で、店舗・景品・設定により大きく異なります。',
        '★ marks community reference figures; they vary widely by store, prize and setting.',
      );

  // Guide motion demo (움직임으로 보기)
  String get guideDemoTitle => _t('움직임으로 보기', '動きで見る', 'See it move');
  String get guideDemoHint => _t(
        '화면을 끌어서 시점을 돌려 볼 수 있습니다. 단계 번호나 이전·다음 버튼을 누르면 그 단계만 다시 보여 줍니다.',
        'ドラッグで回転できます。手順の番号や前・次のボタンをタップすると、その手順だけをもう一度再生します。',
        'Drag to turn the view. Tap a step number or the previous/next buttons to replay just that step.',
      );
  String get guideDemoNote => _t(
        '이해를 돕기 위한 예시 움직임입니다. 실제 움직임은 기계 설정과 경품 무게에 따라 달라집니다.',
        '理解のための動きの例です。実際の動きは機械の設定や景品の重さで変わります。',
        'An illustrative example. Real movement depends on the machine settings and the prize weight.',
      );
  String get guideDemoPlay => _t('재생', '再生', 'Play');
  String get guideDemoPause => _t('일시정지', '一時停止', 'Pause');
  String get guideDemoPrevStep => _t('이전 단계', '前の手順', 'Previous step');
  String get guideDemoNextStep => _t('다음 단계', '次の手順', 'Next step');
  String get guideDemoReplayStep => _t('이 단계 다시 보기', 'この手順をもう一度', 'Replay this step');
  String guideDemoShowStep(int n) => _t('$n단계 장면 보기', '手順$nの場面を見る', 'Show step $n');

  // 3D scene labels and controls
  String get sceneFront => _t('앞쪽', '手前', 'Front (手前)');
  String get resetView => _t('시점 초기화', '視点をリセット', 'Reset view');
  String get playMotion => _t('예상 움직임 재생', '予想の動きを再生', 'Play motion');
  String get pauseMotion => _t('예상 움직임 일시정지', '予想の動きを一時停止', 'Pause motion');

  // Prize sheet
  String get prizeSheetTitle => _t('경품 크기와 위치', '景品の情報と位置', 'Prize size and position');
  String get presetFigureBoxS => _t('피규어 상자 (소)', 'フィギュア箱 小', 'Figure box S');
  String get presetFigureBoxM => _t('피규어 상자 (중)', 'フィギュア箱 中', 'Figure box M');
  String get presetFigureBoxL => _t('피규어 상자 (대)', 'フィギュア箱 大', 'Figure box L');
  String get presetPlush => _t('인형', 'ぬいぐるみ', 'Plush (ぬいぐるみ)');
  String get widthMm => _t('가로 (mm)', '幅 (mm)', 'Width (mm)');
  String get depthMm => _t('깊이 (mm)', '奥行 (mm)', 'Depth (mm)');
  String get heightMm => _t('높이 (mm)', '高さ (mm)', 'Height (mm)');
  String get massG => _t('무게 (g)', '重さ (g)', 'Mass (g)');
  String get boxYOffset => _t('상자 앞뒤 위치 (안쪽 ↔ 앞쪽)', '箱の前後位置（奥寄り ↔ 手前寄り）', 'Box front/back position (奥寄り ↔ 手前寄り)');
  String get towardBack => _t('안쪽', '奥', 'Back (奥)');
  String get towardFront => _t('앞쪽', '手前', 'Front (手前)');
  String get topFaceRatio => _t('윗면 비율', '上面の比率', 'Top-face ratio');
  String get yaw => _t('회전 (위에서 본 각도)', '回転（上から見た角度）', 'Yaw (seen from above)');

  // ---------------------------------------------------------------------------
  // Settings

  String get settingsTitle => _t('설정', '設定', 'Settings');
  String get mockMode => _t('모의 분석 모드', 'モック解析モード', 'Mock analysis mode');
  String get mockModeHint => _t(
        '켜면 서버 대신 앱에 들어 있는 예시 결과(평행한 봉 2개에 걸친 상자)를 보여 줍니다.',
        'オンにするとサーバーの代わりに内蔵サンプル（橋渡し）を使います。',
        'When on, a bundled sample result (橋渡し) is used instead of the server.',
      );
  String get serverUrl => _t('서버 주소', 'サーバーURL', 'Server URL');
  String get serverUrlHint => _t(
        'Android 에뮬레이터에서는 http://10.0.2.2:8080 주소가 PC의 localhost를 가리킵니다.',
        'Androidエミュレータでは http://10.0.2.2:8080 がPCのlocalhostです。',
        'On the Android emulator, http://10.0.2.2:8080 is the PC\'s localhost.',
      );
  String get appKey => _t('앱 키 (X-App-Key)', 'アプリキー (X-App-Key)', 'App key (X-App-Key)');
  String get appKeyHint => _t('비워 두면 보내지 않습니다', '空なら送信しません', 'Left empty, the header is not sent');
  String get language => _t('언어', '言語', 'Language');
  String get defaultPrize => _t('기본 경품 종류', '既定の景品プリセット', 'Default prize preset');
  String get showGuideAgain => _t('촬영 가이드 다시 보기', '撮影ガイドを再表示', 'Show the shooting guide again');
  String get guideRestored => _t('촬영 가이드를 다시 보여 줍니다', 'ガイドを再表示します', 'The guide will be shown again');
  String get about => _t('앱 정보', 'このアプリについて', 'About');
  String get aboutBody => _t(
        'IWantFigure는 크레인 게임 기계 사진을 분석해 어디를 노리면 좋을지 알려 주는 참고용 도구입니다.\n\n'
            '• 추천은 참고용이며 경품 획득을 보장하지 않습니다.\n'
            '• 매장의 촬영·플레이 규정을 꼭 지켜 주세요. 다른 손님이 찍히지 않게 주의하세요.\n'
            '• 사진은 분석할 때만 서버로 보내며, 서버에 원본을 저장하지 않는 것을 원칙으로 합니다.\n'
            '• 기록을 저장하면 사진 사본은 이 기기의 앱 저장 공간에만 보관되고, 기록을 지우면 함께 지워집니다.',
        'IWantFigureはクレーンゲーム（UFOキャッチャー）の写真を解析し、狙い位置を提案する参考用ツールです。\n\n'
            '• 提案は参考情報であり、景品の獲得を保証するものではありません。\n'
            '• 店舗の撮影・プレイのルールを必ず守ってください。他のお客さんが写らないよう注意してください。\n'
            '• 写真は解析のためだけにサーバーへ送信され、原本はサーバーに保存しない方針です。\n'
            '• 記録を保存すると写真のコピーがこの端末のアプリ領域にのみ保存され、記録を削除すると一緒に削除されます。',
        'IWantFigure analyses a photo of a crane game (クレーンゲーム / UFOキャッチャー) and suggests where to aim. It is a reference tool.\n\n'
            '• Suggestions are for reference only and do not guarantee winning a prize.\n'
            '• Always follow the arcade\'s photo and play rules, and keep other customers out of the frame.\n'
            '• Photos are sent to the server only for analysis; originals are not meant to be stored there.\n'
            '• Saving a record keeps a copy of the photo only in this device\'s app storage; deleting the record deletes it too.',
      );
  String get version => _t('버전', 'バージョン', 'Version');

  // ---------------------------------------------------------------------------
  // Enum labels

  String armLabel(Arm arm) => switch (arm) {
        Arm.left => _t('왼쪽 집게', '左アーム', 'Left arm'),
        Arm.right => _t('오른쪽 집게', '右アーム', 'Right arm'),
        Arm.both => _t('양쪽 집게', '両アーム', 'Both arms'),
      };

  String armShort(Arm arm) => switch (arm) {
        Arm.left => _t('왼쪽', '左', 'L'),
        Arm.right => _t('오른쪽', '右', 'R'),
        Arm.both => _t('양쪽', '両方', 'Both'),
      };

  /// Localized layout name; the Japanese community term is appended in
  /// parentheses unless the UI language is Japanese.
  String layoutLabel(LayoutType t) {
    final base = switch (t) {
      LayoutType.bridgeParallel => _t('평행한 봉 2개에 걸친 상자', '橋渡し（平行）', 'Bridge (parallel)'),
      LayoutType.bridgeHanoji => _t('한쪽이 벌어진 봉에 걸친 상자', '橋渡し（末広がり / ハの字）', 'Bridge (flared / ハの字)'),
      LayoutType.bridgeStep => _t('높이가 다르거나 튜브를 씌운 봉', '橋渡し（段差 / ピンクチューブ）', 'Bridge (stepped / tube)'),
      LayoutType.bridgeFour => _t('평행한 봉 4개에 걸친 상자', '橋渡し（4本バー）', 'Bridge (four bars)'),
      LayoutType.bridgeMixed => _t('바깥은 평행, 안쪽은 벌어진 봉 4개', '橋渡し（4本 平行＋ハの字）', 'Bridge (parallel + flared mix)'),
      LayoutType.frontDrop => _t('앞으로 밀어 떨어뜨리는 단', '前落とし', 'Front drop'),
      LayoutType.valleyDrop => _t('가운데 골로 떨어뜨리는 경사판', '谷落とし', 'Valley drop'),
      LayoutType.sideDrop => _t('옆으로 밀어 떨어뜨리는 단', '横落とし', 'Side drop'),
      LayoutType.ringPera => _t('종이 고리가 달린 경품', 'ペラ輪', 'Paper ring'),
      LayoutType.ringD => _t('금속 고리로 봉에 걸린 경품', 'D環 / Oリング', 'D-ring / O-ring'),
      LayoutType.hangString => _t('끈으로 봉에 매달린 경품', '紐吊り', 'Hung on a string'),
      LayoutType.hookS => _t('S자 고리로 걸어 올리기', 'S字フック', 'S-hook'),
      LayoutType.takoyaki => _t('공을 구멍에 넣는 판', 'たこ焼き', 'Takoyaki cups'),
      LayoutType.threeClaw => _t('세 발 집게로 집는 인형', '3本爪 ぬいぐるみ', '3-claw plush'),
      LayoutType.twoClawDirect => _t('두 발 집게로 바로 집는 인형', '2本爪 直取り', '2-claw direct grab'),
      LayoutType.pile => _t('쌓여 있는 작은 경품', '山積み', 'Pile'),
      LayoutType.floorBox => _t('바닥에 놓인 상자', '箱 直置き', 'Box on the floor'),
      LayoutType.unknown => _t('판별 불가', '判別不可', 'Unknown'),
    };
    // Korean screens stay plain Korean; the Japanese name appears once, on
    // the guide page (guideJapaneseName). English keeps it in parentheses.
    if (locale != AppLocale.en || t == LayoutType.unknown) return base;
    return '$base (${t.labelJa})';
  }

  String techniqueLabel(Technique t) {
    final base = switch (t) {
      Technique.tateHame => _t('세워서 떨어뜨리기', '縦ハメ', 'Stand-up wedge'),
      Technique.yokoHame => _t('눕혀서 떨어뜨리기', '横ハメ', 'Sideways wedge'),
      Technique.zurashi => _t('밀어 옮기기', 'ずらし', 'Shift'),
      Technique.yose => _t('끌어당기기', '寄せ', 'Pull'),
      Technique.oshikomi => _t('밀어 넣기', '押し込み', 'Push in'),
      Technique.mochiage => _t('들어 올리기', '持ち上げ', 'Lift'),
      Technique.hikkake => _t('걸어 올리기', '引っ掛け', 'Hook'),
      Technique.noriage => _t('봉 위로 올리기', '乗り上げ', 'Ride up'),
      Technique.tsuki => _t('찔러 넘기기', '突き', 'Poke'),
      Technique.otoshi => _t('떨어뜨리기', '落とし', 'Drop'),
      Technique.nadare => _t('무너뜨리기', '雪崩', 'Avalanche'),
      Technique.kadoOshi => _t('모서리 누르기', '角押し', 'Corner push'),
      Technique.unknown => _t('미정', '未定', 'Undecided'),
    };
    if (locale != AppLocale.en || t == Technique.unknown) return base;
    return '$base (${t.labelJa})';
  }

  String armPowerLabel(ArmPower p) => switch (p) {
        ArmPower.weak => _t('약함', '弱い', 'Weak'),
        ArmPower.medium => _t('보통', '普通', 'Medium'),
        ArmPower.strong => _t('강함', '強い', 'Strong'),
        ArmPower.unknown => unknown,
      };

  String assistLampLabel(AssistLamp l) => switch (l) {
        AssistLamp.none => _t('없음', 'なし', 'None'),
        AssistLamp.blue => _t('파랑', '青', 'Blue'),
        AssistLamp.green => _t('초록', '緑', 'Green'),
        AssistLamp.unknown => unknown,
      };

  String exitSideLabel(ExitSide e) => switch (e) {
        ExitSide.front => _t('앞쪽', '手前', 'Front (手前)'),
        ExitSide.left => _t('왼쪽', '左', 'Left'),
        ExitSide.right => _t('오른쪽', '右', 'Right'),
        ExitSide.back => _t('안쪽', '奥', 'Back (奥)'),
        ExitSide.center => _t('가운데 (봉 사이)', '中央（バーの間）', 'Centre (between bars)'),
        ExitSide.unknown => unknown,
      };

  String observationLabel(ObservationKind k) => switch (k) {
        ObservationKind.noMove => _t('움직이지 않음', '動かず', 'No move'),
        ObservationKind.smallMove => _t('조금 움직임', '少し動いた', 'Small move'),
        ObservationKind.bigMove => _t('많이 움직임', '大きく動いた', 'Big move'),
        ObservationKind.lifted => _t('들어 올려짐', '持ち上がった', 'Lifted'),
        ObservationKind.dropped => _t('떨어짐 (획득)', '落ちた（獲得）', 'Dropped (won)'),
        ObservationKind.stuck => _t('끼임', '詰み', 'Stuck (詰み)'),
      };

  String clawCountLabel(int n) => n <= 0 ? unknown : _t('$n개', '$n本爪', '$n arms');

  String confidencePercent(double c) => '${(c * 100).round()}%';

  String playsAndYen(int plays, int yen) => _t('$plays판 · $yen엔', '$plays回 · $yen円', '$plays plays · ¥$yen');
}
