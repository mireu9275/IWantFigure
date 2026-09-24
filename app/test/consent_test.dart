import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/services/history_store.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<HistoryStore> history(WidgetTester tester, String name) async {
    final dir = tempHistoryDir(name);
    addTearDown(() => dir.deleteSync(recursive: true));
    final h = HistoryStore(directory: dir);
    await tester.runAsync(h.load);
    return h;
  }

  testWidgets('first launch shows the consent dialog; agreeing persists it', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings(initial: {'consent_given': false, 'mock_mode': false});
    final s = stringsFor('ko');
    await tester.pumpWidget(testApp(settings: settings, history: await history(tester, 'consent1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(s.consentTitle), findsOneWidget);
    expect(find.text(s.consentAgree), findsOneWidget);
    expect(settings.consentGiven, isFalse);

    await tester.tap(find.text(s.consentAgree));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(s.consentTitle), findsNothing);
    expect(settings.consentGiven, isTrue);
    expect(settings.mockMode, isFalse, reason: 'agreeing keeps the configured mode');
  });

  testWidgets('choosing mock-only forces mock mode and does not ask again', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings(initial: {'consent_given': false, 'mock_mode': false, 'locale': 'ja'});
    final s = stringsFor('ja');
    await tester.pumpWidget(testApp(settings: settings, history: await history(tester, 'consent2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(s.consentMockOnly));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(settings.consentGiven, isTrue);
    expect(settings.mockMode, isTrue);
    expect(find.text(s.consentTitle), findsNothing);

    // Tapping "take photo" no longer shows the dialog (the picker is faked and cancels).
    await tester.tap(find.text(s.takePhoto));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(s.consentTitle), findsNothing);
  });

  testWidgets('consent already given → no dialog', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final s = stringsFor('en');
    await tester.pumpWidget(testApp(settings: settings, history: await history(tester, 'consent3')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(s.consentTitle), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
