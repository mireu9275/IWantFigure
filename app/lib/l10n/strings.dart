/// Map-free, switch-based localization for the app UI.
///
/// Every user-visible string lives here so that the rest of the code never
/// hard-codes Korean/Japanese/English text. Japanese arcade terms are kept in
/// parentheses where players actually use them (縦ハメ, 橋渡し, 手前バー …).
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
        '크레인게임(クレーンゲーム) 사진을 찍으면 어디를 노릴지 추천합니다',
        'クレーンゲームの写真から「どこを狙うか」を提案します',
        'Photograph a crane game (クレーンゲーム) and get a suggested aim point',
      );
  String get takePhoto => _t('촬영', '撮影', 'Camera');
  String get pickFromGallery => _t('갤러리', 'ギャラリー', 'Gallery');
  String get mockModeChip => _t('모의 분석 모드', 'モック解析モード', 'Mock analysis');
  String get mockModeChipHint => _t(
        '서버 없이 샘플 결과를 사용합니다. 설정에서 변경할 수 있습니다.',
        'サーバーなしでサンプル結果を使います。設定で変更できます。',
        'Uses a bundled sample result instead of a server. Change it in Settings.',
      );
  String get shootingGuideTitle => _t('촬영 가이드', '撮影ガイド', 'Shooting guide');
  List<String> get shootingGuideItems => [
        _t('유리에 밀착해서 반사를 줄이세요', 'ガラスに密着させて反射を減らす', 'Hold the phone against the glass to reduce reflections'),
        _t('기계 정면에서, 수평을 맞춰 찍으세요', '筐体の正面から、水平に撮る', 'Shoot from the front of the cabinet, level with the floor'),
        _t('아암(アーム)과 바(バー)가 모두 보이게', 'アームとバーが両方写るように', 'Keep both the claw (アーム) and the bars (バー) in frame'),
        _t('다른 손님의 얼굴이 나오지 않게 하세요', '他のお客さんの顔が写らないように', 'Do not capture other customers\' faces'),
        _t('매장의 촬영 규정을 먼저 확인하세요', '店舗の撮影ルールを先に確認', 'Check the arcade\'s photo rules first'),
        _t('대기자가 있으면 1게임 안에 마치세요', '待っている人がいれば1ゲーム以内で', 'If others are waiting, finish within one game'),
        _t('사진 1장이면 충분합니다 (빠른 분석)', '写真は1枚で十分です（すばやく解析）', 'One photo is enough (quick analysis)'),
      ];
  String get hideGuide => _t('가이드 숨기기', 'ガイドを隠す', 'Hide guide');
  String get historyTitle => _t('지난 기록', '履歴', 'History');
  String get historyEmpty => _t(
        '아직 기록이 없습니다. 사진을 찍어 시작하세요.',
        'まだ履歴がありません。写真を撮って始めましょう。',
        'No sessions yet. Take a photo to start.',
      );
  String get deleteHistoryTitle => _t('기록을 삭제할까요?', '履歴を削除しますか？', 'Delete this record?');
  String get pickFailed => _t('사진을 불러오지 못했습니다', '写真を読み込めませんでした', 'Could not load the photo');

  // ---------------------------------------------------------------------------
  // Analyzing

  String get analyzingTitle => _t('분석 중', '解析中', 'Analyzing');
  String get stagePrepare => _t('사진 준비', '写真を準備', 'Preparing photo');
  String get stageServer => _t('서버 분석', 'サーバーで解析', 'Server analysis');
  String get stageAim => _t('조준 계산', '狙いを計算', 'Computing aim');
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
      '서버 응답이 너무 늦습니다 ($sec초 초과).',
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
        '서버에 분석 제공자(LLM)가 설정되어 있지 않습니다. 서버 관리자에게 문의하거나 모의 모드를 사용하세요.',
        'サーバーに解析プロバイダ (LLM) が設定されていません。サーバー管理者に確認するか、モックモードを使ってください。',
        'The server has no analysis provider (LLM) configured. Contact the server admin or use mock mode.',
      );
  String errorProvider(String detail) => _t(
        '분석 제공자 오류: $detail',
        '解析プロバイダのエラー: $detail',
        'Analysis provider error: $detail',
      );
  String get errorBadResponse => _t(
        '서버 응답을 해석할 수 없습니다.',
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
        '모서리·바·윗면 경계를 끌어서 맞추세요',
        '角・バー・上面の境界をドラッグして合わせてください',
        'Drag the corners, bars and top-face edge to match the photo',
      );
  String get prizeInfo => _t('경품 정보', '景品情報', 'Prize');
  String get currentStep => _t('이번 플레이', '今回のプレイ', 'This play');
  String stepOf(int index, int total) => _t('$index/$total 수', '$index/$total 手目', 'Step $index/$total');
  String get afterPlay => _t('플레이 후 결과는?', 'プレイ後の結果は？', 'What happened after the play?');
  String get finishedBanner => _t(
        '경품이 떨어졌습니다! 완료를 눌러 기록을 저장하세요.',
        '景品が落ちました！「完了」を押して記録を保存しましょう。',
        'The prize dropped! Tap Done to save the record.',
      );
  String get giveUp => _t('실패/포기', '失敗/あきらめる', 'Fail / give up');
  String get noPlanTitle => _t('조준점을 계산하지 못했습니다', '狙い位置を計算できませんでした', 'Could not compute an aim point');
  String get playsCount => _t('플레이 횟수', 'プレイ回数', 'Number of plays');
  String get yenSpent => _t('사용 금액 (엔)', '使った金額（円）', 'Amount spent (yen)');
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
  String get sectionRationale => _t('왜 이 지점인가', 'なぜこの位置か', 'Why this point');
  String get sectionSteps => _t('플레이 순서', 'プレイ手順', 'Play sequence');
  String get sectionAbort => _t('철수 조건', '撤退条件', 'When to stop');
  String get sectionWarnings => _t('주의', '注意', 'Warnings');
  String get sectionRequestedPhotos => _t('추가로 필요한 사진', '追加で必要な写真', 'More photos requested');
  String get sectionMachine => _t('기계 정보', '筐体情報', 'Machine');
  String get sectionAnalysis => _t('분석 정보', '解析情報', 'Analysis');
  String get clawCount => _t('아암 수', 'アーム数', 'Claw arms');
  String get armPower => _t('아암 파워', 'アームパワー', 'Arm power');
  String get assistLamp => _t('어시스트 램프', 'アシストランプ', 'Assist lamp');
  String get exitSide => _t('낙하구 방향', '落とし口の位置', 'Exit side');
  String get provider => _t('분석 제공자', '解析プロバイダ', 'Provider');
  String get latency => _t('응답 시간', '応答時間', 'Latency');
  String get analysisIdLabel => _t('분석 ID', '解析ID', 'Analysis ID');
  String get llmExplanation => _t('AI 설명', 'AI の説明', 'AI explanation');
  String get expectedMotion => _t('예상 움직임', '予想される動き', 'Expected motion');
  String get disclaimerShort => _t(
        '참고용 추천입니다. 획득을 보장하지 않으며 매장 규정을 지켜 주세요.',
        '参考情報です。獲得を保証するものではありません。店舗ルールを守りましょう。',
        'For reference only. This does not guarantee a win; follow the arcade\'s rules.',
      );

  // Overlay labels
  String get labelFrontBar => _t('앞 바 (手前バー)', '手前バー', 'Front bar (手前バー)');
  String get labelBackBar => _t('뒤 바 (奥バー)', '奥バー', 'Back bar (奥バー)');
  String get labelClawCenter => _t('아암 중심', 'アーム中心', 'Claw centre');
  String get labelTip => _t('발톱', '爪先', 'Tip');
  String get labelDropHole => _t('낙하구', '落とし口', 'Drop hole');
  String get labelClaw => _t('아암', 'アーム', 'Claw');
  String get labelPrize => _t('경품', '景品', 'Prize');
  String get labelTopFace => _t('윗면', '上面', 'Top face');
  String get labelMotion => _t('예상 이동', '予想の動き', 'Expected motion');
  String get barsEstimated => _t('바 위치 추정됨', 'バー位置は推定', 'Bars estimated');

  // 3D scene labels and controls
  String get sceneFront => _t('앞 (手前)', '手前', 'Front (手前)');
  String get resetView => _t('시점 초기화', '視点をリセット', 'Reset view');
  String get playMotion => _t('예상 움직임 재생', '予想の動きを再生', 'Play motion');
  String get pauseMotion => _t('예상 움직임 일시정지', '予想の動きを一時停止', 'Pause motion');

  // Prize sheet
  String get prizeSheetTitle => _t('경품 정보와 위치', '景品の情報と位置', 'Prize size and position');
  String get presetFigureBoxS => _t('피규어 박스 소', 'フィギュア箱 小', 'Figure box S');
  String get presetFigureBoxM => _t('피규어 박스 중', 'フィギュア箱 中', 'Figure box M');
  String get presetFigureBoxL => _t('피규어 박스 대', 'フィギュア箱 大', 'Figure box L');
  String get presetPlush => _t('인형 (ぬいぐるみ)', 'ぬいぐるみ', 'Plush (ぬいぐるみ)');
  String get widthMm => _t('가로 (mm)', '幅 (mm)', 'Width (mm)');
  String get depthMm => _t('세로/깊이 (mm)', '奥行 (mm)', 'Depth (mm)');
  String get heightMm => _t('높이 (mm)', '高さ (mm)', 'Height (mm)');
  String get massG => _t('무게 (g)', '重さ (g)', 'Mass (g)');
  String get boxYOffset => _t('박스 앞/뒤 위치 (奥寄り ↔ 手前寄り)', '箱の前後位置（奥寄り ↔ 手前寄り）', 'Box front/back position (奥寄り ↔ 手前寄り)');
  String get towardBack => _t('안쪽 (奥)', '奥', 'Back (奥)');
  String get towardFront => _t('앞쪽 (手前)', '手前', 'Front (手前)');
  String get topFaceRatio => _t('윗면 비율', '上面の比率', 'Top-face ratio');
  String get yaw => _t('회전 (위에서 본 각도)', '回転（上から見た角度）', 'Yaw (seen from above)');

  // ---------------------------------------------------------------------------
  // Settings

  String get settingsTitle => _t('설정', '設定', 'Settings');
  String get mockMode => _t('모의 분석 모드', 'モック解析モード', 'Mock analysis mode');
  String get mockModeHint => _t(
        '켜면 서버 대신 내장 샘플 결과(橋渡し)를 사용합니다.',
        'オンにするとサーバーの代わりに内蔵サンプル（橋渡し）を使います。',
        'When on, a bundled sample result (橋渡し) is used instead of the server.',
      );
  String get serverUrl => _t('서버 주소', 'サーバーURL', 'Server URL');
  String get serverUrlHint => _t(
        'Android 에뮬레이터에서는 http://10.0.2.2:8080 이 PC의 localhost입니다.',
        'Androidエミュレータでは http://10.0.2.2:8080 がPCのlocalhostです。',
        'On the Android emulator, http://10.0.2.2:8080 is the PC\'s localhost.',
      );
  String get appKey => _t('앱 키 (X-App-Key)', 'アプリキー (X-App-Key)', 'App key (X-App-Key)');
  String get appKeyHint => _t('비워 두면 보내지 않습니다', '空なら送信しません', 'Left empty, the header is not sent');
  String get language => _t('언어', '言語', 'Language');
  String get defaultPrize => _t('기본 경품 프리셋', '既定の景品プリセット', 'Default prize preset');
  String get showGuideAgain => _t('촬영 가이드 다시 보기', '撮影ガイドを再表示', 'Show the shooting guide again');
  String get guideRestored => _t('가이드가 다시 표시됩니다', 'ガイドを再表示します', 'The guide will be shown again');
  String get about => _t('정보', 'このアプリについて', 'About');
  String get aboutBody => _t(
        'IWantFigure는 크레인게임(クレーンゲーム / UFOキャッチャー) 사진을 분석해 조준 위치를 제안하는 참고용 도구입니다.\n\n'
            '• 추천은 참고용이며 경품 획득을 보장하지 않습니다.\n'
            '• 매장의 촬영·플레이 규정을 반드시 지켜 주세요. 다른 손님이 찍히지 않도록 주의하세요.\n'
            '• 사진은 분석을 위해서만 서버로 전송되며 원본은 서버에 저장하지 않는 것을 원칙으로 합니다.\n'
            '• 기록을 저장하면 사진 사본이 이 기기의 앱 저장 공간에만 보관되며, 기록을 삭제하면 함께 삭제됩니다.',
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
        Arm.left => _t('왼쪽 아암', '左アーム', 'Left arm'),
        Arm.right => _t('오른쪽 아암', '右アーム', 'Right arm'),
        Arm.both => _t('양쪽 아암', '両アーム', 'Both arms'),
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
      LayoutType.bridgeParallel => _t('다리 걸치기 (평행)', '橋渡し（平行）', 'Bridge (parallel)'),
      LayoutType.bridgeHanoji => _t('다리 걸치기 (八자)', '橋渡し（末広がり / ハの字）', 'Bridge (flared / ハの字)'),
      LayoutType.bridgeStep => _t('다리 걸치기 (단차/튜브)', '橋渡し（段差 / ピンクチューブ）', 'Bridge (stepped / tube)'),
      LayoutType.frontDrop => _t('앞 낙하', '前落とし', 'Front drop'),
      LayoutType.valleyDrop => _t('골 낙하', '谷落とし', 'Valley drop'),
      LayoutType.sideDrop => _t('옆 낙하', '横落とし', 'Side drop'),
      LayoutType.ringPera => _t('종이 고리', 'ペラ輪', 'Paper ring'),
      LayoutType.ringD => _t('D링 / O링', 'D環 / Oリング', 'D-ring / O-ring'),
      LayoutType.hookS => _t('S자 훅', 'S字フック', 'S-hook'),
      LayoutType.takoyaki => _t('타코야키 (구슬 컵)', 'たこ焼き', 'Takoyaki cups'),
      LayoutType.threeClaw => _t('3발 인형', '3本爪 ぬいぐるみ', '3-claw plush'),
      LayoutType.twoClawDirect => _t('2발 직접 집기', '2本爪 直取り', '2-claw direct grab'),
      LayoutType.pile => _t('산더미', '山積み', 'Pile'),
      LayoutType.floorBox => _t('바닥 직치 박스', '箱 直置き', 'Box on the floor'),
      LayoutType.unknown => _t('판별 불가', '判別不可', 'Unknown'),
    };
    if (locale == AppLocale.ja || t == LayoutType.unknown) return base;
    return '$base (${t.labelJa})';
  }

  String techniqueLabel(Technique t) {
    final base = switch (t) {
      Technique.tateHame => _t('세로 끼우기', '縦ハメ', 'Stand-up wedge'),
      Technique.yokoHame => _t('가로 끼우기', '横ハメ', 'Sideways wedge'),
      Technique.zurashi => _t('밀어 옮기기', 'ずらし', 'Shift'),
      Technique.yose => _t('끌어당기기', '寄せ', 'Pull'),
      Technique.oshikomi => _t('밀어 넣기', '押し込み', 'Push in'),
      Technique.mochiage => _t('들어 올리기', '持ち上げ', 'Lift'),
      Technique.hikkake => _t('걸기', '引っ掛け', 'Hook'),
      Technique.noriage => _t('바 위로 올리기', '乗り上げ', 'Ride up'),
      Technique.tsuki => _t('찌르기', '突き', 'Poke'),
      Technique.otoshi => _t('떨어뜨리기', '落とし', 'Drop'),
      Technique.nadare => _t('무너뜨리기', '雪崩', 'Avalanche'),
      Technique.kadoOshi => _t('모서리 누르기', '角押し', 'Corner push'),
      Technique.unknown => _t('미정', '未定', 'Undecided'),
    };
    if (locale == AppLocale.ja || t == Technique.unknown) return base;
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
        ExitSide.front => _t('앞 (手前)', '手前', 'Front (手前)'),
        ExitSide.left => _t('왼쪽', '左', 'Left'),
        ExitSide.right => _t('오른쪽', '右', 'Right'),
        ExitSide.back => _t('뒤 (奥)', '奥', 'Back (奥)'),
        ExitSide.center => _t('가운데 (바 사이)', '中央（バーの間）', 'Centre (between bars)'),
        ExitSide.unknown => unknown,
      };

  String observationLabel(ObservationKind k) => switch (k) {
        ObservationKind.noMove => _t('안 움직임', '動かず', 'No move'),
        ObservationKind.smallMove => _t('조금 움직임', '少し動いた', 'Small move'),
        ObservationKind.bigMove => _t('많이 움직임', '大きく動いた', 'Big move'),
        ObservationKind.lifted => _t('떴다', '持ち上がった', 'Lifted'),
        ObservationKind.dropped => _t('떨어짐 (획득)', '落ちた（獲得）', 'Dropped (won)'),
        ObservationKind.stuck => _t('막힘 (詰み)', '詰み', 'Stuck (詰み)'),
      };

  String clawCountLabel(int n) => n <= 0 ? unknown : _t('$n발', '$n本爪', '$n arms');

  String confidencePercent(double c) => '${(c * 100).round()}%';

  String playsAndYen(int plays, int yen) => _t('$plays회 · $yen엔', '$plays回 · $yen円', '$plays plays · ¥$yen');
}
