import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/theme.dart';
import '../../../core/middleware/auth_middleware.dart';
import '../../../core/routes/app_routes.dart';
import '../../history/presentation/widgets/history_list_item.dart';
import '../controllers/dashboard_controller.dart';
import 'widgets/quick_stats_row.dart';
import 'widgets/status_banner.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
              icon: const Icon(Icons.history),
              onPressed: () => Get.toNamed(AppRoutes.history)),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _confirmLogout(context)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.fetchMe,
          child: Obx(() {
            switch (controller.loadStatus.value) {
              case DashboardLoadStatus.loading:
                return const Center(child: CircularProgressIndicator());

              case DashboardLoadStatus.error:
                return _ErrorState(
                  message:
                      controller.errorMessage.value ?? 'Something went wrong.',
                  onRetry: controller.fetchMe,
                );

              case DashboardLoadStatus.loaded:
                final user = controller.user.value!;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.navy, Color(0xFF1E3A8A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.16),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome,
                                    color: Colors.white, size: 16),
                                SizedBox(width: 6),
                                Text('AI-powered workflow',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(_greeting,
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 6),
                          const Text(
                              'Everything you need to assess damage and share a report faster.',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    StatusBanner(user: user),
                    const SizedBox(height: 16),
                    QuickStatsRow(
                        totalAssessments: controller.totalAssessments.value),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: controller.startNewAssessment,
                        icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                        label: const Text('Start new assessment'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Recent assessments',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.navy,
                                      fontSize: 16)),
                              GestureDetector(
                                onTap: () => Get.toNamed(AppRoutes.history),
                                child: const Text('View all',
                                    style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (controller.recentAssessments.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                    'No assessments yet — start your first one above.',
                                    style: TextStyle(color: AppColors.slate)),
                              ),
                            )
                          else
                            ...controller.recentAssessments.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: HistoryListItem(
                                  item: item,
                                  onTap: () {
                                    if (item.status == 'complete') {
                                      Get.toNamed(AppRoutes.reportPreview,
                                          arguments: item.id);
                                    }
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
            }
          }),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
            'You\'ll need to verify your phone number again to sign back in.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await Get.find<SessionState>().markLoggedOut();
              Get.offAllNamed(AppRoutes.login);
            },
            child:
                const Text('Log out', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.slate),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
