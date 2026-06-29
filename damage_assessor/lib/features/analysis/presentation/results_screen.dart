import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/theme.dart';
import '../../../core/routes/app_routes.dart';
import '../controllers/analysis_controller.dart';
import 'widgets/annotated_photos_carousel.dart';
import 'widgets/condition_badges_row.dart';
import 'widgets/cost_summary_card.dart';
import 'widgets/damage_region_tile.dart';

class ResultsScreen extends GetView<AnalysisController> {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final result = controller.result.value;
      if (result == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Assessment results')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (result.vehicle != null) ...[
                Text(result.vehicle!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
                const SizedBox(height: 10),
              ],

              AnnotatedPhotosCarousel(photos: result.photos),
              const SizedBox(height: 16),

              ConditionBadgesRow(
                overallCondition: result.overallCondition,
                drivability: result.drivability,
                totalLossRisk: result.totalLossRisk,
              ),
              const SizedBox(height: 16),
              CostSummaryCard(min: result.totalCostMinDzd, max: result.totalCostMaxDzd),
              const SizedBox(height: 16),

              if (result.structuralIntegrity != null || result.hiddenDamageRisk != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: AppColors.lightBg, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (result.structuralIntegrity != null)
                        Text('Structural integrity: ${result.structuralIntegrity}', style: const TextStyle(color: AppColors.slate, fontSize: 13)),
                      if (result.hiddenDamageRisk != null)
                        Text('Hidden damage risk: ${result.hiddenDamageRisk}', style: const TextStyle(color: AppColors.slate, fontSize: 13)),
                    ],
                  ),
                ),

              if (result.summary != null) ...[
                const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 6),
                Text(result.summary!, style: const TextStyle(color: AppColors.slate)),
                const SizedBox(height: 20),
              ],

              if (result.primaryConcerns.isNotEmpty) ...[
                const Text('Primary concerns', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 6),
                ...result.primaryConcerns.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('•  '),
                          Expanded(child: Text(c, style: const TextStyle(color: AppColors.slate))),
                        ],
                      ),
                    )),
                const SizedBox(height: 20),
              ],

              Text(
                'Damage regions (${result.damageRegions.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 10),

              if (result.damageRegions.isEmpty)
                // Per the spec: zero damage is a valid, billable result —
                // not an error state.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.lightBg, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.green),
                      SizedBox(width: 10),
                      Expanded(child: Text('No damage detected.')),
                    ],
                  ),
                )
              else
                ...result.damageRegions.map((r) => DamageRegionTile(region: r)),

              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Get.toNamed(AppRoutes.reportPreview, arguments: result.id),
                  child: const Text('Generate report'),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
