import 'dart:convert';
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

  test('corrupt file loads as empty, is moved aside and never overwritten', () async {
    final dir = tempHistoryDir('corrupt');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/iwantfigure').createSync();
    final file = File('${dir.path}/iwantfigure/history.json');
    const garbage = '{{{ truncated';
    file.writeAsStringSync(garbage);
    final store = HistoryStore(directory: dir);
    await store.load();
    expect(store.loaded, isTrue);
    expect(store.entries, isEmpty);

    final backup = File('${dir.path}/iwantfigure/history.json.bak');
    expect(backup.existsSync(), isTrue, reason: 'corrupt file is kept as .bak');
    expect(backup.readAsStringSync(), garbage);
    expect(file.existsSync(), isFalse);

    // Adding afterwards writes a fresh file and leaves the backup untouched.
    await store.add(HistoryEntry(
      id: 'n1',
      timestamp: DateTime(2026, 9, 24),
      analysis: sampleAnalysis(),
      photoPath: '',
      imageWidth: 1,
      imageHeight: 1,
    ));
    expect(backup.readAsStringSync(), garbage);
    expect(file.existsSync(), isTrue);
    expect(File('${file.path}.tmp').existsSync(), isFalse, reason: 'temp file renamed away');
    final reloaded = HistoryStore(directory: dir);
    await reloaded.load();
    expect(reloaded.entries.map((e) => e.id), ['n1']);
  });

  test('a bad entry is skipped and the good ones survive the next add', () async {
    final dir = tempHistoryDir('mixed');
    addTearDown(() => dir.deleteSync(recursive: true));
    Directory('${dir.path}/iwantfigure').createSync();
    final file = File('${dir.path}/iwantfigure/history.json');
    HistoryEntry good(String id, DateTime t) => HistoryEntry(
          id: id,
          timestamp: t,
          analysis: sampleAnalysis(),
          photoPath: '',
          imageWidth: 1,
          imageHeight: 1,
        );
    final bad = {
      'id': 'bad',
      'timestamp': '2026-09-24T00:00:00',
      // bbox with two numbers → NBox.fromList throws.
      'analysis': {
        'layout_type': 'bridge_parallel',
        'objects': [
          {'id': 'x', 'kind': 'box', 'bbox': [0.1, 0.2]},
        ],
      },
    };
    file.writeAsStringSync(jsonEncode([
      good('g1', DateTime(2026, 9, 20)).toJson(),
      bad,
      42,
      good('g2', DateTime(2026, 9, 22)).toJson(),
    ]));

    final store = HistoryStore(directory: dir);
    await store.load();
    expect(store.entries.map((e) => e.id), ['g2', 'g1']);
    expect(File('${file.path}.bak').existsSync(), isFalse);

    await store.add(good('g3', DateTime(2026, 9, 24)));
    final reloaded = HistoryStore(directory: dir);
    await reloaded.load();
    expect(reloaded.entries.map((e) => e.id), ['g3', 'g2', 'g1']);
  });

  test('photo file names are sanitized and stay inside the photos directory', () async {
    expect(HistoryStore.photoFileName('session-1-abc'), 'session-1-abc');
    expect(HistoryStore.photoFileName('../../etc/passwd'), '.._.._etc_passwd'.replaceAll('.', '_'));
    expect(HistoryStore.photoFileName('..'), 'photo');
    expect(HistoryStore.photoFileName(''), 'photo');
    expect(HistoryStore.photoFileName('a' * 200).length, 80);

    final dir = tempHistoryDir('traversal');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = HistoryStore(directory: dir);
    await store.load();
    final stored = await store.add(
      HistoryEntry(
        id: '../../evil',
        timestamp: DateTime(2026, 9, 24),
        analysis: sampleAnalysis(),
        photoPath: '',
        imageWidth: 1,
        imageHeight: 1,
      ),
      photoBytes: Uint8List.fromList([9]),
    );
    final photosDir = Directory('${dir.path}/iwantfigure/photos');
    expect(File(stored.photoPath).parent.path, photosDir.path);
    expect(RegExp(r'^[A-Za-z0-9_-]+\.jpg$').hasMatch(stored.photoPath.split(Platform.pathSeparator).last), isTrue);
    expect(File('${dir.path}/evil.jpg').existsSync(), isFalse);
  });
}
