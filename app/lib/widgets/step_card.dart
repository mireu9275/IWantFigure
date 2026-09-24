/// Card describing the play to make now.
library;

import 'package:flutter/material.dart';

import '../engine/aim_engine.dart';
import '../l10n/strings.dart';
import 'arm_style.dart';

/// Shows the current [AimStep]: index/total, arm badge, technique chip,
/// title and detail.
class CurrentStepCard extends StatelessWidget {
  const CurrentStepCard({super.key, required this.plan, this.dense = false});

  final AimPlan plan;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final step = plan.current;
    final scheme = Theme.of(context).colorScheme;
    if (step == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(child: Text(s.noPlanTitle)),
            ],
          ),
        ),
      );
    }
    final color = armColor(step.arm);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(dense ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.currentStep,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.outline),
                ),
                const SizedBox(width: 8),
                Text(
                  s.stepOf(step.index, plan.steps.length),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(width: 8),
                // Badges flow to a second line when the labels are long
                // (English / Japanese technique names).
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ArmBadge(arm: step.arm, compact: dense),
                      Chip(
                        label: Text(s.techniqueLabel(step.technique), overflow: TextOverflow.ellipsis),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        labelStyle: const TextStyle(fontSize: 11),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              step.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (step.detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                step.detail,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: dense ? 2 : 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
