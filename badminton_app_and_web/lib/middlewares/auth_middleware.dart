import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/repository/auth_repository.dart';
import '../routes/app_routes.dart';

class AuthMiddleware extends GetMiddleware {
  AuthMiddleware({super.priority});

  @override
  RouteSettings? redirect(String? route) {
    final authRepository = _authRepository;
    final user = authRepository.currentUser;
    if (user == null || user.uid.isEmpty || user.isAnonymous) {
      return RouteSettings(
        name: AppRoutes.login,
        arguments: {'redirect': route},
      );
    }

    if (authRepository.requiresEmailVerification(user)) {
      return const RouteSettings(name: AppRoutes.otp);
    }

    return null;
  }

  AuthRepository get _authRepository {
    if (Get.isRegistered<AuthRepository>()) {
      return Get.find<AuthRepository>();
    }

    return Get.put<AuthRepository>(AuthRepository(), permanent: true);
  }
}
