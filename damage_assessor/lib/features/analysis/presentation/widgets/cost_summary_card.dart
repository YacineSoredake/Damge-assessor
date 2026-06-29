import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/theme.dart';

class CostSummaryCard extends StatelessWidget {
  final int? min;
  final int? max;
  const CostSummaryCard({super.key, this.min, this.max});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.decimalPattern();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.lightBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estimated repair cost', style: TextStyle(color: AppColors.slate, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            min != null && max != null
                ? '${formatter.format(min)} – ${formatter.format(max)} DZD'
                : 'Estimate unavailable',
            style: const TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
