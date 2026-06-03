import 'package:get/get.dart';

import '../../controllers/app/profile_controller.dart';
import '../../data/repository/auth_repository.dart';
import '../../data/repository/user_repository.dart';

class ProfileBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.lazyPut<AuthRepository>(() => AuthRepository(), fenix: true);
    }
    if (!Get.isRegistered<UserRepository>()) {
      Get.lazyPut<UserRepository>(() => UserRepository());
    }

    if (!Get.isRegistered<ProfileController>()) {
      Get.lazyPut<ProfileController>(
        () => ProfileController(
          authRepository: Get.find<AuthRepository>(),
          userRepository: Get.find<UserRepository>(),
        ),
      );
    }
  }
}
