import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/config/theme.dart';
import '../controllers/subscription_controller.dart';
import '../data/subscription_repository.dart';
import 'widgets/plan_card.dart';

class PaywallScreen extends GetView<SubscriptionController> {
  const PaywallScreen({super.key});

  // TODO: replace with real DZD pricing once decided.
  static const monthlyPriceLabel = '1 500 DZD / month';
  static const yearlyPriceLabel = '14 400 DZD / year';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscribe')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unlock unlimited assessments', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text(
                'Your free report has been used. Subscribe to keep assessing vehicles.',
                style: TextStyle(color: AppColors.slate),
              ),
              const SizedBox(height: 24),

              Obx(() => PlanCard(
                    plan: SubscriptionPlan.yearly,
                    priceLabel: yearlyPriceLabel,
                    badge: 'Save 20%',
                    selected: controller.selectedPlan.value == SubscriptionPlan.yearly,
                    onTap: () => controller.selectPlan(SubscriptionPlan.yearly),
                  )),
              const SizedBox(height: 12),
              Obx(() => PlanCard(
                    plan: SubscriptionPlan.monthly,
                    priceLabel: monthlyPriceLabel,
                    selected: controller.selectedPlan.value == SubscriptionPlan.monthly,
                    onTap: () => controller.selectPlan(SubscriptionPlan.monthly),
                  )),

              const SizedBox(height: 24),
              Obx(() {
                final msg = controller.errorMessage.value;
                if (msg == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(msg, style: const TextStyle(color: AppColors.red)),
                );
              }),

              Obx(() {
                final status = controller.checkoutStatus.value;

                if (status == CheckoutStatus.awaitingConfirmation) {
                  return Column(
                    children: [
                      const Text(
                        'Complete the payment in your browser, then come back and tap below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.slate),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: controller.checkPaymentStatus,
                          child: const Text("I've completed payment"),
                        ),
                      ),
                    ],
                  );
                }

                final isLaunching = status == CheckoutStatus.launching;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLaunching ? null : controller.startCheckout,
                    child: isLaunching
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Continue to payment'),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
