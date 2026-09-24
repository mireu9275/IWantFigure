/// Root widget: theme, locale scope and the home route.
library;

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../screens/home_screen.dart';
import '../services/api_client.dart';
import '../services/face_blur.dart';
import '../services/history_store.dart';
import '../services/mlkit_face_detector.dart';
import '../services/image_prep.dart';
import '../services/settings.dart';
import 'app_scope.dart';

/// The IWantFigure application shell.
class IWantFigureApp extends StatelessWidget {
  const IWantFigureApp({
    super.key,
    required this.settings,
    required this.history,
    this.picker,
    this.faceDetector,
    this.serviceOverride,
    this.home,
    this.fontFamily,
    this.fontFamilyFallback,
  });

  final SettingsStore settings;
  final HistoryStore history;

  /// Photo picker; a default one is created when null.
  final PhotoPicker? picker;
  final AnalysisService? serviceOverride;

  /// Face detector; ML Kit (on device) when null.
  final FaceRegionDetector? faceDetector;

  /// Overrides the home route (tests).
  final Widget? home;

  /// Optional font family/fallback for the theme (used by the screenshot
  /// tool; the platform default is used when null).
  final String? fontFamily;
  final List<String>? fontFamilyFallback;

  static const seedColor = Color(0xFFE64A5F);

  @override
  Widget build(BuildContext context) {
    final picker = this.picker ?? PhotoPicker();
    final faceDetector = this.faceDetector ?? const MlKitFaceRegionDetector();
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final strings = settings.strings;
        return AppScope(
          settings: settings,
          history: history,
          picker: picker,
          faceDetector: faceDetector,
          serviceOverride: serviceOverride,
          child: LocaleScope(
            strings: strings,
            child: MaterialApp(
              title: strings.appName,
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
                useMaterial3: true,
                fontFamily: fontFamily,
                fontFamilyFallback: fontFamilyFallback,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: seedColor,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
                fontFamily: fontFamily,
                fontFamilyFallback: fontFamilyFallback,
              ),
              themeMode: ThemeMode.system,
              home: home ?? const HomeScreen(),
            ),
          ),
        );
      },
    );
  }
}
