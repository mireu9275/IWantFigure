import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/screens/home_screen.dart';
import 'package:iwantfigure/screens/settings_screen.dart';
import 'package:iwantfigure/services/history_store.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final code in ['ko', 'ja', 'en']) {
    testWidgets('HomeScreen renders the main buttons in $code', (tester) async {
      final settings = await loadedSettings(initial: {'locale': code});
      final dir = tempHistoryDir(code);
      addTearDown(() => dir.deleteSync(recursive: true));
      final history = HistoryStore(directory: dir);
      await history.load();
      final s = stringsFor(code);

      await tester.pumpWidget(testApp(settings: settings, history: history));
      await tester.pump();

      expect(find.text(s.takePhoto), findsOneWidget);
      expect(find.text(s.pickFromGallery), findsOneWidget);
      expect(find.text(s.shootingGuideTitle), findsOneWidget);
      expect(find.text(s.mockModeChip), findsOneWidget);
      expect(find.text(s.historyEmpty), findsOneWidget);
      // Each guide bullet is rendered.
      for (final item in s.shootingGuideItems) {
        expect(find.text(item), findsOneWidget);
      }
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  }

  testWidgets('hide-guide button hides the card and persists', (tester) async {
    final settings = await loadedSettings();
    final dir = tempHistoryDir('guide');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await history.load();
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(settings: settings, history: history));
    await tester.pump();
    await tester.tap(find.text(s.hideGuide));
    await tester.pump();

    expect(find.text(s.shootingGuideTitle), findsNothing);
    expect(settings.showShootingGuide, isFalse);
  });

  testWidgets('settings icon opens SettingsScreen and language switch re-renders home', (tester) async {
    final settings = await loadedSettings();
    final dir = tempHistoryDir('settings');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await history.load();

    await tester.pumpWidget(testApp(settings: settings, history: history));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(settings.locale.code, 'en');
    expect(find.text(stringsFor('en').settingsTitle), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(stringsFor('en').takePhoto), findsOneWidget);
  });

  testWidgets('cancelled picker leaves the home screen in place', (tester) async {
    final settings = await loadedSettings();
    final dir = tempHistoryDir('cancel');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await history.load();
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(settings: settings, history: history));
    await tester.pump();
    await tester.tap(find.text(s.takePhoto));
    await tester.pump();
    await tester.pump();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
