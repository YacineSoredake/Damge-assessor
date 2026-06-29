import 'package:get/get.dart';
import '../controllers/report_controller.dart';
import '../data/report_repository.dart';

class ReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ReportRepository>(() => ReportRepository());
    Get.lazyPut<ReportController>(() => ReportController(Get.find()));
  }
}