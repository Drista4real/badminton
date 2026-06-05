import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const fontFamily = 'Poppins';

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.black,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.65),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      textTheme: _textTheme(Brightness.light),
    );
  }

  static ThemeData get dark {
    const darkSurface = Color(0xFF101414);
    const darkCard = Color(0xFF18201F);
    const darkText = Color(0xFFEAF3F1);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.secondary,
      secondary: AppColors.primary,
      surface: darkSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkSurface,
      cardColor: darkCard,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.secondary.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      textTheme: _textTheme(Brightness.dark),
    );
  }

  static TextTheme _textTheme(Brightness brightness) {
    final textColor = brightness == Brightness.dark
        ? const Color(0xFFEAF3F1)
        : AppColors.black;
    final mutedColor = brightness == Brightness.dark
        ? const Color(0xFFB7C7C4)
        : AppColors.grey;

    return TextTheme(
      headlineSmall: TextStyle(
        color: textColor,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        color: mutedColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}
