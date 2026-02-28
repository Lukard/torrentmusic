import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Dark theme for TorrentMusic.
ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accentLight,
      surface: AppColors.surface,
      onPrimary: AppColors.onAccent,
      onSecondary: AppColors.onAccent,
      onSurface: AppColors.onBackground,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.onBackground,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: const CardTheme(
      color: AppColors.surface,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withAlpha(40),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: AppColors.onSurface),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.surfaceVariant,
      thumbColor: AppColors.accent,
      overlayColor: Color(0x297C4DFF),
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
    ),
    iconTheme: const IconThemeData(color: AppColors.onBackground),
    dividerColor: AppColors.divider,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        color: AppColors.onBackground,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: AppColors.onBackground,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(color: AppColors.onBackground),
      bodyLarge: TextStyle(color: AppColors.onBackground),
      bodyMedium: TextStyle(color: AppColors.onSurface),
      bodySmall: TextStyle(color: AppColors.subtle),
    ),
  );
}
