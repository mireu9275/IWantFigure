/// Buttons the player taps after each play to report what happened.
library;

import 'package:flutter/material.dart';

import '../engine/inputs.dart';
import '../l10n/strings.dart';

/// Row of observation buttons plus an undo button.
class ObservationBar extends StatelessWidget {
  const ObservationBar({
    super.key,
    required this.onObserve,
    required this.onUndo,
    required this.canUndo,
    this.enabled = true,
  });

  final ValueChanged<ObservationKind> onObserve;
  final VoidCallback onUndo;
  final bool canUndo;
  final bool enabled;

  static IconData iconFor(ObservationKind k) => switch (k) {
        ObservationKind.noMove => Icons.block,
        ObservationKind.smallMove => Icons.trending_flat,
        ObservationKind.bigMove => Icons.double_arrow,
        ObservationKind.lifted => Icons.arrow_upward,
        ObservationKind.dropped => Icons.celebration,
        ObservationKind.stuck => Icons.lock_outline,
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(s.afterPlay, style: Theme.of(context).textTheme.labelLarge),
            ),
            TextButton.icon(
              onPressed: canUndo && enabled ? onUndo : null,
              icon: const Icon(Icons.undo, size: 18),
              label: Text(s.undo),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final k in ObservationKind.values)
              ActionChip(
                avatar: Icon(
                  iconFor(k),
                  size: 16,
                  color: k == ObservationKind.dropped
                      ? scheme.primary
                      : (k == ObservationKind.stuck ? scheme.error : null),
                ),
                label: Text(s.observationLabel(k)),
                onPressed: enabled ? () => onObserve(k) : null,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}
