import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light(ColorScheme? dynamicScheme) {
    final scheme =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: AppColors.maroon,
          brightness: Brightness.light,
        ).copyWith(secondary: AppColors.turmeric, surface: AppColors.parchment);
    return _themeFrom(scheme);
  }

  static ThemeData dark(ColorScheme? dynamicScheme) {
    final scheme =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: AppColors.maroon,
          brightness: Brightness.dark,
        ).copyWith(secondary: AppColors.turmeric, surface: AppColors.charcoal);
    return _themeFrom(scheme);
  }

  static ThemeData _themeFrom(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: AppTypography.textTheme(scheme.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        titleTextStyle: AppTypography.textTheme(scheme.onSurface).titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
      ),
      cardTheme: CardThemeData(color: scheme.surfaceContainerLow, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }
}
