import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/theme.dart';
import '../../data/models/history_item_model.dart';

class HistoryListItem extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onTap;
  const HistoryListItem({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isComplete = item.status == 'complete';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: isComplete
            ? AppColors.conditionColor(item.overallCondition ?? '').withOpacity(0.15)
            : AppColors.lightBg,
        child: Icon(
          isComplete ? Icons.directions_car : Icons.hourglass_top,
          color: isComplete ? AppColors.conditionColor(item.overallCondition ?? '') : AppColors.slate,
        ),
      ),
      title: Text(item.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(item.vehicle ?? (isComplete ? (item.overallCondition ?? '') : item.status)),
      trailing: Text(
        DateFormat('dd MMM').format(item.createdAt),
        style: const TextStyle(color: AppColors.slate, fontSize: 12),
      ),
    );
  }
}