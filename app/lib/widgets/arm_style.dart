/// Colours and badges shared by the overlay, the 3D caption and the step card.
library;

import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/analysis.dart';

/// Colour used for an [Arm] everywhere in the UI.
Color armColor(Arm arm) => switch (arm) {
      Arm.left => const Color(0xFF2E7DFF),
      Arm.right => const Color(0xFFFF7A1A),
      Arm.both => const Color(0xFF2BB673),
    };

/// Small rounded badge naming the arm.
class ArmBadge extends StatelessWidget {
  const ArmBadge({super.key, required this.arm, this.compact = false});

  final Arm arm;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final color = armColor(arm);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (arm) {
              Arm.left => Icons.arrow_back,
              Arm.right => Icons.arrow_forward,
              Arm.both => Icons.compare_arrows,
            },
            size: compact ? 14 : 16,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            compact ? s.armShort(arm) : s.armLabel(arm),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
