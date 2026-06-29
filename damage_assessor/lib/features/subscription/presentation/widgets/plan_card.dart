import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';
import '../../data/subscription_repository.dart';

class PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final String priceLabel;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;

  const PlanCard({
    super.key,
    required this.plan,
    required this.priceLabel,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.accent.withOpacity(0.08) : AppColors.lightBg,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.accent : AppColors.slate,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan == SubscriptionPlan.monthly ? 'Monthly' : 'Yearly',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  Text(priceLabel, style: const TextStyle(color: AppColors.slate, fontSize: 13)),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}
