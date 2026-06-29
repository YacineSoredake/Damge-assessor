import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';

class ConditionBadgesRow extends StatelessWidget {
  final String? overallCondition;
  final String? drivability;
  final String? totalLossRisk;

  const ConditionBadgesRow({
    super.key,
    this.overallCondition,
    this.drivability,
    this.totalLossRisk,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (overallCondition != null) _badge('Condition: $overallCondition', AppColors.conditionColor(overallCondition!)),
        if (drivability != null) _badge(drivability!.replaceAll('_', ' '), AppColors.navy),
        if (totalLossRisk != null) _badge('Risk: $totalLossRisk', AppColors.conditionColor(totalLossRisk!)),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
