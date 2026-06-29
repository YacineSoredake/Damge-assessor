import 'package:get/get.dart';
import '../controllers/history_controller.dart';
import '../data/history_repository.dart';

class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HistoryRepository>(() => HistoryRepository());
    Get.lazyPut<HistoryController>(() => HistoryController(Get.find()));
  }
}