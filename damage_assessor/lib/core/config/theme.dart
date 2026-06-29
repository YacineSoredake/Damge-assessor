import 'package:flutter/material.dart';

/// Brand palette — kept consistent with the PDF report design
/// (navy header, slate text, blue accent, semantic condition colors).
class AppColors {
  AppColors._();

  static const navy = Color(0xFF0F172A);
  static const slate = Color(0xFF475569);
  static const lightBg = Color(0xFFF1F5F9);
  static const accent = Color(0xFF2563EB);

  static const green = Color(0xFF16A34A);
  static const orange = Color(0xFFEA580C);
  static const red = Color(0xFFDC2626);
  static const border = Color(0xFFE2E8F0);

  /// Maps overall_condition / risk strings to a semantic color.
  static Color conditionColor(String condition) {
    switch (condition.toLowerCase()) {
      case 'excellent':
      case 'good':
      case 'low':
        return green;
      case 'fair':
      case 'medium':
        return orange;
      case 'poor':
      case 'critical':
      case 'high':
        return red;
      default:
        return slate;
    }
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          primary: AppColors.accent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightBg,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
          bodyMedium: TextStyle(color: AppColors.slate),
        ),
      );
}
