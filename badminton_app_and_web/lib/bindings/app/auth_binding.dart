import 'package:get/get.dart';

import '../../controllers/app/auth_controller.dart';
import '../../data/repository/auth_repository.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.put<AuthRepository>(AuthRepository(), permanent: true);
    }

    if (!Get.isRegistered<AuthController>()) {
      Get.put<AuthController>(
        AuthController(authRepository: Get.find<AuthRepository>()),
        permanent: true,
      );
    }
  }
}
