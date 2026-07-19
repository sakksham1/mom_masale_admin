import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Color onSurface) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
        fontSize: 40,
        height: 1.1,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
        fontSize: 30,
        height: 1.15,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
        fontSize: 22,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 16,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 14,
        color: onSurface,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 12,
        color: onSurface,
      ),
      labelLarge: TextStyle(
        fontFamily: 'Manrope',
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 24,
        color: onSurface,
      ),
    );
  }

  /// Use for currency figures and order/customer IDs.
  static TextStyle ledger({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    required Color color,
  }) => TextStyle(
    fontFamily: 'IBMPlexMono',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}
