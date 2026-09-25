/// Layout-type guide (기초 가이드): a list of every [LayoutType] and a detail
/// page with a motion demo, how to recognise it, how to aim, techniques,
/// tips, when to walk away and the typical cost.
library;

import 'package:flutter/material.dart';

import '../guide/guide_demo.dart';
import '../guide/guide_demos.dart';
import '../l10n/guide_content.dart';
import '../l10n/strings.dart';
import '../models/analysis.dart';
import '../widgets/guide_demo_view.dart';

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
              leading: _LayoutIconBadge(type: type),
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

/// Guide for one layout type. When the type has a motion demo it plays near
/// the top and stays pinned (shrunk) while the text scrolls; the How-to step
/// on screen is highlighted and tapping a step jumps the demo to it.
class GuideDetailScreen extends StatefulWidget {
  const GuideDetailScreen({super.key, required this.type});

  final LayoutType type;

  @override
  State<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<GuideDetailScreen> {
  final _step = ValueNotifier<int>(-1);
  final _demoKey = GlobalKey<GuideDemoViewState>();
  GuideDemo? _demo;
  (LayoutType, AppLocale)? _demoFor;

  @override
  void dispose() {
    _step.dispose();
    super.dispose();
  }

  /// The demo, rebuilt only when the type or the language changes.
  GuideDemo? _demoOf(S s) {
    final key = (widget.type, s.locale);
    if (_demoFor != key) {
      _demoFor = key;
      _demo = guideDemoFor(widget.type, s);
    }
    return _demo;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final g = guideFor(widget.type, s);
    final demo = _demoOf(s);
    final scenes = demo?.timeline.steps.toSet() ?? const <int>{};
    final width = MediaQuery.sizeOf(context).width;
    final maxExtent = ((width - 32) * 0.92).clamp(260.0, 440.0) + 12;
    final minExtent = ((width - 32) * 0.42).clamp(150.0, 210.0) + 12;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.layoutLabel(widget.type), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LayoutIconBadge(type: widget.type, large: true),
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
            ),
          ),
          if (demo != null) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Icon(Icons.view_in_ar_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.guideDemoTitle, style: theme.textTheme.titleMedium)),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _DemoHeaderDelegate(
                minHeight: minExtent,
                maxHeight: maxExtent,
                background: theme.scaffoldBackgroundColor,
                builder: (context, shrink) => GuideDemoView(
                  key: _demoKey,
                  demo: demo,
                  steps: g.howTo,
                  step: _step,
                  showCaption: shrink < (maxExtent - minExtent) / 2,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.guideDemoHint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(s.guideDemoNote, style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
                  ],
                ),
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
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
                  children: [
                    for (var i = 0; i < g.howTo.length; i++)
                      _numbered(context, s, i, g.howTo[i], hasScene: scenes.contains(i)),
                  ],
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
              ]),
            ),
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

  /// Numbered How-to step. Steps the demo shows are highlighted while they
  /// play and jump the demo to their scene when tapped.
  Widget _numbered(BuildContext context, S s, int i, String text, {required bool hasScene}) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: _step,
      builder: (context, current, _) {
        final active = hasScene && current == i;
        final body = AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: active ? 0.7 : 0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: scheme.primary,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(fontSize: 12, color: scheme.onPrimary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(text, style: active ? const TextStyle(fontWeight: FontWeight.w600) : null),
                ),
              ),
              if (hasScene)
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2),
                  child: Icon(active ? Icons.play_circle : Icons.play_circle_outline, size: 18, color: scheme.primary),
                ),
            ],
          ),
        );
        if (!hasScene) return body;
        return Semantics(
          button: true,
          hint: s.guideDemoShowStep(i + 1),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _demoKey.currentState?.seekToStep(i),
            child: body,
          ),
        );
      },
    );
  }
}

/// Pinned header holding the demo: full size near the top of the page,
/// shrinking to [minHeight] while the text scrolls under it.
class _DemoHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DemoHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.background,
    required this.builder,
  });

  final double minHeight;
  final double maxHeight;
  final Color background;
  final Widget Function(BuildContext context, double shrinkOffset) builder;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(
        color: background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: builder(context, shrinkOffset),
        ),
      );

  // The builder closes over page state (step, locale) that changes between
  // builds, so always rebuild; the demo keeps its state through its key.
  @override
  bool shouldRebuild(_DemoHeaderDelegate oldDelegate) => true;
}

class _LayoutIconBadge extends StatelessWidget {
  const _LayoutIconBadge({required this.type, this.large = false});

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
