import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/aim_engine.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/services/api_client.dart';
import 'package:iwantfigure/services/history_store.dart';
import 'package:iwantfigure/services/session_controller.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('analyze produces a plan and observations update it', () async {
    final svc = FakeAnalysisService(sampleAnalysis());
    final c = SessionController(photo: await fakePhoto(), service: svc, locale: 'en');
    final states = <SessionState>[];
    c.addListener(() => states.add(c.state));

    await c.analyze();
    expect(c.state, SessionState.ready);
    expect(states, contains(SessionState.analyzing));
    expect(svc.lastLocale, 'en');
    expect(svc.lastHints?.prizeSizeMm, isNull, reason: 'no explicit prize → engine picks a default by kind');
    expect(c.prizeIsExplicit, isFalse);
    expect(c.prize.widthMm, 150);
    final first = c.plan!.currentStepIndex;

    c.addObservation(ObservationKind.smallMove);
    expect(c.plan!.currentStepIndex, first, reason: 'recompute is deferred to a microtask');
    await Future<void>.delayed(Duration.zero);
    expect(c.plan!.currentStepIndex, isNot(first));
    expect(c.observations.single.playIndex, 1);

    c.addObservation(ObservationKind.noMove);
    c.addObservation(ObservationKind.noMove);
    await Future<void>.delayed(Duration.zero);
    expect(c.plan!.armPowerEstimate, ArmPower.weak);

    c.undoObservation();
    c.undoObservation();
    c.undoObservation();
    await Future<void>.delayed(Duration.zero);
    expect(c.observations, isEmpty);
    expect(c.plan!.currentStepIndex, first);

    c.addObservation(ObservationKind.dropped);
    await Future<void>.delayed(Duration.zero);
    expect(c.isFinished, isTrue);
  });

  test('corrections, prize and locale feed the engine', () async {
    final c = SessionController(
      photo: await fakePhoto(),
      service: FakeAnalysisService(sampleAnalysis()),
    );
    await c.analyze();
    c.setCorrections(const SceneCorrections(boxYOffsetMm: -60));
    await Future<void>.delayed(Duration.zero);
    expect(c.plan!.steps.first.technique, Technique.yose);
    expect(c.plan!.scene.boxById('prize')!.pose.position.y, -60);

    c.setPrize(PrizeSpec.defaultFigureBox.copyWith(widthMm: 190, massG: 150));
    await Future<void>.delayed(Duration.zero);
    expect(c.plan!.scene.boxById('prize')!.size.x, 190);

    final koTitle = c.plan!.current!.title;
    c.setLocale('ja');
    await Future<void>.delayed(Duration.zero);
    expect(c.plan!.current!.title, isNot(koTitle));
  });

  test('errors are exposed and a service swap allows retry', () async {
    final failing = FakeAnalysisService(sampleAnalysis(), error: const NetworkException('down'));
    final c = SessionController(photo: await fakePhoto(), service: failing);
    await c.analyze();
    expect(c.state, SessionState.error);
    expect(c.error, isA<NetworkException>());
    expect(c.plan, isNull);

    c.service = FakeAnalysisService(sampleAnalysis());
    await c.analyze();
    expect(c.state, SessionState.ready);
    expect(c.error, isNull);
  });

  test('finish saves to history and reset clears the session', () async {
    final dir = tempHistoryDir('ctl');
    addTearDown(() => dir.deleteSync(recursive: true));
    final history = HistoryStore(directory: dir);
    await history.load();
    final c = SessionController(
      photo: await fakePhoto(),
      service: FakeAnalysisService(sampleAnalysis()),
      history: history,
    );
    await c.analyze();
    c.addObservation(ObservationKind.bigMove);
    c.addObservation(ObservationKind.dropped);
    await Future<void>.delayed(Duration.zero);

    final entry = await c.finish(SessionOutcome.success, yen: 200);
    expect(entry.plays, 2);
    expect(entry.yen, 200);
    expect(entry.outcome, SessionOutcome.success);
    expect(entry.observations.length, 2);
    expect(history.entries.single.id, entry.id);
    expect(await history.entries.single.loadPhoto(), c.photo.bytes);

    c.reset();
    expect(c.state, SessionState.idle);
    expect(c.plan, isNull);
    expect(c.observations, isEmpty);
    expect(c.outcome, SessionOutcome.open);
  });

  test('finish keeps the session unsaved and rethrows when the store fails', () async {
    final dir = tempHistoryDir('ctl_fail');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = ThrowingHistoryStore(dir);
    final c = SessionController(
      photo: await fakePhoto(),
      service: FakeAnalysisService(sampleAnalysis()),
      history: store,
    );
    await c.analyze();
    c.addObservation(ObservationKind.dropped);
    await Future<void>.delayed(Duration.zero);

    await expectLater(
      c.finish(SessionOutcome.success, plays: 3, yen: 300),
      throwsA(isA<FileSystemException>()),
    );
    expect(store.attempts, 1);
    expect(c.isSaved, isFalse);
    expect(c.outcome, SessionOutcome.open);
    expect(c.plays, 0);
    expect(c.yen, 0);
    expect(store.entries, isEmpty);

    // A later successful save commits the outcome.
    final ok = SessionController(
      photo: c.photo,
      service: FakeAnalysisService(sampleAnalysis()),
      history: HistoryStore(directory: dir),
    );
    await ok.analyze();
    await ok.finish(SessionOutcome.fail, plays: 2, yen: 200);
    expect(ok.isSaved, isTrue);
    expect(ok.outcome, SessionOutcome.fail);
  });

  test('a newer analyze() wins over a slower earlier one', () async {
    final slowResult = sampleAnalysis().copyWith(confidence: 0.11);
    final fastResult = sampleAnalysis().copyWith(confidence: 0.99);
    final slow = FakeAnalysisService(slowResult, delay: const Duration(milliseconds: 120));
    final fast = FakeAnalysisService(fastResult);
    final c = SessionController(photo: await fakePhoto(), service: slow);

    final first = c.analyze();
    c.service = fast;
    final second = c.analyze();
    await Future.wait([first, second]);
    expect(c.state, SessionState.ready);
    expect(c.analysis!.confidence, 0.99);
    expect(c.plan!.confidence, 0.99);

    // A stale failure must not flip a fresh result into an error either.
    final failing = FakeAnalysisService(
      slowResult,
      error: const NetworkException('late failure'),
      delay: const Duration(milliseconds: 80),
    );
    c.service = failing;
    final third = c.analyze();
    c.service = fast;
    final fourth = c.analyze();
    await Future.wait([third, fourth]);
    expect(c.state, SessionState.ready);
    expect(c.error, isNull);
    expect(c.analysis!.confidence, 0.99);
  });

  test('history ids are generated locally and never contain the server analysis_id', () async {
    final tainted = AnalysisResult.fromJson({
      ...sampleAnalysis().toJson(),
      'analysis_id': '../../evil',
    });
    final c = SessionController(photo: await fakePhoto(), service: FakeAnalysisService(tainted));
    await c.analyze();
    final id = c.toHistoryEntry().id;
    expect(RegExp(r'^session-\d+-[a-z0-9]+$').hasMatch(id), isTrue, reason: id);
    expect(id.contains('evil'), isFalse);
    expect(SessionController.newSessionId(), isNot(SessionController.newSessionId()));
  });
}
