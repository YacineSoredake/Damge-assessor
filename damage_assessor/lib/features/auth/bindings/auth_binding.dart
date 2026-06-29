import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../data/auth_repository.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AuthRepository>(() => AuthRepository());
    Get.lazyPut<AuthController>(() => AuthController(Get.find()));
  }
}
