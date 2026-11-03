import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text.dart';

/// Builds the Material 3 theme from the design tokens.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.mint,
      primary: AppColors.mint,
      onPrimary: AppColors.navy,
      secondary: AppColors.sunshine,
      onSecondary: AppColors.navy,
      tertiary: AppColors.sky,
      onTertiary: AppColors.navy,
      error: AppColors.invalid,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.navy,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Nunito',
      textTheme: AppText.textTheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: AppText.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
      ),
    );
  }
}
