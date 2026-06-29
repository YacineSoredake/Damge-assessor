import 'package:get/get.dart';
import '../controllers/analysis_controller.dart';
import '../data/analysis_repository.dart';

class AnalysisBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AnalysisRepository>(() => AnalysisRepository());
    Get.lazyPut<AnalysisController>(() => AnalysisController(Get.find()));
  }
}
