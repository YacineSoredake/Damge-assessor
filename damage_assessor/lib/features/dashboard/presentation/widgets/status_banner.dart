import 'package:flutter/material.dart';
import '../../../../core/config/theme.dart';
import '../../../auth/data/models/user_model.dart';

/// Shows trial remaining or subscription state.
class StatusBanner extends StatelessWidget {
  final UserModel user;
  const StatusBanner({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final (text, subtext, color, icon) = _resolve();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtext,
                    style: const TextStyle(
                        color: AppColors.slate, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (String, String, Color, IconData) _resolve() {
    switch (user.subscriptionStatus) {
      case 'active':
        return (
          'Subscription active',
          'You can keep creating reports without interruption.',
          AppColors.green,
          Icons.check_circle_outline
        );
      case 'grace':
        return (
          'Renew soon',
          'Your access is about to expire. Renew to keep using the app smoothly.',
          AppColors.orange,
          Icons.warning_amber_rounded
        );
      case 'expired':
        return (
          'Subscription expired',
          'Please renew to continue creating reports.',
          AppColors.red,
          Icons.error_outline
        );
      default: // 'none'
        return user.freeReportUsed
            ? (
                'Free report used',
                'Your trial report was used. Subscribe to continue creating more reports.',
                AppColors.red,
                Icons.lock_outline
              )
            : (
                '1 free report available',
                'You still have a free report ready to use.',
                AppColors.green,
                Icons.auto_awesome_outlined
              );
    }
  }
}
