import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/aim_engine.dart';
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
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final settings = await loadedSettings();
    final dir = tempHistoryDir('result');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await history.load();
    final c = await readyController(history: history);
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
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final settings = await loadedSettings();
    final dir = tempHistoryDir('finish');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await history.load();
    final c = await readyController(history: history);
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
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(history.entries.length, 1);
    expect(history.entries.first.outcome, SessionOutcome.success);
    expect(history.entries.first.plays, 1);
    expect(c.isSaved, isTrue);
  });

  testWidgets('tabs switch to 3D and explanation without settling', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final settings = await loadedSettings();
    final dir = tempHistoryDir('tabs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await history.load();
    final c = await readyController();
    final s = stringsFor('ko');

    await tester.pumpWidget(testApp(
      settings: settings,
      history: history,
      home: ResultScreen(controller: c),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text(s.tab3d));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(s.tabExplain));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(s.sectionRationale), findsOneWidget);
    expect(find.text(s.sectionSteps), findsOneWidget);
    expect(find.text(s.sectionMachine), findsOneWidget);

    // Correction toggle only exists on the photo tab.
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    await tester.tap(find.text(s.tabPhoto));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(s.correctHint), findsOneWidget);
  });

  testWidgets('read-only session from history hides observation buttons', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final settings = await loadedSettings();
    final dir = tempHistoryDir('readonly');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await history.load();
    final photo = await fakePhoto();
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
}
