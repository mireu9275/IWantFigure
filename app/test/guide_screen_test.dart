import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/l10n/guide_content.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/screens/guide_screen.dart';
import 'package:iwantfigure/services/history_store.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final code in ['ko', 'ja', 'en']) {
    testWidgets('GuideScreen lists all ${LayoutType.values.length} layout types in $code and opens a detail',
        (tester) async {
      usePhoneViewport(tester);
      final settings = await loadedSettings(initial: {'locale': code});
      final dir = tempHistoryDir('guide_$code');
      addTearDown(() => dir.deleteSync(recursive: true));
      final history = HistoryStore(directory: dir);
      await tester.runAsync(history.load);
      final s = stringsFor(code);

      await tester.pumpWidget(testApp(settings: settings, history: history, home: const GuideScreen()));
      await tester.pump();

      expect(find.text(s.guideTitle), findsOneWidget);
      // The list holds one tile per layout type (plus the subtitle header).
      final delegate = tester.widget<ListView>(find.byType(ListView)).childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, LayoutType.values.length + 1);
      // Every type has exactly one tile (the list is lazy, so scroll to each).
      for (final type in LayoutType.values) {
        final tile = find.text(s.layoutLabel(type));
        await tester.dragUntilVisible(tile, find.byType(ListView), const Offset(0, -200));
        expect(tile, findsOneWidget, reason: '$type tile');
        expect(find.text(guideFor(type, s).summary), findsOneWidget, reason: '$type summary');
        expect(find.byIcon(layoutIcon(type)), findsWidgets, reason: '$type icon');
        expect(find.byType(ListTile).evaluate().length, lessThanOrEqualTo(LayoutType.values.length));
      }

      // Tap the last tile → detail page with every section.
      const last = LayoutType.unknown;
      await tester.tap(find.text(s.layoutLabel(last)));
      await tester.pumpAndSettle();
      expect(find.byType(GuideDetailScreen), findsOneWidget);
      expect(tester.widget<GuideDetailScreen>(find.byType(GuideDetailScreen)).type, last);
      expect(find.text(s.layoutLabel(last)), findsOneWidget); // app bar
      for (final section in [s.guideRecognize, s.guideHowTo, s.guideTips, s.guideAbort, s.guideCost]) {
        await tester.dragUntilVisible(find.text(section), find.byType(ListView), const Offset(0, -250));
        expect(find.text(section), findsOneWidget, reason: section);
      }
      // Unknown recommends no technique, so that section is absent.
      expect(find.text(s.guideTechniques), findsNothing);
      expect(find.text(guideFor(last, s).typicalCost), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(GuideScreen), findsOneWidget);
    });
  }

  testWidgets('GuideDetailScreen shows technique chips and numbered steps for a bridge', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final dir = tempHistoryDir('guide_detail');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final s = stringsFor('ko');
    const type = LayoutType.bridgeParallel;
    final g = guideFor(type, s);

    await tester.pumpWidget(testApp(
      settings: settings,
      history: history,
      home: const GuideDetailScreen(type: type),
    ));
    await tester.pump();

    expect(find.text(g.summary), findsOneWidget);
    for (var i = 0; i < g.howTo.length; i++) {
      await tester.dragUntilVisible(find.text(g.howTo[i]), find.byType(ListView), const Offset(0, -200));
      expect(find.text(g.howTo[i]), findsOneWidget);
      expect(find.text('${i + 1}'), findsWidgets);
    }
    await tester.dragUntilVisible(find.text(s.guideTechniques), find.byType(ListView), const Offset(0, -200));
    for (final t in g.techniques) {
      expect(find.text(s.techniqueLabel(t)), findsOneWidget, reason: '$t chip');
    }
    for (final a in g.abortWhen) {
      await tester.dragUntilVisible(find.text(a), find.byType(ListView), const Offset(0, -200));
      expect(find.text(a), findsOneWidget);
    }
    await tester.dragUntilVisible(find.text(s.disclaimerShort), find.byType(ListView), const Offset(0, -200));
    expect(find.text(s.disclaimerShort), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every layout type renders a detail page without exceptions', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings(initial: {'locale': 'ja'});
    final dir = tempHistoryDir('guide_all');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final s = stringsFor('ja');

    for (final type in LayoutType.values) {
      await tester.pumpWidget(testApp(
        settings: settings,
        history: history,
        home: GuideDetailScreen(type: type),
      ));
      await tester.pump();
      expect(find.text(s.layoutLabel(type)), findsOneWidget, reason: '$type title');
      expect(find.text(s.guideRecognize), findsOneWidget, reason: '$type');
      expect(tester.takeException(), isNull, reason: '$type');
    }
  });

  testWidgets('HomeScreen has a layout-guide card that opens GuideScreen', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final dir = tempHistoryDir('guide_home');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(settings: settings, history: history));
    await tester.pump();
    await tester.dragUntilVisible(find.text(s.guideTitle), find.byType(ListView), const Offset(0, -200));
    expect(find.text(s.guideTitle), findsOneWidget);
    expect(find.text(s.guideSubtitle), findsOneWidget);

    await tester.tap(find.text(s.guideTitle));
    await tester.pumpAndSettle();
    expect(find.byType(GuideScreen), findsOneWidget);
    expect(find.text(s.layoutLabel(LayoutType.bridgeParallel)), findsOneWidget);

    // The card is there even when the shooting guide is hidden.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await settings.setShowShootingGuide(false);
    await tester.pump();
    expect(find.text(s.shootingGuideTitle), findsNothing);
    expect(find.text(s.guideTitle), findsOneWidget);
  });
}
