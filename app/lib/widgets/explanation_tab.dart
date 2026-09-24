/// The "explain" tab: what was detected, why this aim point, the full play
/// sequence, when to stop, warnings and machine information.
library;

import 'package:flutter/material.dart';

import '../engine/aim_engine.dart';
import '../l10n/strings.dart';
import '../models/analysis.dart';
import 'arm_style.dart';

/// Scrollable explanation of [plan] and the underlying [analysis].
class ExplanationTab extends StatelessWidget {
  const ExplanationTab({super.key, required this.plan, required this.analysis});

  final AimPlan plan;
  final AnalysisResult analysis;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _section(context, s.sectionSummary, [
          _kv(context, s.layoutType, s.layoutLabel(plan.layoutType)),
          _kv(context, s.technique, s.techniqueLabel(plan.technique)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 110, child: Text(s.confidence, style: theme.textTheme.labelLarge)),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: plan.confidence, minHeight: 8),
                  ),
                ),
                const SizedBox(width: 8),
                Text(s.confidencePercent(plan.confidence)),
              ],
            ),
          ),
          _kv(context, s.armPower, '${s.armPowerLabel(plan.armPowerEstimate)} (${s.estimated})'),
          if (analysis.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.llmExplanation, style: theme.textTheme.labelLarge),
            Text(analysis.explanation),
          ],
          if (analysis.strategy.expectedMotion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(s.expectedMotion, style: theme.textTheme.labelLarge),
            Text(analysis.strategy.expectedMotion),
          ],
          const SizedBox(height: 8),
          Text(s.disclaimerShort, style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline)),
        ]),
        if (plan.rationale.isNotEmpty)
          _section(context, s.sectionRationale, [for (final r in plan.rationale) _bullet(context, r)]),
        if (plan.steps.isNotEmpty)
          _section(context, s.sectionSteps, [
            for (final st in plan.steps) _stepTile(context, st, st.index - 1 == plan.currentStepIndex),
          ]),
        if (plan.abortIf.isNotEmpty)
          _section(context, s.sectionAbort, [
            for (final a in plan.abortIf) _bullet(context, a, icon: Icons.stop_circle_outlined, color: scheme.error),
          ]),
        if (plan.warnings.isNotEmpty)
          _section(context, s.sectionWarnings, [
            for (final w in plan.warnings)
              _bullet(context, w, icon: Icons.warning_amber_rounded, color: scheme.tertiary),
          ]),
        if (plan.requestedPhotos.isNotEmpty)
          _section(context, s.sectionRequestedPhotos, [
            for (final p in plan.requestedPhotos) _bullet(context, p, icon: Icons.photo_camera_outlined),
          ]),
        _section(context, s.sectionMachine, [
          _kv(context, s.clawCount, s.clawCountLabel(analysis.machine.clawCount)),
          _kv(context, s.armPower, s.armPowerLabel(analysis.machine.armPower)),
          _kv(context, s.assistLamp, s.assistLampLabel(analysis.machine.assistLamp)),
          _kv(context, s.exitSide, s.exitSideLabel(analysis.machine.exitSide)),
        ]),
        _section(context, s.sectionAnalysis, [
          _kv(context, s.provider, [analysis.provider, analysis.model].where((e) => e.isNotEmpty).join(' · ')),
          if (analysis.latencyMs > 0) _kv(context, 'latency', '${analysis.latencyMs} ms'),
          if (analysis.analysisId.isNotEmpty) _kv(context, 'id', analysis.analysisId),
        ]),
      ],
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      );

  Widget _kv(BuildContext context, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 110, child: Text(k, style: Theme.of(context).textTheme.labelLarge)),
            Expanded(child: Text(v.isEmpty ? '—' : v)),
          ],
        ),
      );

  Widget _bullet(BuildContext context, String text, {IconData icon = Icons.circle, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 8),
              child: Icon(icon, size: icon == Icons.circle ? 8 : 16, color: color),
            ),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Widget _stepTile(BuildContext context, AimStep st, bool current) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final color = armColor(st.arm);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: current ? color.withValues(alpha: 0.10) : null,
        border: Border.all(color: current ? color : scheme.outlineVariant, width: current ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: current ? color : scheme.surfaceContainerHighest,
                child: Text(
                  '${st.index}',
                  style: TextStyle(fontSize: 12, color: current ? Colors.white : null, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              ArmBadge(arm: st.arm, compact: true),
              const SizedBox(width: 6),
              Flexible(child: Text(s.techniqueLabel(st.technique), style: Theme.of(context).textTheme.labelSmall)),
            ],
          ),
          const SizedBox(height: 6),
          Text(st.title, style: Theme.of(context).textTheme.titleSmall),
          if (st.detail.isNotEmpty) Text(st.detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
