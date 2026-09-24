/// Result: photo overlay / 3D scene / explanation tabs, the current-step card
/// and the observation buttons that drive the next recommendation.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../engine/aim_engine.dart';
import '../l10n/strings.dart';
import '../scene3d/scene_painter.dart' show SceneLabels;
import '../scene3d/scene_view.dart';
import '../services/history_store.dart';
import '../services/session_controller.dart';
import '../widgets/explanation_tab.dart';
import '../widgets/observation_bar.dart';
import '../widgets/photo_overlay.dart';
import '../widgets/prize_sheet.dart';
import '../widgets/step_card.dart';

/// Shows the [AimPlan] of [controller]. When the controller is read-only
/// (reopened from history) the observation controls are hidden.
class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _editing = false;

  /// True while the photo is zoomed in; horizontal pans then belong to the
  /// photo, not to the tab swipe.
  bool _zoomed = false;

  SessionController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (_tabs.index != 0 && _editing) setState(() => _editing = false);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _finish(SessionOutcome outcome) async {
    final s = S.of(context);
    final result = await _askPlaysAndYen(context, s, outcome);
    if (result == null || !mounted) return;
    try {
      await c.finish(outcome, plays: result.$1, yen: result.$2);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.saveFailed(_describeError(e)))),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.savedToHistory)));
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  static String _describeError(Object e) => switch (e) {
        FileSystemException(:final message, :final osError) =>
          osError == null ? message : '$message (${osError.message})',
        _ => e.toString(),
      };

  Future<(int, int)?> _askPlaysAndYen(BuildContext context, S s, SessionOutcome outcome) {
    final plays = TextEditingController(text: '${c.playsFromObservations}');
    final yen = TextEditingController(text: '${c.playsFromObservations * 100}');
    return showDialog<(int, int)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(outcome == SessionOutcome.success ? s.outcomeSuccess : s.outcomeFail),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: plays,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.playsCount),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: yen,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.yenSpent),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(s.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop((
              int.tryParse(plays.text.trim()) ?? c.playsFromObservations,
              int.tryParse(yen.text.trim()) ?? 0,
            )),
            child: Text(s.save),
          ),
        ],
      ),
    ).whenComplete(() {
      plays.dispose();
      yen.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final plan = c.plan;
        final analysis = c.analysis;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(plan == null ? s.appName : s.layoutLabel(plan.layoutType), maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (_tabs.index == 0 && plan != null && plan.canPlan && !c.readOnly)
                IconButton(
                  tooltip: s.correct,
                  isSelected: _editing,
                  selectedIcon: Icon(Icons.edit, color: scheme.primary),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => setState(() => _editing = !_editing),
                ),
              if (!c.readOnly)
                IconButton(
                  tooltip: s.prizeInfo,
                  icon: const Icon(Icons.inventory_2_outlined),
                  onPressed: () => showPrizeSheet(context, c),
                ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: s.tabPhoto, icon: const Icon(Icons.photo_outlined, size: 18), height: 56),
                Tab(text: s.tab3d, icon: const Icon(Icons.view_in_ar_outlined, size: 18), height: 56),
                Tab(text: s.tabExplain, icon: const Icon(Icons.notes, size: 18), height: 56),
              ],
            ),
          ),
          body: plan == null || analysis == null
              ? Center(child: Text(s.noPlanTitle))
              : Column(
                  children: [
                    Expanded(
                      child: TabBarView(
                        controller: _tabs,
                        physics: _editing || _zoomed ? const NeverScrollableScrollPhysics() : null,
                        children: [
                          _photoTab(context, s, plan, analysis),
                          SceneView(
                            scene: plan.scene,
                            caption: plan.current?.title,
                            labels: SceneLabels(
                              dropHole: s.labelDropHole,
                              front: s.sceneFront,
                              resetView: s.resetView,
                              playMotion: s.playMotion,
                              pauseMotion: s.pauseMotion,
                            ),
                          ),
                          ExplanationTab(plan: plan, analysis: analysis),
                        ],
                      ),
                    ),
                    _bottomPanel(context, s, plan),
                  ],
                ),
        );
      },
    );
  }

  Widget _photoTab(BuildContext context, S s, AimPlan plan, analysis) {
    final target = analysis.targetPrize;
    final others = <dynamic>[
      for (final o in analysis.objects)
        if (o.id != target?.id && (o.kind.isPrize || o.kind.isBar)) o,
    ];
    return Column(
      children: [
        Expanded(
          child: PhotoOverlay(
            imageBytes: c.photo.bytes,
            imageWidth: c.photo.width,
            imageHeight: c.photo.height,
            plan: plan,
            corrections: c.corrections,
            editing: _editing,
            onCorrectionsChanged: c.setCorrections,
            otherObjects: others.cast(),
            onZoomChanged: (z) {
              if (z != _zoomed && mounted) setState(() => _zoomed = z);
            },
          ),
        ),
        if (_editing)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.correctHint, style: Theme.of(context).textTheme.bodySmall)),
                  TextButton(
                    onPressed: c.corrections.isEmpty ? null : () => c.setCorrections(SceneCorrections.none),
                    child: Text(s.reset),
                  ),
                  FilledButton.tonal(
                    onPressed: () => setState(() => _editing = false),
                    child: Text(s.done),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _bottomPanel(BuildContext context, S s, AimPlan plan) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.readOnly)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(s.readOnlyBanner, style: Theme.of(context).textTheme.labelMedium)),
                      Text(
                        '${_outcomeLabel(s, c.outcome)} · ${s.playsAndYen(c.plays, c.yen)}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              CurrentStepCard(plan: plan, dense: true),
              if (!c.readOnly) ...[
                const SizedBox(height: 6),
                if (plan.finished)
                  _finishedBanner(context, s)
                else ...[
                  ObservationBar(
                    onObserve: c.addObservation,
                    onUndo: c.undoObservation,
                    canUndo: c.observations.isNotEmpty,
                    enabled: plan.canPlan,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _finish(SessionOutcome.fail),
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: Text(s.giveUp),
                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _finishedBanner(BuildContext context, S s) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.celebration, color: scheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(child: Text(s.finishedBanner, style: TextStyle(color: scheme.onPrimaryContainer))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: c.undoObservation,
                icon: const Icon(Icons.undo, size: 18),
                label: Text(s.undo),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _finish(SessionOutcome.success),
                icon: const Icon(Icons.check),
                label: Text(s.done),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _outcomeLabel(S s, SessionOutcome o) => switch (o) {
        SessionOutcome.success => s.outcomeSuccess,
        SessionOutcome.fail => s.outcomeFail,
        SessionOutcome.open => s.outcomeOpen,
      };
}
