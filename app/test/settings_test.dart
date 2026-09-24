import 'package:flutter_test/flutter_test.dart';
import 'package:iwantfigure/engine/inputs.dart';
import 'package:iwantfigure/l10n/strings.dart';
import 'package:iwantfigure/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsStore();
    await s.load();
    expect(s.baseUrl, 'http://10.0.2.2:8080');
    expect(s.appKey, '');
    expect(s.mockMode, isTrue);
    expect(s.locale, AppLocale.ko);
    expect(s.prizePreset, PrizePreset.figureBoxM);
    expect(s.defaultPrize.widthMm, PrizeSpec.defaultFigureBox.widthMm);
    expect(s.showShootingGuide, isTrue);
    expect(S.current.locale, AppLocale.ko);
  });

  test('setters persist and a fresh store reads them back', () async {
    SharedPreferences.setMockInitialValues({});
    final a = SettingsStore();
    await a.load();
    var notified = 0;
    a.addListener(() => notified++);
    await a.setBaseUrl('https://api.example.com/');
    await a.setAppKey(' secret ');
    await a.setMockMode(false);
    await a.setLocale(AppLocale.ja);
    await a.setPrizePreset(PrizePreset.plush);
    await a.setShowShootingGuide(false);
    expect(notified, 6);
    expect(a.baseUrl, 'https://api.example.com');
    expect(a.appKey, 'secret');
    expect(S.current.locale, AppLocale.ja);

    final b = SettingsStore();
    await b.load();
    expect(b.baseUrl, 'https://api.example.com');
    expect(b.appKey, 'secret');
    expect(b.mockMode, isFalse);
    expect(b.locale, AppLocale.ja);
    expect(b.prizePreset, PrizePreset.plush);
    expect(b.defaultPrize.name, PrizeSpec.defaultPlush.name);
    expect(b.showShootingGuide, isFalse);
  });

  test('empty URL falls back to the default', () async {
    SharedPreferences.setMockInitialValues({});
    final s = SettingsStore();
    await s.load();
    await s.setBaseUrl('   ');
    expect(s.baseUrl, SettingsStore.defaultBaseUrl);
  });
}
