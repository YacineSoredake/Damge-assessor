import 'package:get/get.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../controllers/subscription_controller.dart';
import '../data/subscription_repository.dart';

class SubscriptionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SubscriptionRepository>(() => SubscriptionRepository());
    Get.lazyPut<DashboardRepository>(() => DashboardRepository());
    Get.lazyPut<SubscriptionController>(() => SubscriptionController(Get.find(), Get.find()));
  }
}
