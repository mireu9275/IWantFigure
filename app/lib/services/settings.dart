/// User settings persisted with `shared_preferences`.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/inputs.dart';
import '../l10n/strings.dart';

/// Named prize presets offered in the UI.
enum PrizePreset {
  figureBoxS,
  figureBoxM,
  figureBoxL,
  plush;

  /// Dimensions for the preset.
  PrizeSpec get spec => switch (this) {
        PrizePreset.figureBoxS => const PrizeSpec(
            name: 'figure box S', widthMm: 120, depthMm: 160, heightMm: 80, massG: 200),
        PrizePreset.figureBoxM => PrizeSpec.defaultFigureBox.copyWith(name: 'figure box M'),
        PrizePreset.figureBoxL => const PrizeSpec(
            name: 'figure box L', widthMm: 200, depthMm: 280, heightMm: 130, massG: 550),
        PrizePreset.plush => PrizeSpec.defaultPlush,
      };

  static PrizePreset fromName(String? name) => PrizePreset.values.firstWhere(
        (p) => p.name == name,
        orElse: () => PrizePreset.figureBoxM,
      );
}

/// Application settings. Call [load] once before use; every setter persists
/// immediately and notifies listeners.
class SettingsStore extends ChangeNotifier {
  SettingsStore();

  static const defaultBaseUrl = 'http://10.0.2.2:8080';

  static const _kBaseUrl = 'base_url';
  static const _kAppKey = 'app_key';
  static const _kMockMode = 'mock_mode';
  static const _kLocale = 'locale';
  static const _kPrizePreset = 'prize_preset';
  static const _kShowGuide = 'show_shooting_guide';

  SharedPreferences? _prefs;

  String _baseUrl = defaultBaseUrl;
  String _appKey = '';
  bool _mockMode = true;
  AppLocale _locale = AppLocale.ko;
  PrizePreset _prizePreset = PrizePreset.figureBoxM;
  bool _showShootingGuide = true;

  bool get loaded => _prefs != null;

  /// Server base URL without a trailing slash.
  String get baseUrl => _baseUrl;
  String get appKey => _appKey;

  /// When true the bundled sample analysis is used instead of the server.
  bool get mockMode => _mockMode;
  AppLocale get locale => _locale;
  PrizePreset get prizePreset => _prizePreset;

  /// The [PrizeSpec] used for new sessions.
  PrizeSpec get defaultPrize => _prizePreset.spec;
  bool get showShootingGuide => _showShootingGuide;

  /// Localized strings for the current locale.
  S get strings => S(_locale);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    _baseUrl = _normalizeUrl(p.getString(_kBaseUrl) ?? defaultBaseUrl);
    _appKey = p.getString(_kAppKey) ?? '';
    _mockMode = p.getBool(_kMockMode) ?? true;
    _locale = AppLocale.fromCode(p.getString(_kLocale));
    _prizePreset = PrizePreset.fromName(p.getString(_kPrizePreset));
    _showShootingGuide = p.getBool(_kShowGuide) ?? true;
    S.current = strings;
    notifyListeners();
  }

  Future<void> setBaseUrl(String value) async {
    _baseUrl = _normalizeUrl(value);
    await _prefs?.setString(_kBaseUrl, _baseUrl);
    notifyListeners();
  }

  Future<void> setAppKey(String value) async {
    _appKey = value.trim();
    await _prefs?.setString(_kAppKey, _appKey);
    notifyListeners();
  }

  Future<void> setMockMode(bool value) async {
    _mockMode = value;
    await _prefs?.setBool(_kMockMode, value);
    notifyListeners();
  }

  Future<void> setLocale(AppLocale value) async {
    _locale = value;
    S.current = strings;
    await _prefs?.setString(_kLocale, value.code);
    notifyListeners();
  }

  Future<void> setPrizePreset(PrizePreset value) async {
    _prizePreset = value;
    await _prefs?.setString(_kPrizePreset, value.name);
    notifyListeners();
  }

  Future<void> setShowShootingGuide(bool value) async {
    _showShootingGuide = value;
    await _prefs?.setBool(_kShowGuide, value);
    notifyListeners();
  }

  static String _normalizeUrl(String v) {
    var s = v.trim();
    if (s.isEmpty) return defaultBaseUrl;
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}
