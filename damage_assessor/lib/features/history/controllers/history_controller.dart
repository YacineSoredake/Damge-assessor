import 'package:get/get.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/middleware/auth_middleware.dart';
import '../../../../core/routes/app_routes.dart';
import '../data/history_repository.dart';
import '../data/models/history_item_model.dart';

class HistoryController extends GetxController {
  final HistoryRepository _repository;
  HistoryController(this._repository);

  final items = <HistoryItem>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  final searchQuery = ''.obs;
  final errorMessage = RxnString();

  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    loadFirstPage();
  }

  Future<void> loadFirstPage() async {
    _page = 1;
    hasMore.value = true;
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final results = await _repository.fetchPage(page: _page, search: searchQuery.value);
      items.value = results;
      hasMore.value = results.length == 20;
    } catch (e) {
      _handleError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    try {
      _page++;
      final results = await _repository.fetchPage(page: _page, search: searchQuery.value);
      items.addAll(results);
      hasMore.value = results.length == 20;
    } catch (e) {
      _page--; // roll back so a retry (e.g. scrolling again) re-attempts the same page
      _handleError(e);
    } finally {
      isLoadingMore.value = false;
    }
  }

  void search(String query) {
    searchQuery.value = query;
    loadFirstPage();
  }

  void openAssessment(HistoryItem item) {
    if (item.status == 'complete') {
      Get.toNamed(AppRoutes.reportPreview, arguments: item.id);
    } else {
      Get.snackbar('Not ready', 'This assessment hasn\'t finished analysis yet.');
    }
  }

  void _handleError(Object e) {
    if (e is AuthFailure) {
      Get.find<SessionState>().markLoggedOut();
      Get.offAllNamed(AppRoutes.login);
      return;
    }
    final failure = e is Failure ? e : const UnknownFailure();
    errorMessage.value = failure.message;
  }
}