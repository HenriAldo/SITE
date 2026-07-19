import 'package:flutter/material.dart';
import '../../data/models/assessment.dart';

class RiskBadge extends StatelessWidget {
  final RiskLevel riskLevel;
  final bool large;

  const RiskBadge({super.key, required this.riskLevel, this.large = false});

  @override
  Widget build(BuildContext context) {
    final padding = large
        ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    final fontSize = large ? 16.0 : 13.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: riskLevel.backgroundColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: riskLevel.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(riskLevel.icon, color: riskLevel.color, size: large ? 20 : 14),
          const SizedBox(width: 6),
          Text(
            riskLevel.label,
            style: TextStyle(
              color: riskLevel.color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
