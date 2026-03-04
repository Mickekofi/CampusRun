import 'package:flutter/material.dart';

enum AppThemeMode { black, gray, white }

class AppBrandColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color blue = Color(0xFF0D47A1);
  static const Color red = Color(0xFFC62828);
}

class AppThemeSettings extends ChangeNotifier {
  AppThemeMode _currentTheme = AppThemeMode.white;

  AppThemeMode get currentTheme => _currentTheme;

  ThemeData get themeData {
    switch (_currentTheme) {
      case AppThemeMode.black:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: AppBrandColors.blue,
            secondary: AppBrandColors.red,
            surface: Color(0xFF121212),
            onPrimary: AppBrandColors.white,
            onSecondary: AppBrandColors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFF000000),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF000000),
            foregroundColor: AppBrandColors.white,
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: AppBrandColors.red,
            linearTrackColor: Color(0xFF2A2A2A),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppBrandColors.blue,
              foregroundColor: AppBrandColors.white,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppBrandColors.blue,
              side: const BorderSide(color: AppBrandColors.blue),
            ),
          ),
        );
      case AppThemeMode.gray:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: AppBrandColors.blue,
            secondary: AppBrandColors.red,
            surface: Color(0xFF2A2A2A),
            onPrimary: AppBrandColors.white,
            onSecondary: AppBrandColors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFF303030),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF303030),
            foregroundColor: AppBrandColors.white,
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: AppBrandColors.red,
            linearTrackColor: Color(0xFF5A5A5A),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppBrandColors.blue,
              foregroundColor: AppBrandColors.white,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppBrandColors.blue,
              side: const BorderSide(color: AppBrandColors.blue),
            ),
          ),
        );
      case AppThemeMode.white:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorScheme: const ColorScheme.light(
            primary: AppBrandColors.blue,
            secondary: AppBrandColors.red,
            surface: AppBrandColors.white,
            onPrimary: AppBrandColors.white,
            onSecondary: AppBrandColors.white,
            onSurface: AppBrandColors.blue,
          ),
          scaffoldBackgroundColor: AppBrandColors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppBrandColors.white,
            foregroundColor: AppBrandColors.blue,
          ),
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: AppBrandColors.red,
            linearTrackColor: Color(0xFFE0E0E0),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppBrandColors.blue,
              foregroundColor: AppBrandColors.white,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppBrandColors.blue,
              side: const BorderSide(color: AppBrandColors.blue),
            ),
          ),
        );
    }
  }

  void setTheme(AppThemeMode themeMode) {
    if (_currentTheme == themeMode) return;
    _currentTheme = themeMode;
    notifyListeners();
  }
}

final AppThemeSettings appThemeSettings = AppThemeSettings();
