/// Dependency container exposed to the widget tree.
library;

import 'package:flutter/widgets.dart';

import '../services/face_blur.dart';

import '../services/api_client.dart';
import '../services/history_store.dart';
import '../services/image_prep.dart';
import '../services/mock_api.dart';
import '../services/settings.dart';

/// Gives screens access to the settings, the history store and the photo
/// picker. Build analysis services through [buildService] so the mock/real
/// choice follows the current settings.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.settings,
    required this.history,
    required this.picker,
    required this.faceDetector,
    this.serviceOverride,
    required super.child,
  });

  final SettingsStore settings;
  final HistoryStore history;
  final PhotoPicker picker;

  /// On-device face detector used before a photo is uploaded or stored.
  final FaceRegionDetector faceDetector;

  /// When set (tests), returned by [buildService] regardless of settings.
  final AnalysisService? serviceOverride;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above ${context.widget}');
    return scope!;
  }

  static AppScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>();

  AnalysisService buildService({bool forceMock = false}) {
    final o = serviceOverride;
    if (o != null) return o;
    if (forceMock || settings.mockMode) return const MockAnalyzeApi();
    return AnalyzeApi(baseUrl: settings.baseUrl, appKey: settings.appKey);
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      settings != oldWidget.settings ||
      history != oldWidget.history ||
      picker != oldWidget.picker ||
      faceDetector != oldWidget.faceDetector ||
      serviceOverride != oldWidget.serviceOverride;
}
