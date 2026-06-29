import 'package:get/get.dart';
import '../../history/data/history_repository.dart';
import '../controllers/dashboard_controller.dart';
import '../data/dashboard_repository.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardRepository>(() => DashboardRepository());
    Get.lazyPut<HistoryRepository>(() => HistoryRepository());
    Get.lazyPut<DashboardController>(() => DashboardController(Get.find(), Get.find()));
  }
}