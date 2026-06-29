import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';
import '../../data/models/result_model.dart';

class DamageRegionTile extends StatelessWidget {
  final DamageRegion region;
  const DamageRegionTile({super.key, required this.region});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ExpansionTile(
        title: Text(
          region.carPart ?? 'Unknown part',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
        ),
        subtitle: Text(region.damageType ?? '—'),
        trailing: region.severityLabel != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.conditionColor(region.severityLabel!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  region.severityLabel!.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (region.isLowConfidence)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Low confidence — recommend manual review',
                      style: TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (region.description != null) Text(region.description!, style: const TextStyle(color: AppColors.slate, fontSize: 13)),
                const SizedBox(height: 6),
                if (region.repairMethod != null) Text('Repair method: ${region.repairMethod}'),
                if (region.costMinDzd != null && region.costMaxDzd != null)
                  Text('Cost: ${region.costMinDzd} – ${region.costMaxDzd} DZD'),
                if (region.priority != null)
                  Text('Priority: ${region.priority}', style: const TextStyle(color: AppColors.slate, fontSize: 12)),
                if (region.safetyRisk)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('⚠ Safety risk', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
                  ),
                if (region.notes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(region.notes!, style: const TextStyle(color: AppColors.slate, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
