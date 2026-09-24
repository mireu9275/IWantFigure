/// Settings: mock mode, server, language, default prize, guide, about.
library;

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../l10n/strings.dart';
import '../services/settings.dart';

/// Edits the [SettingsStore]: mock mode, server URL/key, language, default
/// prize preset, guide visibility, plus the about/disclaimer block.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? _url;
  TextEditingController? _key;

  @override
  void dispose() {
    _url?.dispose();
    _key?.dispose();
    super.dispose();
  }

  String _presetLabel(S s, PrizePreset p) => switch (p) {
        PrizePreset.figureBoxS => s.presetFigureBoxS,
        PrizePreset.figureBoxM => s.presetFigureBoxM,
        PrizePreset.figureBoxL => s.presetFigureBoxL,
        PrizePreset.plush => s.presetPlush,
      };

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    _url ??= TextEditingController(text: settings.baseUrl);
    _key ??= TextEditingController(text: settings.appKey);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = S.of(context);
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(s.settingsTitle)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              SwitchListTile(
                title: Text(s.mockMode),
                subtitle: Text(s.mockModeHint),
                value: settings.mockMode,
                onChanged: settings.setMockMode,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                enabled: !settings.mockMode,
                decoration: InputDecoration(
                  labelText: s.serverUrl,
                  helperText: s.serverUrlHint,
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.restart_alt),
                    tooltip: s.reset,
                    onPressed: () {
                      _url!.text = SettingsStore.defaultBaseUrl;
                      settings.setBaseUrl(SettingsStore.defaultBaseUrl);
                    },
                  ),
                ),
                onChanged: settings.setBaseUrl,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _key,
                enabled: !settings.mockMode,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: s.appKey,
                  helperText: s.appKeyHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: settings.setAppKey,
              ),
              const SizedBox(height: 20),
              Text(s.language, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              SegmentedButton<AppLocale>(
                segments: [
                  for (final l in AppLocale.values)
                    ButtonSegment(value: l, label: Text(l.nativeName)),
                ],
                selected: {settings.locale},
                onSelectionChanged: (v) => settings.setLocale(v.first),
              ),
              const SizedBox(height: 20),
              Text(s.defaultPrize, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in PrizePreset.values)
                    ChoiceChip(
                      label: Text(_presetLabel(s, p)),
                      selected: settings.prizePreset == p,
                      onSelected: (_) => settings.setPrizePreset(p),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tips_and_updates_outlined),
                title: Text(s.showGuideAgain),
                enabled: !settings.showShootingGuide,
                onTap: () {
                  settings.setShowShootingGuide(true);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.guideRestored)));
                },
              ),
              const Divider(height: 32),
              Text(s.about, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(s.aboutBody),
              const SizedBox(height: 12),
              Text(
                s.disclaimerShort,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 6),
              Text('${s.version} 0.1.0', style: theme.textTheme.bodySmall),
            ],
          ),
        );
      },
    );
  }
}
