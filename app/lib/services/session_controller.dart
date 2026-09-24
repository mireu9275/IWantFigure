/// State of one analysis session: the photo, the analysis result, the user's
/// inputs (prize, corrections, observations) and the derived [AimPlan].
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../engine/aim_engine.dart';
import '../models/analysis.dart';
import 'api_client.dart';
import 'face_blur.dart';
import 'history_store.dart';
import 'image_prep.dart';

/// Lifecycle of a session.
enum SessionState { idle, analyzing, ready, error }

/// Progress steps shown while analyzing.
enum AnalyzeStage { prepare, blur, server, aim }

/// Holds everything about the current session and recomputes the plan with
/// [AimEngine] whenever an input changes (coalesced into one microtask).
class SessionController extends ChangeNotifier {
  SessionController({
    required this.photo,
    required AnalysisService this.service,
    this._locale = 'ko',
    PrizeSpec? prize,
    this.engine = const AimEngine(),
    this.history,
    this.hints,
    this.faceDetector = const NoopFaceRegionDetector(),
    this.blurFaces = true,
    this.blurrer = const FaceBlurrer(),
  }) : _prize = prize; // ignore: prefer_initializing_formals

  /// Reopens a saved session read-only (no observations can be added).
  SessionController.fromHistory(
    HistoryEntry entry, {
    required Uint8List photoBytes,
    this.engine = const AimEngine(),
    String? locale,
  })  : photo = PickedPhoto(
          bytes: photoBytes,
          width: entry.imageWidth,
          height: entry.imageHeight,
          path: entry.photoPath,
        ),
        service = null,
        _locale = locale ?? entry.locale,
        _prize = entry.prize,
        history = null,
        hints = null,
        faceDetector = const NoopFaceRegionDetector(),
        blurFaces = false,
        blurrer = const FaceBlurrer(),
        readOnly = true,
        _analysis = entry.analysis,
        _corrections = entry.corrections,
        _observations = [...entry.observations],
        _outcome = entry.outcome,
        _plays = entry.plays,
        _yen = entry.yen,
        _state = SessionState.ready {
    _recomputePlan();
  }

  /// The photo in use. Replaced by the anonymised version once faces were
  /// pixelated, so the overlay, the upload and the history all use it.
  PickedPhoto photo;

  /// On-device face detector used before upload; faces are pixelated by
  /// [blurrer]. Off when [blurFaces] is false.
  final FaceRegionDetector faceDetector;
  final bool blurFaces;
  final FaceBlurrer blurrer;

  int _blurredFaces = 0;

  /// Faces pixelated in [photo] during the last [analyze] (0 when none).
  int get blurredFaces => _blurredFaces;
  final AimEngine engine;
  final HistoryStore? history;
  final AnalyzeHints? hints;

  /// True for sessions reopened from history.
  bool readOnly = false;

  /// The provider used by [analyze]; swap it to retry with the mock.
  AnalysisService? service;

  String _locale;

  /// Prize size chosen by the user; `null` = decide from the detected prize
  /// kind (figure box vs plush) — see [prize].
  PrizeSpec? _prize;
  AnalysisResult? _analysis;
  SceneCorrections _corrections = SceneCorrections.none;
  List<Observation> _observations = [];
  AimPlan? _plan;
  SessionState _state = SessionState.idle;
  AnalyzeStage _stage = AnalyzeStage.prepare;
  Object? _error;
  SessionOutcome _outcome = SessionOutcome.open;
  int _plays = 0;
  int _yen = 0;
  bool _planScheduled = false;
  bool _disposed = false;

  /// Incremented on every [analyze]; a call whose generation is stale (a
  /// newer call started, or the controller was disposed) discards its result.
  int _generation = 0;

  String get locale => _locale;
  /// The prize size in effect: the user's choice, or a default matching the
  /// detected prize kind.
  PrizeSpec get prize => _prize ?? _autoPrize;

  /// True when the user set the prize size explicitly.
  bool get prizeIsExplicit => _prize != null;

  PrizeSpec get _autoPrize => _analysis?.targetPrize?.kind == ObjectKind.plush
      ? PrizeSpec.defaultPlush
      : PrizeSpec.defaultFigureBox;
  AnalysisResult? get analysis => _analysis;
  SceneCorrections get corrections => _corrections;
  List<Observation> get observations => List.unmodifiable(_observations);
  AimPlan? get plan => _plan;
  SessionState get state => _state;
  AnalyzeStage get stage => _stage;
  Object? get error => _error;
  SessionOutcome get outcome => _outcome;
  int get plays => _plays;
  int get yen => _yen;
  bool get isFinished => _plan?.finished ?? false;
  bool get isSaved => _outcome != SessionOutcome.open;

  /// Number of plays implied by the observations (詰み does not count).
  int get playsFromObservations =>
      _observations.where((o) => o.kind != ObservationKind.stuck).length;

  /// Runs the analysis provider on the photo and computes the first plan.
  /// When called again while a previous call is in flight, only the newest
  /// call's result is applied.
  Future<void> analyze() async {
    final svc = service;
    if (svc == null) return;
    final gen = ++_generation;
    bool stale() => _disposed || gen != _generation;
    _state = SessionState.analyzing;
    _stage = AnalyzeStage.prepare;
    _error = null;
    notifyListeners();
    try {
      // "prepare" is the decode already done by the picker; yield once so
      // the UI can show the stage.
      await Future<void>.delayed(Duration.zero);
      if (stale()) return;
      if (blurFaces) {
        _stage = AnalyzeStage.blur;
        notifyListeners();
        final blurred = await anonymiseFaces(
          bytes: photo.bytes,
          width: photo.width,
          height: photo.height,
          path: photo.path,
          detector: faceDetector,
          blurrer: blurrer,
        );
        if (stale()) return;
        _blurredFaces = blurred.faceCount;
        if (blurred.changed) {
          photo = PickedPhoto(
            bytes: blurred.bytes,
            width: blurred.width,
            height: blurred.height,
            path: photo.path,
          );
        }
      }
      _stage = AnalyzeStage.server;
      notifyListeners();
      final result = await svc.analyze(
        photo.bytes,
        locale: _locale,
        hints: hints ??
            AnalyzeHints(
              prizeSizeMm: _prize == null
                  ? null
                  : [_prize!.widthMm, _prize!.depthMm, _prize!.heightMm],
            ),
      );
      if (stale()) return;
      _stage = AnalyzeStage.aim;
      notifyListeners();
      _analysis = result;
      _recomputePlan();
      _state = SessionState.ready;
    } catch (e) {
      if (stale()) return;
      _error = e;
      _state = SessionState.error;
    }
    notifyListeners();
  }

  void addObservation(ObservationKind kind, {String? note}) {
    if (readOnly) return;
    _observations = [
      ..._observations,
      Observation(kind, playIndex: playsFromObservations + 1, note: note),
    ];
    _invalidatePlan();
  }

  void undoObservation() {
    if (readOnly || _observations.isEmpty) return;
    _observations = _observations.sublist(0, _observations.length - 1);
    _invalidatePlan();
  }

  void setCorrections(SceneCorrections c) {
    _corrections = c;
    _invalidatePlan();
  }

  void setPrize(PrizeSpec p) {
    _prize = p;
    _invalidatePlan();
  }

  void setLocale(String code) {
    if (code == _locale) return;
    _locale = code;
    _invalidatePlan();
  }

  /// Records the outcome and, when a [history] store is attached, saves the
  /// session (copying the photo). The outcome is only committed once the save
  /// succeeded; a failed save rethrows and leaves [isSaved] false. Returns
  /// the entry that was built.
  Future<HistoryEntry> finish(SessionOutcome outcome, {int? plays, int? yen}) async {
    final p = plays ?? playsFromObservations;
    final y = yen ?? 0;
    final entry = _buildEntry(outcome: outcome, plays: p, yen: y);
    final store = history;
    final stored = store == null ? entry : await store.add(entry, photoBytes: photo.bytes);
    _outcome = outcome;
    _plays = p;
    _yen = y;
    if (!_disposed) notifyListeners();
    return stored;
  }

  /// Snapshot of the session as a history record (photo path not yet copied).
  HistoryEntry toHistoryEntry() => _buildEntry(outcome: _outcome, plays: _plays, yen: _yen);

  static final _random = math.Random();

  /// Locally generated, file-system-safe id (never derived from server data).
  static String newSessionId() =>
      'session-${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(1 << 30).toRadixString(36)}';

  HistoryEntry _buildEntry({
    required SessionOutcome outcome,
    required int plays,
    required int yen,
  }) {
    final a = _analysis;
    if (a == null) {
      throw StateError('No analysis to save');
    }
    return HistoryEntry(
      id: newSessionId(),
      timestamp: DateTime.now(),
      analysis: a,
      photoPath: photo.path ?? '',
      imageWidth: photo.width,
      imageHeight: photo.height,
      observations: _observations,
      prize: prize,
      corrections: _corrections,
      outcome: outcome,
      plays: plays,
      yen: yen,
      locale: _locale,
    );
  }

  /// Clears the analysis and every input; keeps the photo and the service.
  void reset() {
    _analysis = null;
    _plan = null;
    _observations = [];
    _corrections = SceneCorrections.none;
    _outcome = SessionOutcome.open;
    _plays = 0;
    _yen = 0;
    _error = null;
    _state = SessionState.idle;
    notifyListeners();
  }

  void _invalidatePlan() {
    if (_planScheduled) return;
    _planScheduled = true;
    scheduleMicrotask(() {
      _planScheduled = false;
      if (_disposed) return;
      _recomputePlan();
      notifyListeners();
    });
  }

  void _recomputePlan() {
    final a = _analysis;
    if (a == null) {
      _plan = null;
      return;
    }
    _plan = engine.plan(
      a,
      prize: _prize,
      corrections: _corrections,
      observations: _observations,
      locale: _locale,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
