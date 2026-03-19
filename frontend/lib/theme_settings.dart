import 'package:flutter/material.dart';

/// Defines the available theme mode options for the app.
///
/// Current modes:
/// - [black]
/// - [gray]
/// - [white]
///
/// Note: This enum is used by [AppThemeSettings] to track the selected mode.
enum AppThemeMode { black, gray, white }

/// Centralized design tokens for CampusRun brand colors and gradients.
///
/// This class is a static container only (no instance needed).
/// All values are compile-time constants to ensure consistency and performance.
class AppBrandColors {
  /// Pure white for high-contrast text/icons.
  static const Color white = Color(0xFFFFFFFF);

  /// Deep black start tone used in primary dark surfaces.
  static const Color blackStart = Color(0xFF000000);

  /// Slightly lifted black end tone used with gradients.
  static const Color blackEnd = Color(0xFF171717);

  /// Warm gradient start for primary accent family.
  static const Color redYellowStart = Color(0xFFD10F2F);

  /// Warm gradient end for primary accent family.
  static const Color redYellowEnd = Color(0xFFFFC107);

  /// Main accent midpoint used for CTAs and progress emphasis.
  static const Color redYellowMid = Color(0xFFFF7A21);

  /// Green gradient start used for positive states.
  static const Color greenStart = Color(0xFF00A86B);

  /// Green gradient end used for positive states.
  static const Color greenEnd = Color(0xFF00D084);

  /// Main green midpoint used for success/availability signaling.
  static const Color greenMid = Color(0xFF00C278);

  /// Muted white for secondary text and subtle contrast.
  static const Color whiteMuted = Color(0xFFE5E5E5);

  /// Global dark background gradient used across major screens.
  static const LinearGradient blackBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blackStart, blackEnd],
  );

  /// Accent gradient for action-led UI elements.
  static const LinearGradient redYellowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [redYellowStart, redYellowEnd],
  );

  /// Positive-state gradient for confirmations/success visuals.
  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenStart, greenEnd],
  );
}

/// App-level theme manager using [ChangeNotifier].
///
/// Responsibilities:
/// - Store current theme mode ([AppThemeMode]).
/// - Expose computed [ThemeData].
/// - Notify listeners when mode changes via [setTheme].
class AppThemeSettings extends ChangeNotifier {
  /// Internal mutable state for current selected theme mode.
  AppThemeMode _currentTheme = AppThemeMode.black;

  /// Public read-only access to current theme mode.
  AppThemeMode get currentTheme => _currentTheme;

  /// Builds and returns the active [ThemeData] for the app.
  ///
  /// Current implementation uses Material 3 and dark color system.
  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        /// Primary interactive color.
        primary: AppBrandColors.redYellowMid,

        /// Secondary/supportive color.
        secondary: AppBrandColors.greenMid,

        /// Main surface color for cards/sheets.
        surface: AppBrandColors.blackEnd,

        /// Foreground color rendered on primary surfaces.
        onPrimary: AppBrandColors.white,

        /// Foreground color rendered on secondary surfaces.
        onSecondary: AppBrandColors.white,

        /// Foreground color rendered on generic surfaces.
        onSurface: AppBrandColors.white,
      ),

      /// Default scaffold background color.
      scaffoldBackgroundColor: AppBrandColors.blackStart,

      /// App bar styling.
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppBrandColors.white,
        elevation: 0,
      ),

      /// Typography defaults.
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppBrandColors.white),
        bodyMedium: TextStyle(color: AppBrandColors.whiteMuted),
        bodySmall: TextStyle(color: AppBrandColors.whiteMuted),
      ),

      /// Default icon color.
      iconTheme: const IconThemeData(color: AppBrandColors.greenMid),

      /// Global progress indicator appearance.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppBrandColors.redYellowMid,
        linearTrackColor: Color(0xFF2B2B2B),
      ),

      /// Global input decoration style for text fields/forms.
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: AppBrandColors.whiteMuted),
        hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
        prefixIconColor: AppBrandColors.greenMid,
        suffixIconColor: AppBrandColors.greenMid,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF484848)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppBrandColors.redYellowMid,
            width: 1.8,
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),

      /// Global elevated button style.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppBrandColors.redYellowMid,
          foregroundColor: AppBrandColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      /// Global outlined button style.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppBrandColors.greenMid,
          side: const BorderSide(color: AppBrandColors.greenMid),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// Updates the current theme mode and notifies listeners.
  ///
  /// No-op when the incoming mode matches the current mode.
  void setTheme(AppThemeMode themeMode) {
    if (_currentTheme == themeMode) return;
    _currentTheme = themeMode;
    notifyListeners();
  }
}

/// Shared app-level theme settings instance.
///
/// This can be injected or listened to from UI/state layers.
final AppThemeSettings appThemeSettings = AppThemeSettings();



// below is discarded because not documented, i will come back to it later when things break.
/*
import 'package:flutter/material.dart';

enum AppThemeMode { black, gray, white }

class AppBrandColors {
  static const Color white = Color(0xFFFFFFFF);
  static const Color blackStart = Color(0xFF000000);
  static const Color blackEnd = Color(0xFF171717);

  static const Color redYellowStart = Color(0xFFD10F2F);
  static const Color redYellowEnd = Color(0xFFFFC107);
  static const Color redYellowMid = Color(0xFFFF7A21);

  static const Color greenStart = Color(0xFF00A86B);
  static const Color greenEnd = Color(0xFF00D084);
  static const Color greenMid = Color(0xFF00C278);

  static const Color whiteMuted = Color(0xFFE5E5E5);

  static const LinearGradient blackBackgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [blackStart, blackEnd],
  );

  static const LinearGradient redYellowGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [redYellowStart, redYellowEnd],
  );

  static const LinearGradient greenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenStart, greenEnd],
  );
}

class AppThemeSettings extends ChangeNotifier {
  AppThemeMode _currentTheme = AppThemeMode.black;

  AppThemeMode get currentTheme => _currentTheme;

  ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppBrandColors.redYellowMid,
        secondary: AppBrandColors.greenMid,
        surface: AppBrandColors.blackEnd,
        onPrimary: AppBrandColors.white,
        onSecondary: AppBrandColors.white,
        onSurface: AppBrandColors.white,
      ),
      scaffoldBackgroundColor: AppBrandColors.blackStart,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppBrandColors.white,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppBrandColors.white),
        bodyMedium: TextStyle(color: AppBrandColors.whiteMuted),
        bodySmall: TextStyle(color: AppBrandColors.whiteMuted),
      ),
      iconTheme: const IconThemeData(color: AppBrandColors.greenMid),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppBrandColors.redYellowMid,
        linearTrackColor: Color(0xFF2B2B2B),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: AppBrandColors.whiteMuted),
        hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
        prefixIconColor: AppBrandColors.greenMid,
        suffixIconColor: AppBrandColors.greenMid,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF484848)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppBrandColors.redYellowMid,
            width: 1.8,
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppBrandColors.redYellowMid,
          foregroundColor: AppBrandColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppBrandColors.greenMid,
          side: const BorderSide(color: AppBrandColors.greenMid),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void setTheme(AppThemeMode themeMode) {
    if (_currentTheme == themeMode) return;
    _currentTheme = themeMode;
    notifyListeners();
  }
}

final AppThemeSettings appThemeSettings = AppThemeSettings();


*/  