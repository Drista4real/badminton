// ===============================
// FILE: lib/views/app/onboarding/onboarding_controller.dart
// ===============================

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../controllers/app/splash_controller.dart';
import '../../../routes/app_routes.dart';

class OnboardingController extends GetxController {
  RxInt currentPage = 0.obs;

  void changePage(int index) {
    currentPage.value = index;
  }

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SplashController.onboardingSeenKey, true);
    Get.offNamed(AppRoutes.login);
  }
}
