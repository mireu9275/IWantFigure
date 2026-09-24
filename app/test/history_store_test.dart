import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/inputs.dart';
import 'package:iwantfigure/models/analysis.dart';
import 'package:iwantfigure/services/history_store.dart';

import 'helpers.dart';

void main() {
  test('add / list / delete round-trip with photo copy', () async {
    final dir = tempHistoryDir('store');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = HistoryStore(directory: dir);
    await store.load();
    expect(store.entries, isEmpty);

    final entry = HistoryEntry(
      id: 'a1',
      timestamp: DateTime(2026, 9, 24, 12),
      analysis: sampleAnalysis(),
      photoPath: '',
      imageWidth: 640,
      imageHeight: 480,
      observations: const [Observation(ObservationKind.noMove, playIndex: 1)],
      prize: PrizeSpec.defaultFigureBox.copyWith(massG: 420),
      corrections: const SceneCorrections(
        prizeBbox: NBox(0.1, 0.2, 0.3, 0.4),
        topFaceRatio: 0.4,
        yawDeg: 10,
        boxYOffsetMm: -30,
      ),
      outcome: SessionOutcome.success,
      plays: 4,
      yen: 400,
      locale: 'ja',
    );
    final stored = await store.add(entry, photoBytes: Uint8List.fromList([1, 2, 3]));
    expect(File(stored.photoPath).existsSync(), isTrue);
    expect(await stored.loadPhoto(), [1, 2, 3]);

    final older = HistoryEntry(
      id: 'a0',
      timestamp: DateTime(2026, 9, 23),
      analysis: sampleAnalysis(),
      photoPath: '',
      imageWidth: 1,
      imageHeight: 1,
    );
    await store.add(older);
    expect(store.entries.map((e) => e.id), ['a0', 'a1']);

    final reloaded = HistoryStore(directory: dir);
    await reloaded.load();
    expect(reloaded.entries.map((e) => e.id), ['a1', 'a0']);
    final r = reloaded.entries.first;
    expect(r.outcome, SessionOutcome.success);
    expect(r.plays, 4);
    expect(r.yen, 400);
    expect(r.locale, 'ja');
    expect(r.observations.single.kind, ObservationKind.noMove);
    expect(r.prize.massG, 420);
    expect(r.corrections.prizeBbox, const NBox(0.1, 0.2, 0.3, 0.4));
    expect(r.corrections.topFaceRatio, 0.4);
    expect(r.corrections.yawDeg, 10);
    expect(r.corrections.boxYOffsetMm, -30);
    expect(r.corrections.frontBar, isNull);
    expect(r.analysis.layoutType, LayoutType.bridgeParallel);

    await reloaded.delete('a1');
    expect(reloaded.entries.map((e) => e.id), ['a0']);
    expect(File(stored.photoPath).existsSync(), isFalse);
  });

  test('corrupt file loads as empty', () async {
    final dir = tempHistoryDir('corrupt');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/iwantfigure').createSync();
    File('${dir.path}/iwantfigure/history.json').writeAsStringSync('{{{');
    final store = HistoryStore(directory: dir);
    await store.load();
    expect(store.loaded, isTrue);
    expect(store.entries, isEmpty);
  });
}
