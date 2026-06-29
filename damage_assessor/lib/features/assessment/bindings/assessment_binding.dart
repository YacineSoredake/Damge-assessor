import 'package:get/get.dart';
import '../controllers/capture_controller.dart';
import '../data/assessment_repository.dart';

class AssessmentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AssessmentRepository>(() => AssessmentRepository());
    Get.lazyPut<CaptureController>(() => CaptureController(Get.find()));
  }
}
