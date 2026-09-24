/// Entry screen: take/pick a photo, shooting guide, past sessions.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../l10n/strings.dart';
import '../services/history_store.dart';
import '../services/image_prep.dart';
import '../services/session_controller.dart';
import 'analyzing_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _picking = false;

  Future<void> _pick(PhotoSource source) async {
    if (_picking) return;
    final scope = AppScope.of(context);
    final s = S.of(context);
    setState(() => _picking = true);
    PickedPhoto? photo;
    try {
      photo = await scope.picker.pick(source);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${s.pickFailed}: $e')));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
    if (photo == null || !mounted) return;
    final controller = SessionController(
      photo: photo,
      service: scope.buildService(),
      locale: scope.settings.locale.code,
      prize: scope.settings.defaultPrize,
      history: scope.history,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AnalyzingScreen(controller: controller)),
    );
  }

  Future<void> _openHistory(HistoryEntry entry) async {
    final s = S.of(context);
    final bytes = await entry.loadPhoto();
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.pickFailed)));
      return;
    }
    final controller = SessionController.fromHistory(
      entry,
      photoBytes: bytes,
      locale: S.of(context).code,
    );
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ResultScreen(controller: controller)),
    );
  }

  Future<void> _confirmDelete(HistoryEntry entry) async {
    final s = S.of(context);
    final scope = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteHistoryTitle),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.delete)),
        ],
      ),
    );
    if (ok == true) await scope.history.delete(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, scope.history]),
      builder: (context, _) {
        final s = S.of(context);
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final entries = scope.history.entries;
        return Scaffold(
          appBar: AppBar(
            title: Text(s.appName),
            actions: [
              IconButton(
                tooltip: s.settingsTitle,
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(s.homeTagline, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
              if (settings.mockMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Tooltip(
                      message: s.mockModeChipHint,
                      child: Chip(
                        avatar: const Icon(Icons.science_outlined, size: 18),
                        label: Text(s.mockModeChip),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _bigButton(
                      icon: Icons.photo_camera,
                      label: s.takePhoto,
                      onPressed: _picking ? null : () => _pick(PhotoSource.camera),
                      filled: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _bigButton(
                      icon: Icons.photo_library_outlined,
                      label: s.pickFromGallery,
                      onPressed: _picking ? null : () => _pick(PhotoSource.gallery),
                      filled: false,
                    ),
                  ),
                ],
              ),
              if (settings.showShootingGuide) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tips_and_updates_outlined, size: 20),
                            const SizedBox(width: 8),
                            Text(s.shootingGuideTitle, style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (final item in s.shootingGuideItems)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 6, right: 8),
                                  child: Icon(Icons.circle, size: 6),
                                ),
                                Expanded(child: Text(item)),
                              ],
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => settings.setShowShootingGuide(false),
                            child: Text(s.hideGuide),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(s.historyTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(s.historyEmpty, style: TextStyle(color: scheme.outline)),
                )
              else
                for (final e in entries) _historyTile(context, s, e),
            ],
          ),
        );
      },
    );
  }

  Widget _bigButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool filled,
  }) {
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 30),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
    final style = ButtonStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 18)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
    return filled
        ? FilledButton(onPressed: onPressed, style: style, child: child)
        : FilledButton.tonal(onPressed: onPressed, style: style, child: child);
  }

  Widget _historyTile(BuildContext context, S s, HistoryEntry e) {
    final scheme = Theme.of(context).colorScheme;
    final outcome = switch (e.outcome) {
      SessionOutcome.success => (s.outcomeSuccess, scheme.primary, Icons.emoji_events),
      SessionOutcome.fail => (s.outcomeFail, scheme.error, Icons.close),
      SessionOutcome.open => (s.outcomeOpen, scheme.outline, Icons.more_horiz),
    };
    final file = File(e.photoPath);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 56,
            height: 56,
            child: e.photoPath.isNotEmpty && file.existsSync()
                ? Image.file(file, fit: BoxFit.cover, cacheWidth: 112)
                : ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
          ),
        ),
        title: Text(s.layoutLabel(e.analysis.layoutType), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            Icon(outcome.$3, size: 14, color: outcome.$2),
            const SizedBox(width: 4),
            Text(outcome.$1, style: TextStyle(color: outcome.$2)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${s.playsAndYen(e.plays, e.yen)} · ${_date(e.timestamp)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: s.delete,
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(e),
        ),
        onTap: () => _openHistory(e),
      ),
    );
  }

  static String _date(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}
