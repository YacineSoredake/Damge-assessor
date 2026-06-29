import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/routes/app_routes.dart';
import '../../auth/data/models/user_model.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/subscription_repository.dart';

enum CheckoutStatus { idle, launching, awaitingConfirmation, error }

class SubscriptionController extends GetxController {
  final SubscriptionRepository _repository;
  final DashboardRepository _dashboardRepository; // reused to re-check /me after payment
  SubscriptionController(this._repository, this._dashboardRepository);

  final selectedPlan = SubscriptionPlan.yearly.obs; // yearly pre-selected — nudges the better-value plan
  final checkoutStatus = CheckoutStatus.idle.obs;
  final errorMessage = RxnString();

  void selectPlan(SubscriptionPlan plan) => selectedPlan.value = plan;

  /// Opens the Chargily checkout page in an external browser.
  /// Payment confirmation itself happens via the backend webhook,
  /// not anything we can detect client-side — so once they return to
  /// the app, we re-check /me to see if it actually went through.
  Future<void> startCheckout() async {
    checkoutStatus.value = CheckoutStatus.launching;
    errorMessage.value = null;
    try {
      final url = await _repository.createCheckout(selectedPlan.value);
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched) {
        throw const UnknownFailure('Could not open the payment page.');
      }
      checkoutStatus.value = CheckoutStatus.awaitingConfirmation;
    } catch (e) {
      final failure = e is Failure ? e : const UnknownFailure();
      errorMessage.value = failure.message;
      checkoutStatus.value = CheckoutStatus.error;
    }
  }

  /// Called when the user taps "I've completed payment" after returning
  /// from the browser. Re-fetches live status — if the webhook already
  /// processed, subscription_status will reflect it; if not yet (webhook
  /// can lag a few seconds), we tell them to wait and retry rather than
  /// falsely confirming success.
  Future<void> checkPaymentStatus() async {
    try {
      final UserModel user = await _dashboardRepository.fetchMe();
      if (user.subscriptionStatus == 'active') {
        Get.offAllNamed(AppRoutes.dashboard);
      } else {
        Get.snackbar(
          'Payment not confirmed yet',
          'This can take a few seconds. Please try again shortly.',
        );
      }
    } catch (e) {
      final failure = e is Failure ? e : const UnknownFailure();
      Get.snackbar('Could not check status', failure.message);
    }
  }
}
