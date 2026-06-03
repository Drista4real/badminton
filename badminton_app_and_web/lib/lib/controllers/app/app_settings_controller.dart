import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsController extends GetxController {
  AppSettingsController({
    required bool initialDarkMode,
    required Locale initialLocale,
  }) : isDarkMode = initialDarkMode.obs,
       locale = initialLocale.obs,
       themeMode = (initialDarkMode ? ThemeMode.dark : ThemeMode.light).obs;

  static const englishLocale = Locale('en', 'US');
  static const vietnameseLocale = Locale('vi', 'VN');
  static const darkModeKey = 'is_dark_mode';
  static const localeKey = 'app_locale';

  final RxBool isDarkMode;
  final Rx<Locale> locale;
  final Rx<ThemeMode> themeMode;

  Future<void> setDarkMode(bool value) async {
    isDarkMode.value = value;
    themeMode.value = value ? ThemeMode.dark : ThemeMode.light;
    Get.changeThemeMode(themeMode.value);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(darkModeKey, value);
  }

  Future<void> setLanguage(String languageCode) async {
    final nextLocale = languageCode == 'en' ? englishLocale : vietnameseLocale;
    locale.value = nextLocale;
    Get.updateLocale(nextLocale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localeKey, localeTag(nextLocale));
  }

  static Locale localeFromTag(String? value) {
    switch (value) {
      case 'en_US':
        return englishLocale;
      case 'vi_VN':
        return vietnameseLocale;
      default:
        return vietnameseLocale;
    }
  }

  static String localeTag(Locale locale) {
    return '${locale.languageCode}_${locale.countryCode ?? ''}';
  }
}
