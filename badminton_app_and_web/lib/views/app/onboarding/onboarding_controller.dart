// ===============================
// FILE: lib/views/app/onboarding/onboarding_controller.dart
// ===============================

import 'package:get/get.dart';

class OnboardingController extends GetxController {
  RxInt currentPage = 0.obs;

  void changePage(int index) {
    currentPage.value = index;
  }
}