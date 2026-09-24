/// Persistent list of past sessions stored as one JSON file in the app's
/// documents directory, with photos copied next to it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../engine/inputs.dart';
import '../models/analysis.dart';

/// How a session ended.
enum SessionOutcome {
  success,
  fail,
  open;

  static SessionOutcome fromName(String? n) => SessionOutcome.values.firstWhere(
        (o) => o.name == n,
        orElse: () => SessionOutcome.open,
      );
}


/// One saved session.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.analysis,
    required this.photoPath,
    required this.imageWidth,
    required this.imageHeight,
    this.observations = const [],
    this.prize = PrizeSpec.defaultFigureBox,
    this.corrections = SceneCorrections.none,
    this.outcome = SessionOutcome.open,
    this.plays = 0,
    this.yen = 0,
    this.locale = 'ko',
  });

  final String id;
  final DateTime timestamp;
  final AnalysisResult analysis;

  /// Absolute path of the copied photo (may no longer exist).
  final String photoPath;
  final int imageWidth;
  final int imageHeight;
  final List<Observation> observations;
  final PrizeSpec prize;
  final SceneCorrections corrections;
  final SessionOutcome outcome;
  final int plays;
  final int yen;
  final String locale;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'analysis': analysis.toJson(),
        'photo_path': photoPath,
        'image_width': imageWidth,
        'image_height': imageHeight,
        'observations': observations.map((o) => o.toJson()).toList(),
        'prize': prize.toJson(),
        'corrections': corrections.toJson(),
        'outcome': outcome.name,
        'plays': plays,
        'yen': yen,
        'locale': locale,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: (j['id'] ?? '').toString(),
        timestamp: DateTime.tryParse((j['timestamp'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        analysis: AnalysisResult.fromJson(
            (j['analysis'] as Map<String, dynamic>?) ?? const {}),
        photoPath: (j['photo_path'] ?? '').toString(),
        imageWidth: (j['image_width'] as num?)?.toInt() ?? 0,
        imageHeight: (j['image_height'] as num?)?.toInt() ?? 0,
        observations: (j['observations'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Observation.fromJson)
            .toList(),
        prize: j['prize'] is Map<String, dynamic>
            ? PrizeSpec.fromJson(j['prize'] as Map<String, dynamic>)
            : PrizeSpec.defaultFigureBox,
        corrections: SceneCorrections.fromJson(
            j['corrections'] as Map<String, dynamic>?),
        outcome: SessionOutcome.fromName(j['outcome'] as String?),
        plays: (j['plays'] as num?)?.toInt() ?? 0,
        yen: (j['yen'] as num?)?.toInt() ?? 0,
        locale: (j['locale'] ?? 'ko').toString(),
      );

  /// Reads the stored photo, or null when the file is gone.
  Future<Uint8List?> loadPhoto() async {
    final f = File(photoPath);
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }
}

/// Loads, lists, adds and deletes [HistoryEntry]s. Newest first.
class HistoryStore extends ChangeNotifier {
  /// [directory] overrides the storage root (tests); by default the
  /// `path_provider` documents directory is used.
  HistoryStore({Directory? directory}) : _rootOverride = directory;

  static const _fileName = 'history.json';
  static const _photoDir = 'photos';

  final Directory? _rootOverride;
  Directory? _root;
  List<HistoryEntry> _entries = const [];
  bool _loaded = false;

  List<HistoryEntry> get entries => _entries;
  bool get loaded => _loaded;

  Future<Directory> _rootDir() async {
    if (_root != null) return _root!;
    final base = _rootOverride ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}iwantfigure');
    await dir.create(recursive: true);
    _root = dir;
    return dir;
  }

  Future<File> _file() async =>
      File('${(await _rootDir()).path}${Platform.pathSeparator}$_fileName');

  Future<void> load() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        final decoded = jsonDecode(await f.readAsString());
        if (decoded is List) {
          _entries = decoded
              .whereType<Map<String, dynamic>>()
              .map(HistoryEntry.fromJson)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        }
      }
    } catch (e) {
      debugPrint('HistoryStore.load failed: $e');
      _entries = const [];
    }
    _loaded = true;
    notifyListeners();
  }

  /// Copies [photoBytes] into the store and appends [entry] (with its
  /// `photoPath` replaced by the copy). Returns the stored entry.
  Future<HistoryEntry> add(HistoryEntry entry, {Uint8List? photoBytes}) async {
    var stored = entry;
    if (photoBytes != null) {
      final dir = Directory(
          '${(await _rootDir()).path}${Platform.pathSeparator}$_photoDir');
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}${entry.id}.jpg');
      await file.writeAsBytes(photoBytes, flush: true);
      stored = entry.copyWith(photoPath: file.path);
    }
    _entries = [stored, ..._entries.where((e) => e.id != stored.id)];
    await _save();
    notifyListeners();
    return stored;
  }

  Future<void> delete(String id) async {
    final victim = _entries.where((e) => e.id == id).firstOrNull;
    if (victim == null) return;
    _entries = _entries.where((e) => e.id != id).toList();
    try {
      final f = File(victim.photoPath);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Losing an orphan photo is harmless.
    }
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final f = await _file();
    await f.writeAsString(jsonEncode(_entries.map((e) => e.toJson()).toList()),
        flush: true);
  }
}

extension on HistoryEntry {
  HistoryEntry copyWith({String? photoPath}) => HistoryEntry(
        id: id,
        timestamp: timestamp,
        analysis: analysis,
        photoPath: photoPath ?? this.photoPath,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        observations: observations,
        prize: prize,
        corrections: corrections,
        outcome: outcome,
        plays: plays,
        yen: yen,
        locale: locale,
      );
}
