import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/aim_engine.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/screens/result_screen.dart';
import 'package:iwantfigure/services/history_store.dart';
import 'package:iwantfigure/services/session_controller.dart';
import 'package:iwantfigure/widgets/photo_overlay.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SessionController> readyController({HistoryStore? history}) async {
    final photo = await fakePhoto();
    final c = SessionController(
      photo: photo,
      service: FakeAnalysisService(sampleAnalysis()),
      locale: 'ko',
      history: history,
    );
    await c.analyze();
    expect(c.state, SessionState.ready);
    expect(c.plan, isNotNull);
    return c;
  }

  testWidgets('ResultScreen shows the current step and advances on an observation', (tester) async {
    usePhoneViewport(tester);

    final settings = await loadedSettings();
    final dir = tempHistoryDir('result');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final c = (await tester.runAsync(() => readyController(history: history)))!;
    final s = stringsFor('ko');
    final total = c.plan!.steps.length;
    final first = c.plan!.currentStepIndex + 1;

    await tester.pumpWidget(testApp(
      settings: settings,
      history: history,
      home: ResultScreen(controller: c),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PhotoOverlay), findsOneWidget);
    expect(find.text(s.stepOf(first, total)), findsOneWidget);
    expect(find.text(c.plan!.current!.title), findsWidgets);

    await tester.tap(find.text(s.observationLabel(ObservationKind.smallMove)));
    await tester.pump(); // microtask recompute + rebuild
    await tester.pump(const Duration(milliseconds: 50));

    final next = c.plan!.currentStepIndex + 1;
    expect(next, isNot(first));
    expect(find.text(s.stepOf(next, total)), findsOneWidget);
    expect(c.observations.length, 1);

    // Undo returns to the first step.
    await tester.tap(find.text(s.undo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(s.stepOf(first, total)), findsOneWidget);
    expect(c.observations, isEmpty);
  });

  testWidgets('dropped observation shows the finished banner; done saves to history', (tester) async {
    usePhoneViewport(tester);

    final settings = await loadedSettings();
    final dir = tempHistoryDir('finish');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final c = (await tester.runAsync(() => readyController(history: history)))!;
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(
      settings: settings,
      history: history,
      home: ResultScreen(controller: c),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text(s.observationLabel(ObservationKind.dropped)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.plan!.finished, isTrue);
    expect(find.text(s.finishedBanner), findsOneWidget);

    await tester.tap(find.text(s.done).last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(s.playsCount), findsOneWidget);
    await tester.tap(find.text(s.save));
    await tester.pump();
    // Saving copies the photo to disk: let real IO finish.
    await settleRealIO(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(history.entries.length, 1);
    expect(history.entries.first.outcome, SessionOutcome.success);
    expect(history.entries.first.plays, 1);
    expect(c.isSaved, isTrue);
  });

  testWidgets('tabs switch to 3D and explanation without settling', (tester) async {
    usePhoneViewport(tester);

    final settings = await loadedSettings();
    final dir = tempHistoryDir('tabs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final c = (await tester.runAsync(readyController))!;
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(
      settings: settings,
      history: history,
      home: ResultScreen(controller: c),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    Future<void> switchTab(String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));
    }

    await switchTab(s.tab3d);
    // The (stub or real) SceneView shows the current step as its caption.
    expect(find.text(c.plan!.current!.title), findsWidgets);

    await switchTab(s.tabExplain);
    expect(find.text(s.sectionSummary), findsOneWidget);
    for (final section in [s.sectionRationale, s.sectionSteps, s.sectionAbort, s.sectionMachine]) {
      await tester.dragUntilVisible(
        find.text(section),
        find.byType(ListView),
        const Offset(0, -250),
      );
      expect(find.text(section), findsOneWidget);
    }

    // Correction toggle only exists on the photo tab.
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await switchTab(s.tabPhoto);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(s.correctHint), findsOneWidget);
  });

  testWidgets('read-only session from history hides observation buttons', (tester) async {
    usePhoneViewport(tester);

    final settings = await loadedSettings();
    final dir = tempHistoryDir('readonly');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final photo = (await tester.runAsync(fakePhoto))!;
    final entry = HistoryEntry(
      id: 'e1',
      timestamp: DateTime(2026, 9, 24),
      analysis: sampleAnalysis(),
      photoPath: '',
      imageWidth: photo.width,
      imageHeight: photo.height,
      observations: const [Observation(ObservationKind.smallMove, playIndex: 1)],
      outcome: SessionOutcome.fail,
      plays: 3,
      yen: 300,
    );
    final c = SessionController.fromHistory(entry, photoBytes: photo.bytes);
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(
      settings: settings,
      history: history,
      home: ResultScreen(controller: c),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(s.readOnlyBanner), findsOneWidget);
    expect(find.text(s.observationLabel(ObservationKind.smallMove)), findsNothing);
    expect(c.plan!.currentStepIndex, 1);
  });

  testWidgets('a zoomed photo keeps horizontal pans away from the tab swipe', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final dir = tempHistoryDir('zoom');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final c = (await tester.runAsync(readyController))!;
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(settings: settings, history: history, home: ResultScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));
    final tabs = DefaultTabController.maybeOf(tester.element(find.byType(TabBarView))) ??
        tester.widget<TabBarView>(find.byType(TabBarView)).controller!;

    // Control: without zoom a swipe on the photo switches tabs.
    expect(tabs.index, 0);
    await tester.drag(find.byType(PhotoOverlay), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tabs.index, 1);

    await tester.tap(find.text(s.tabPhoto));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tabs.index, 0);

    // Zoom in, then swipe: the tab must stay put.
    await pinchZoom(tester, find.byType(PhotoOverlay));
    expect(tester.widget<TabBarView>(find.byType(TabBarView)).physics, isA<NeverScrollableScrollPhysics>());
    await tester.drag(find.byType(PhotoOverlay), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tabs.index, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed save shows a snackbar and keeps the result screen', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final dir = tempHistoryDir('savefail');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = ThrowingHistoryStore(dir);
    final c = (await tester.runAsync(() => readyController(history: store)))!;
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(settings: settings, history: store, home: ResultScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(s.observationLabel(ObservationKind.dropped)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text(s.done).last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(s.save));
    await tester.pump();
    await settleRealIO(tester, rounds: 5);
    await tester.pump(const Duration(milliseconds: 300));

    expect(store.attempts, 1);
    expect(c.isSaved, isFalse);
    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.textContaining(s.saveFailed('').trim().replaceAll(':', '')), findsOneWidget);
    expect(find.text(s.savedToHistory), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('3D tab controls and explanation metadata are localized', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings(initial: {'locale': 'en'});
    final dir = tempHistoryDir('labels');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final withMeta = AnalysisResult.fromJson({
      ...sampleAnalysis().toJson(),
      'analysis_id': 'an-42',
      'latency_ms': 1234,
    });
    final photo = (await tester.runAsync(fakePhoto))!;
    final c = SessionController(photo: photo, service: FakeAnalysisService(withMeta), locale: 'en');
    await c.analyze();
    final s = stringsFor('en');

    await tester.pumpWidget(testApp(settings: settings, history: history, home: ResultScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text(s.tab3d));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip(s.resetView), findsOneWidget);
    expect(find.byTooltip(s.pauseMotion), findsOneWidget);

    await tester.tap(find.text(s.tabExplain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.dragUntilVisible(find.text(s.latency), find.byType(ListView), const Offset(0, -250));
    expect(find.text(s.latency), findsOneWidget);
    expect(find.text('1234 ms'), findsOneWidget);
    expect(find.text(s.analysisIdLabel), findsOneWidget);
    expect(find.text('an-42'), findsOneWidget);
  });
}
