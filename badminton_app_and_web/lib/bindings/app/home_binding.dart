import 'package:get/get.dart';

import '../../controllers/app/home_controller.dart';
import '../../data/network/api_client.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/court_repository.dart';
import '../../data/repository/notification_repository.dart';
import '../../data/repository/user_repository.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(() => AuthRepository(), fenix: true);
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(ApiClient(), permanent: true);
    }
    if (!Get.isRegistered<CourtRepository>()) {
      Get.lazyPut<CourtRepository>(
        () => CourtRepository(apiClient: Get.find<ApiClient>()),
      );
    }
    if (!Get.isRegistered<UserRepository>()) {
      Get.lazyPut<UserRepository>(() => UserRepository());
    }
    if (!Get.isRegistered<NotificationRepository>()) {
      Get.lazyPut<NotificationRepository>(() => NotificationRepository());
    }

    Get.lazyPut<HomeController>(
      () => HomeController(
        courtRepository: Get.find<CourtRepository>(),
        notificationRepository: Get.find<NotificationRepository>(),
        userRepository: Get.find<UserRepository>(),
        authRepository: Get.find<AuthRepository>(),
      ),
    );
  }
}
