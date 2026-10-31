import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const double _cardRadius = 20;

  static ThemeData light() => _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.gold,
      onPrimary: AppColors.navy,
      secondary: AppColors.navy,
      onSecondary: Colors.white,
      error: AppColors.alert,
      surface: AppColors.cardLight,
      onSurface: AppColors.navy,
    ),
    scaffold: AppColors.pageLight,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: Brightness.dark,
      primary: AppColors.gold,
      onPrimary: AppColors.navy,
      secondary: AppColors.pageLight,
      onSecondary: AppColors.navy,
      error: AppColors.alert,
      surface: AppColors.cardDark,
      onSurface: Colors.white,
    ),
    scaffold: AppColors.pageDark,
  );

  static ThemeData _build(ColorScheme colorScheme, {required Color scaffold}) {
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
      ),
      // Full-width 56 px gold buttons in thumb reach (Fitts's law, board 07).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
        ),
      ),
      // Gold text on the light page is about 1.9:1, below WCAG AA, so secondary buttons use navy.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.secondary,
          side: BorderSide(color: colorScheme.secondary),
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.secondary),
      ),
    );
  }
}
