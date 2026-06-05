import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_controller.dart';
import '../../data/repository/auth_repository.dart';
import '../../routes/app_routes.dart';

class SplashController extends GetxController {
  SplashController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  static const _splashDelay = Duration(milliseconds: 2500);
  static const onboardingSeenKey = 'has_seen_onboarding';

  final AuthRepository _authRepository;

  @override
  void onReady() {
    super.onReady();
    _redirectAfterDelay();
  }

  Future<void> _redirectAfterDelay() async {
    await Future.delayed(_splashDelay);

    final user = await _authRepository.reloadCurrentUser();
    final prefs = await SharedPreferences.getInstance();
    final pendingVerificationUserId = prefs.getString(
      AuthController.pendingEmailVerificationUserKey,
    );

    if (user != null &&
        pendingVerificationUserId == user.uid &&
        !_authRepository.requiresEmailVerification(user)) {
      try {
        await _authRepository.ensureUserDocument(user);
      } catch (_) {
        // Profile sync must not keep verified users stuck on splash.
      }
      await prefs.remove(AuthController.pendingEmailVerificationUserKey);
      await _authRepository.signOut();
      Get.offNamed(AppRoutes.login);
      return;
    }

    if (user != null && _authRepository.requiresEmailVerification(user)) {
      Get.offNamed(AppRoutes.otp);
      return;
    }

    if (user != null) {
      Get.offNamed(AppRoutes.home);
      return;
    }

    final hasSeenOnboarding = prefs.getBool(onboardingSeenKey) ?? false;

    Get.offNamed(hasSeenOnboarding ? AppRoutes.login : AppRoutes.onboarding);
  }
}
