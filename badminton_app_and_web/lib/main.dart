import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'apps/badminton_app.dart';
import 'controllers/app/app_settings_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool(AppSettingsController.darkModeKey) ?? false;
  final initialLocale = AppSettingsController.localeFromTag(
    prefs.getString(AppSettingsController.localeKey),
  );

  Get.put<AppSettingsController>(
    AppSettingsController(
      initialDarkMode: isDarkMode,
      initialLocale: initialLocale,
    ),
    permanent: true,
  );

  runApp(const BadmintonApp());
}
