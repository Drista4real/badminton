import 'package:get/get.dart';

import '../../controllers/app/notification_controller.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/notification_repository.dart';

class NotificationBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(() => AuthRepository(), fenix: true);
    }
    Get.lazyPut<NotificationRepository>(() => NotificationRepository());
    Get.lazyPut<NotificationController>(
      () => NotificationController(
        notificationRepository: Get.find<NotificationRepository>(),
        authRepository: Get.find<AuthRepository>(),
      ),
    );
  }
}
