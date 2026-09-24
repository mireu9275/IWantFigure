import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/l10n/strings.dart';
import 'package:iwantfigure/screens/analyzing_screen.dart';
import 'package:iwantfigure/screens/result_screen.dart';
import 'package:iwantfigure/services/api_client.dart';
import 'package:iwantfigure/services/history_store.dart';
import 'package:iwantfigure/services/session_controller.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('successful analysis navigates to the ResultScreen', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final dir = tempHistoryDir('an_ok');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final photo = (await tester.runAsync(fakePhoto))!;
    final svc = FakeAnalysisService(sampleAnalysis());
    final c = SessionController(photo: photo, service: svc);
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(settings: settings, history: history, home: AnalyzingScreen(controller: c)));
    expect(find.text(s.analyzingTitle), findsOneWidget);
    expect(find.text(s.stageServer), findsOneWidget);
    await tester.pump(); // post-frame: analyze() starts
    await tester.pump(); // microtasks of the fake service
    await tester.pump(const Duration(milliseconds: 400)); // zero-delay timer + navigation
    await tester.pump(const Duration(milliseconds: 400)); // new route leaves its first offstage frame

    expect(svc.calls, 1);
    expect(c.state, SessionState.ready);
    expect(find.byType(ResultScreen), findsOneWidget);

    // pushReplacement disposes the old route once the page transition ends.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(AnalyzingScreen), findsNothing);
  });

  testWidgets('error card offers Retry and Switch-to-mock', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final dir = tempHistoryDir('an_err');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final photo = (await tester.runAsync(fakePhoto))!;
    final failing = FakeAnalysisService(
      sampleAnalysis(),
      error: const ApiException(401, 'X-App-Key missing', code: ApiException.codeUnauthorized),
    );
    final good = FakeAnalysisService(sampleAnalysis());
    final c = SessionController(photo: photo, service: failing);
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(
      settings: settings,
      history: history,
      service: good, // what AppScope.buildService(forceMock: true) hands out
      home: AnalyzingScreen(controller: c),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(c.state, SessionState.error);
    expect(find.text(s.analyzeFailed), findsOneWidget);
    expect(find.text(s.errorUnauthorized), findsOneWidget);
    expect(find.text(s.retry), findsOneWidget);
    expect(find.text(s.switchToMock), findsOneWidget);

    await tester.tap(find.text(s.retry));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(failing.calls, 2);
    expect(find.text(s.errorUnauthorized), findsOneWidget);
    expect(find.byType(AnalyzingScreen), findsOneWidget);

    await tester.tap(find.text(s.switchToMock));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // zero-delay timer + navigation
    await tester.pump(const Duration(milliseconds: 400)); // new route leaves its first offstage frame
    expect(good.calls, 1);
    expect(identical(c.service, good), isTrue);
    expect(find.byType(ResultScreen), findsOneWidget);
  });

  test('analysisErrorText maps server codes to localized hints', () {
    final s = const S(AppLocale.en);
    expect(analysisErrorText(s, ApiTimeoutException(AnalyzeApi.defaultTimeout)), s.errorTimeout);
    expect(analysisErrorText(s, const NetworkException('x')), s.errorNetwork);
    expect(analysisErrorText(s, const ApiException(0, 'bad json')), s.errorBadResponse);
    expect(
      analysisErrorText(s, const ApiException(401, 'nope', code: 'unauthorized')),
      s.errorUnauthorized,
    );
    expect(analysisErrorText(s, const ApiException(401, 'nope')), s.errorUnauthorized);
    expect(
      analysisErrorText(s, const ApiException(429, 'slow down', code: 'rate_limited')),
      s.errorRateLimited,
    );
    expect(
      analysisErrorText(s, const ApiException(503, 'no key', code: 'provider_not_configured')),
      s.errorProviderNotConfigured,
    );
    expect(
      analysisErrorText(
        s,
        const ApiException(502, 'provider_error', code: 'provider_error', providerMessage: 'overloaded'),
      ),
      s.errorProvider('overloaded'),
    );
    expect(
      analysisErrorText(s, const ApiException(400, 'image too small', code: 'bad_image')),
      s.errorServer(400, 'image too small'),
    );
    expect(analysisErrorText(s, StateError('boom')), contains(s.analyzeFailed));
    for (final locale in AppLocale.values) {
      expect(S(locale).errorTimeout, contains('75'));
    }
  });
}
