import 'package:get/get.dart';

import '../controllers/app/splash_controller.dart';
import '../data/repository/auth_repository.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(() => AuthRepository(), fenix: true);
    }

    Get.put<SplashController>(
      SplashController(authRepository: Get.find<AuthRepository>()),
    );
  }
}
