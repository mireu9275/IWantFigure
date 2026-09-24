/// Layout-type guide (기초 가이드): a list of every [LayoutType] and a detail
/// page with how to recognise it, how to aim, techniques, tips, when to walk
/// away and the typical cost.
library;

import 'package:flutter/material.dart';

import '../l10n/guide_content.dart';
import '../l10n/strings.dart';
import '../models/analysis.dart';

/// Pushes the guide page for [type] on top of the current route.
Future<void> openGuideDetail(BuildContext context, LayoutType type) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GuideDetailScreen(type: type)),
    );

/// List of all layout types; tap one to open its [GuideDetailScreen].
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final types = LayoutType.values;
    return Scaffold(
      appBar: AppBar(title: Text(s.guideTitle)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        itemCount: types.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text(s.guideSubtitle, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.outline)),
            );
          }
          final type = types[i - 1];
          final guide = guideFor(type, s);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: _EmojiBadge(type: type),
              title: Text(s.layoutLabel(type), maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(guide.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openGuideDetail(context, type),
            ),
          );
        },
      ),
    );
  }
}

/// Guide for one layout type.
class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key, required this.type});

  final LayoutType type;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final g = guideFor(type, s);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.layoutLabel(type), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EmojiBadge(type: type, large: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      g.summary,
                      style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onPrimaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _section(
            context,
            icon: Icons.visibility_outlined,
            title: s.guideRecognize,
            children: [for (final r in g.recognize) _bullet(context, r)],
          ),
          _section(
            context,
            icon: Icons.my_location,
            title: s.guideHowTo,
            children: [for (var i = 0; i < g.howTo.length; i++) _numbered(context, i + 1, g.howTo[i])],
          ),
          if (g.techniques.isNotEmpty)
            _section(
              context,
              icon: Icons.sports_esports_outlined,
              title: s.guideTechniques,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final t in g.techniques)
                      Chip(
                        label: Text(s.techniqueLabel(t)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ),
          _section(
            context,
            icon: Icons.tips_and_updates_outlined,
            title: s.guideTips,
            children: [for (final t in g.tips) _bullet(context, t, icon: Icons.lightbulb_outline)],
          ),
          _section(
            context,
            icon: Icons.stop_circle_outlined,
            title: s.guideAbort,
            children: [
              for (final a in g.abortWhen) _bullet(context, a, icon: Icons.stop_circle_outlined, color: scheme.error),
            ],
          ),
          _section(
            context,
            icon: Icons.payments_outlined,
            title: s.guideCost,
            children: [
              Text(g.typicalCost),
              const SizedBox(height: 6),
              Text(s.guideCostNote, style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(s.disclaimerShort, style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) =>
      Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _bullet(BuildContext context, String text, {IconData icon = Icons.circle, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Icon(icon, size: icon == Icons.circle ? 8 : 16, color: color),
            ),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Widget _numbered(BuildContext context, int n, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: scheme.primary,
            child: Text(
              '$n',
              style: TextStyle(fontSize: 12, color: scheme.onPrimary, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(text))),
        ],
      ),
    );
  }
}

class _EmojiBadge extends StatelessWidget {
  const _EmojiBadge({required this.type, this.large = false});

  final LayoutType type;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = large ? 56.0 : 44.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: large ? scheme.surface : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(layoutIcon(type), size: large ? 30 : 24, color: scheme.onSecondaryContainer),
    );
  }
}
