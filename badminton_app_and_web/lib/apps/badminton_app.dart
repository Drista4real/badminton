import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../commons/styles/app_theme.dart';
import '../controllers/app/app_settings_controller.dart';
import '../localization/app_translations.dart';
import '../routes/app_pages.dart';

class BadmintonApp extends StatelessWidget {
  const BadmintonApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<AppSettingsController>();

    return Obx(
      () => GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Badminton Booking',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: settings.themeMode.value,
        translations: AppTranslations(),
        locale: settings.locale.value,
        fallbackLocale: AppSettingsController.vietnameseLocale,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    );
  }
}
