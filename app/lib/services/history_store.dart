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
  static const _backupSuffix = '.bak';
  static const _backupName = '$_fileName$_backupSuffix';
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

  /// Reads the history file. Entries that fail to parse are skipped (with a
  /// `debugPrint`); when the file itself is not valid JSON it is moved aside
  /// to `history.json.bak` so nothing is overwritten by the next [add].
  Future<void> load() async {
    var entries = <HistoryEntry>[];
    try {
      final f = await _file();
      if (await f.exists()) {
        final text = await f.readAsString();
        dynamic decoded;
        try {
          decoded = jsonDecode(text);
        } on FormatException catch (e) {
          debugPrint('HistoryStore: history.json is corrupt ($e); keeping it as $_backupName');
          await _moveAside(f);
          decoded = null;
        }
        if (decoded is List) {
          entries = _parseEntries(decoded);
        } else if (decoded != null) {
          debugPrint('HistoryStore: unexpected JSON root ${decoded.runtimeType}; keeping it as $_backupName');
          await _moveAside(f);
        }
      }
    } catch (e) {
      debugPrint('HistoryStore.load failed: $e');
    }
    _entries = entries;
    _loaded = true;
    notifyListeners();
  }

  static List<HistoryEntry> _parseEntries(List<dynamic> list) {
    final out = <HistoryEntry>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      if (item is! Map<String, dynamic>) {
        debugPrint('HistoryStore: skipping entry $i (not an object)');
        continue;
      }
      try {
        out.add(HistoryEntry.fromJson(item));
      } catch (e) {
        debugPrint('HistoryStore: skipping entry $i (${item['id']}): $e');
      }
    }
    out.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return out;
  }

  Future<void> _moveAside(File f) async {
    try {
      await f.rename('${f.path}$_backupSuffix');
    } catch (e) {
      debugPrint('HistoryStore: could not move the corrupt file aside: $e');
    }
  }

  /// Copies [photoBytes] into the store and appends [entry] (with its
  /// `photoPath` replaced by the copy). Returns the stored entry.
  Future<HistoryEntry> add(HistoryEntry entry, {Uint8List? photoBytes}) async {
    var stored = entry;
    if (photoBytes != null) {
      final dir = Directory(
          '${(await _rootDir()).path}${Platform.pathSeparator}$_photoDir');
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}${photoFileName(entry.id)}.jpg');
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

  /// File-system-safe name for a photo derived from [id]: only
  /// `[A-Za-z0-9_-]` survive, so an id from outside (or a corrupted one) can
  /// never escape the photos directory.
  static String photoFileName(String id) {
    final cleaned = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final trimmed = cleaned.length > 80 ? cleaned.substring(0, 80) : cleaned;
    return trimmed.isEmpty || trimmed.replaceAll('_', '').isEmpty ? 'photo' : trimmed;
  }

  /// Writes to a temporary file and renames it over `history.json`, so a
  /// crash mid-write never leaves a truncated history behind.
  Future<void> _save() async {
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(_entries.map((e) => e.toJson()).toList()),
        flush: true);
    await tmp.rename(f.path);
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
