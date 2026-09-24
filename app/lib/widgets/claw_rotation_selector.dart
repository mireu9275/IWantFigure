/// Compact chooser for the claw twist the player observed while the claw
/// descended (집게 회전 / アームの回転): unknown, none, clockwise or
/// counter-clockwise.
library;

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/analysis.dart';

/// Label plus one [ChoiceChip] per [ClawRotation]. Wraps to a second line
/// when the labels are long (English), so it never overflows.
class ClawRotationSelector extends StatelessWidget {
  const ClawRotationSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final ClawRotation value;
  final ValueChanged<ClawRotation> onChanged;
  final bool enabled;

  static IconData iconFor(ClawRotation r) => switch (r) {
        ClawRotation.clockwise => Icons.rotate_right,
        ClawRotation.counterClockwise => Icons.rotate_left,
        ClawRotation.none => Icons.remove,
        ClawRotation.unknown => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Tooltip(
      message: s.clawRotationHint,
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rotate_right, size: 16),
                const SizedBox(width: 4),
                Text(s.clawRotationTitle, style: theme.textTheme.labelLarge),
              ],
            ),
          ),
          for (final r in ClawRotation.values)
            ChoiceChip(
              avatar: switch (r) {
                ClawRotation.clockwise => const Icon(Icons.rotate_right, size: 16),
                ClawRotation.counterClockwise => const Icon(Icons.rotate_left, size: 16),
                _ => null,
              },
              label: Text(s.clawRotationLabel(r)),
              selected: value == r,
              onSelected: enabled ? (_) => onChanged(r) : null,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              labelStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
        ],
      ),
    );
  }
}
