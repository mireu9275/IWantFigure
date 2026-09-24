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
}
