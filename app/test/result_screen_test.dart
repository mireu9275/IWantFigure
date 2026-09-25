import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/aim_engine.dart';
import 'package:iwantfigure/l10n/guide_content.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/screens/guide_screen.dart';
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
    await tester.fling(find.byType(PhotoOverlay), const Offset(-400, 0), 3000);
    // The page spring settles slowly and the index updates on scroll end;
    // pump fixed durations (tab 2 hosts the endlessly animating SceneView).
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(tabs.index, 1);

    await tester.tap(find.text(s.tabPhoto));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tabs.index, 0);

    // Zoom in, then swipe: the tab must stay put (the pan moves the photo).
    await pinchZoom(tester, find.byType(PhotoOverlay));
    expect(tester.widget<TabBarView>(find.byType(TabBarView)).physics, isA<NeverScrollableScrollPhysics>());
    await tester.fling(find.byType(PhotoOverlay), const Offset(-300, 0), 1500);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tabs.index, 0);
    expect(tabs.offset, 0);
    await tester.drag(find.byType(PhotoOverlay), const Offset(-120, 0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tabs.index, 0);
    expect(tabs.offset, 0);
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
    // analyze() awaits a zero-delay timer: run it outside the fake-async zone.
    await tester.runAsync(c.analyze);
    expect(c.state, SessionState.ready);
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

  /// Pushes a route and lets the transition finish without `pumpAndSettle`
  /// (the result screen hosts an endlessly animating 3D view).
  Future<void> pumpTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('a mock result says the photo was not analysed; a real one does not', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final dir = tempHistoryDir('mock_banner');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final s = stringsFor('ko');
    final photo = (await tester.runAsync(fakePhoto))!;

    for (final provider in ['mock', 'gemini']) {
      final json = jsonDecode(sampleJsonText()) as Map<String, dynamic>;
      json['provider'] = provider;
      final c = SessionController(photo: photo, service: FakeAnalysisService(AnalysisResult.fromJson(json)), locale: 'ko');
      await tester.runAsync(c.analyze);
      await tester.pumpWidget(testApp(settings: settings, history: history, home: ResultScreen(controller: c)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(s.mockResultBanner), provider == 'mock' ? findsOneWidget : findsNothing, reason: provider);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('tapping the layout title opens the guide for that layout', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final dir = tempHistoryDir('title_guide');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final c = (await tester.runAsync(readyController))!;
    final s = stringsFor('ko');
    final type = c.plan!.layoutType;

    await tester.pumpWidget(testApp(settings: settings, history: history, home: ResultScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));

    // The title is a button with an info icon.
    expect(find.byTooltip(s.guideAboutLayout), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.text(s.layoutLabel(type)), findsOneWidget);
    await tester.tap(find.text(s.layoutLabel(type)));
    await pumpTransition(tester);

    expect(find.byType(GuideDetailScreen), findsOneWidget);
    expect(tester.widget<GuideDetailScreen>(find.byType(GuideDetailScreen)).type, type);
    expect(find.text(guideFor(type, s).summary), findsOneWidget);
    // The motion demo sits above the text, so scroll down to the sections.
    await scrollPageTo(tester, find.text(s.guideRecognize));
    expect(find.text(s.guideRecognize), findsOneWidget);
    await scrollPageTo(tester, find.text(s.guideHowTo));
    expect(find.text(s.guideHowTo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('claw rotation selector updates the corrections, the plan and the step card', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final dir = tempHistoryDir('rotation');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final c = (await tester.runAsync(readyController))!;
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(settings: settings, history: history, home: ResultScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(c.corrections.clawRotation, ClawRotation.unknown);
    expect(c.plan!.clawRotation, ClawRotation.unknown);
    expect(find.text(s.clawRotationTitle), findsOneWidget);
    for (final r in ClawRotation.values) {
      expect(find.text(s.clawRotationLabel(r)), findsOneWidget, reason: '$r chip');
    }
    expect(find.text(s.clawRotationShort(ClawRotation.clockwise)), findsNothing);
    // Unknown twist → the engine asks the player to observe it.
    expect(c.plan!.warnings.any((w) => w.contains('시계')), isTrue);
    final stepIndex = c.plan!.steps.indexWhere((st) => st.arm != Arm.both);
    expect(stepIndex, greaterThanOrEqualTo(0));
    final before = c.plan!.steps[stepIndex].clawPoint;

    await tester.tap(find.text(s.clawRotationLabel(ClawRotation.clockwise)));
    await tester.pump(); // microtask recompute
    await tester.pump(const Duration(milliseconds: 50));

    expect(c.corrections.clawRotation, ClawRotation.clockwise);
    expect(c.plan!.clawRotation, ClawRotation.clockwise);
    // The claw centre moved to compensate for the twist; the chip appears on
    // the step card and the rationale explains it.
    expect(c.plan!.steps[stepIndex].clawPoint, isNot(before));
    expect(find.text(s.clawRotationShort(ClawRotation.clockwise)), findsOneWidget);
    expect(c.plan!.rationale.any((r) => r.contains('시계')), isTrue);
    expect(c.plan!.warnings.any((w) => w.contains('시계')), isFalse);

    // Counter-clockwise swaps the chip; "none" removes it and the warning.
    await tester.tap(find.text(s.clawRotationLabel(ClawRotation.counterClockwise)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.plan!.clawRotation, ClawRotation.counterClockwise);
    expect(find.text(s.clawRotationShort(ClawRotation.counterClockwise)), findsOneWidget);
    expect(find.text(s.clawRotationShort(ClawRotation.clockwise)), findsNothing);

    await tester.tap(find.text(s.clawRotationLabel(ClawRotation.none)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.corrections.clawRotation, ClawRotation.none);
    expect(c.plan!.clawRotation, ClawRotation.none);
    expect(c.plan!.steps[stepIndex].clawPoint, before);
    expect(find.text(s.clawRotationShort(ClawRotation.counterClockwise)), findsNothing);
    expect(c.plan!.warnings.any((w) => w.contains('시계')), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('geometry reset in edit mode keeps the observed claw rotation', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings();
    final dir = tempHistoryDir('reset_rotation');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final c = (await tester.runAsync(readyController))!;
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(settings: settings, history: history, home: ResultScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text(s.clawRotationLabel(ClawRotation.clockwise)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    c.setCorrections(c.corrections.copyWith(yawDeg: 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(s.correctHint), findsOneWidget);
    await tester.tap(find.text(s.reset));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(c.corrections.yawDeg, isNull);
    expect(c.corrections.clawRotation, ClawRotation.clockwise);
    expect(c.plan!.clawRotation, ClawRotation.clockwise);
  });

  testWidgets('explanation tab links to the guide for this layout and lists the twist', (tester) async {
    usePhoneViewport(tester);
    final settings = await loadedSettings(initial: {'locale': 'en'});
    final dir = tempHistoryDir('explain_guide');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await tester.runAsync(history.load);
    final photo = (await tester.runAsync(fakePhoto))!;
    final c = SessionController(photo: photo, service: FakeAnalysisService(sampleAnalysis()), locale: 'en');
    await tester.runAsync(c.analyze);
    expect(c.state, SessionState.ready);
    final s = stringsFor('en');
    final type = c.plan!.layoutType;

    await tester.pumpWidget(testApp(settings: settings, history: history, home: ResultScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(s.tabExplain));
    await pumpTransition(tester);

    expect(find.text(s.guideOpenThis), findsOneWidget);
    // The machine section shows the twist value next to the selector's copy
    // in the bottom panel.
    await tester.dragUntilVisible(find.text(s.sectionMachine), find.byType(ListView), const Offset(0, -250));
    expect(find.text(s.clawRotationTitle), findsNWidgets(2));
    // The summary card (with the button) has scrolled out of the lazy list:
    // scroll back to the top before tapping.
    await tester.drag(find.byType(ListView), const Offset(0, 3000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(s.guideOpenThis), findsOneWidget);
    expect(tester.getRect(find.text(s.guideOpenThis)).top, greaterThanOrEqualTo(0));

    await tester.tap(find.text(s.guideOpenThis));
    await pumpTransition(tester);
    expect(find.byType(GuideDetailScreen), findsOneWidget);
    expect(tester.widget<GuideDetailScreen>(find.byType(GuideDetailScreen)).type, type);
    // The motion demo sits above the text, so scroll down to the steps.
    await scrollPageTo(tester, find.text(s.guideHowTo));
    expect(find.text(s.guideHowTo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
