import 'package:get/get.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/routes/app_routes.dart';
import '../../auth/data/models/user_model.dart';
import '../../history/data/history_repository.dart';
import '../../history/data/models/history_item_model.dart';
import '../data/dashboard_repository.dart';

enum DashboardLoadStatus { loading, loaded, error }

class DashboardController extends GetxController {
  final DashboardRepository _repository;
  final HistoryRepository _historyRepository;
  DashboardController(this._repository, this._historyRepository);

  final loadStatus = DashboardLoadStatus.loading.obs;
  final Rxn<UserModel> user = Rxn<UserModel>();
  final errorMessage = RxnString();

  final recentAssessments = <HistoryItem>[].obs;
  final totalAssessments = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchMe();
  }

  Future<void> fetchMe() async {
    loadStatus.value = DashboardLoadStatus.loading;
    errorMessage.value = null;
    try {
      user.value = await _repository.fetchMe();
      loadStatus.value = DashboardLoadStatus.loaded;
      // Fire-and-forget — these are supplementary stats, a failure here
      // shouldn't block the main dashboard from showing.
      _loadRecentAssessments();
    } catch (e) {
      if (e is AuthFailure) {
        await Get.find<SessionState>().markLoggedOut();
        Get.offAllNamed(AppRoutes.login);
        return;
      }
      final failure = e is Failure ? e : const UnknownFailure();
      errorMessage.value = failure.message;
      loadStatus.value = DashboardLoadStatus.error;
    }
  }

  Future<void> _loadRecentAssessments() async {
    try {
      final results = await _historyRepository.fetchPage(page: 1, limit: 3);
      recentAssessments.value = results;
      totalAssessments.value = await _historyRepository.fetchTotalCount();
    } catch (_) {
      // Non-critical — leave lists empty rather than showing an error
      // for what's just a supplementary preview.
    }
  }

  Future<void> startNewAssessment() async {
    try {
      final freshUser = await _repository.fetchMe();
      user.value = freshUser;

      final canProceed = !freshUser.freeReportUsed ||
          freshUser.subscriptionStatus == 'active' ||
          freshUser.subscriptionStatus == 'grace';

      if (canProceed) {
        Get.toNamed(AppRoutes.vehicleInfo);
      } else {
        Get.toNamed(AppRoutes.paywall);
      }
    } catch (e) {
      if (e is AuthFailure) {
        await Get.find<SessionState>().markLoggedOut();
        Get.offAllNamed(AppRoutes.login);
        return;
      }
      final failure = e is Failure ? e : const UnknownFailure();
      Get.snackbar('Could not start assessment', failure.message);
    }
  }
}