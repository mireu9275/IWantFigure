/// State of one analysis session: the photo, the analysis result, the user's
/// inputs (prize, corrections, observations) and the derived [AimPlan].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../engine/aim_engine.dart';
import '../models/analysis.dart';
import 'api_client.dart';
import 'history_store.dart';
import 'image_prep.dart';

/// Lifecycle of a session.
enum SessionState { idle, analyzing, ready, error }

/// Progress steps shown while analyzing.
enum AnalyzeStage { prepare, server, aim }

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
  }) : _prize = prize ?? PrizeSpec.defaultFigureBox;

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

  final PickedPhoto photo;
  final AimEngine engine;
  final HistoryStore? history;
  final AnalyzeHints? hints;

  /// True for sessions reopened from history.
  bool readOnly = false;

  /// The provider used by [analyze]; swap it to retry with the mock.
  AnalysisService? service;

  String _locale;
  PrizeSpec _prize;
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

  String get locale => _locale;
  PrizeSpec get prize => _prize;
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
  Future<void> analyze() async {
    final svc = service;
    if (svc == null) return;
    _state = SessionState.analyzing;
    _stage = AnalyzeStage.prepare;
    _error = null;
    notifyListeners();
    try {
      // Nothing to do for "prepare" beyond the decode already done by the
      // picker; yield once so the UI can show the stage.
      await Future<void>.delayed(Duration.zero);
      _stage = AnalyzeStage.server;
      notifyListeners();
      final result = await svc.analyze(
        photo.bytes,
        locale: _locale,
        hints: hints ??
            AnalyzeHints(
              prizeSizeMm: [_prize.widthMm, _prize.depthMm, _prize.heightMm],
            ),
      );
      if (_disposed) return;
      _stage = AnalyzeStage.aim;
      notifyListeners();
      _analysis = result;
      _recomputePlan();
      _state = SessionState.ready;
    } catch (e) {
      if (_disposed) return;
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
  /// session (copying the photo). Returns the entry that was built.
  Future<HistoryEntry> finish(SessionOutcome outcome, {int? plays, int? yen}) async {
    _outcome = outcome;
    _plays = plays ?? playsFromObservations;
    _yen = yen ?? 0;
    final entry = toHistoryEntry();
    final store = history;
    final stored = store == null ? entry : await store.add(entry, photoBytes: photo.bytes);
    if (!_disposed) notifyListeners();
    return stored;
  }

  /// Snapshot of the session as a history record (photo path not yet copied).
  HistoryEntry toHistoryEntry() {
    final a = _analysis;
    if (a == null) {
      throw StateError('No analysis to save');
    }
    return HistoryEntry(
      id: a.analysisId.isNotEmpty
          ? '${a.analysisId}-${DateTime.now().millisecondsSinceEpoch}'
          : 'session-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      analysis: a,
      photoPath: photo.path ?? '',
      imageWidth: photo.width,
      imageHeight: photo.height,
      observations: _observations,
      prize: _prize,
      corrections: _corrections,
      outcome: _outcome,
      plays: _plays,
      yen: _yen,
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
