// lib/constants/app_theme.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Espacements standards
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing40 = 40.0;

  // Rayons de bordure
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 20.0;
  static const double radiusXLarge = 28.0;

  // Hauteurs
  static const double buttonHeight = 48.0;
  static const double cardHeight = 120.0;
  static const double iconSize = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeXLarge = 64.0;

  // Épaisseur des bordures
  static const double borderWidth = 1.0;
  static const double borderWidthMedium = 2.0;

  // Opacité
  static const double opacityLow = 0.1;
  static const double opacityMedium = 0.5;
  static const double opacityHigh = 0.7;

  // Theme Flutter
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.softIvory,
      primaryColor: AppColors.tropicalTeal,
      // App Bar Theme
      appBarTheme: AppBarThemeData.light,
      // Button Themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.tropicalTeal,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing20,
            vertical: spacing12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMedium),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.tropicalTeal,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Text Themes
      textTheme: TextThemeData.light,
      // Input Decoration
      inputDecorationTheme: InputDecorationThemeData.light,
    );
  }
}

// AppBar Theme Data
class AppBarThemeData {
  static const AppBarTheme light = AppBarTheme(
    backgroundColor: AppColors.tropicalTeal,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(
      color: Colors.white,
      size: AppTheme.iconSize,
    ),
  );
}

// Text Theme Data
class TextThemeData {
  static const TextTheme light = TextTheme(
    // Grands titres
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: AppColors.textColor,
      height: 1.2,
    ),
    displayMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: AppColors.textColor,
      height: 1.2,
    ),
    displaySmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: AppColors.textColor,
      height: 1.2,
    ),
    // Titres
    headlineLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: AppColors.textColor,
      height: 1.3,
    ),
    headlineMedium: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textColor,
      height: 1.3,
    ),
    headlineSmall: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textColor,
      height: 1.4,
    ),
    // Titres de section
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: AppColors.textColor,
      height: 1.3,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.textColor,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textColor,
      height: 1.4,
    ),
    // Corps de texte
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: AppColors.textColor,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: AppColors.textColor,
      height: 1.5,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: AppColors.darkGrey,
      height: 1.4,
    ),
    // Texte petit
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textColor,
      height: 1.4,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textColor,
      height: 1.3,
      letterSpacing: 0.1,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: AppColors.darkGrey,
      height: 1.3,
      letterSpacing: 0.2,
    ),
  );
}

// Input Decoration Theme Data
class InputDecorationThemeData {
  static const InputDecorationTheme light = InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(
      horizontal: AppTheme.spacing16,
      vertical: AppTheme.spacing12,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusMedium)),
      borderSide: BorderSide(
        color: AppColors.mediumGrey,
        width: AppTheme.borderWidth,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusMedium)),
      borderSide: BorderSide(
        color: AppColors.mediumGrey,
        width: AppTheme.borderWidth,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusMedium)),
      borderSide: BorderSide(
        color: AppColors.tropicalTeal,
        width: AppTheme.borderWidthMedium,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusMedium)),
      borderSide: BorderSide(
        color: AppColors.errorColor,
        width: AppTheme.borderWidth,
      ),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusMedium)),
      borderSide: BorderSide(
        color: AppColors.errorColor,
        width: AppTheme.borderWidthMedium,
      ),
    ),
    labelStyle: TextStyle(
      color: AppColors.darkGrey,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: TextStyle(
      color: AppColors.mediumGrey,
      fontSize: 14,
    ),
    prefixIconColor: AppColors.darkGrey,
    suffixIconColor: AppColors.darkGrey,
    errorStyle: TextStyle(
      color: AppColors.errorColor,
      fontSize: 12,
    ),
  );
}

// Card Theme Data
class CardThemeData {
  static const CardTheme light = CardTheme(
    color: Colors.white,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusMedium)),
    ),
    margin: EdgeInsets.zero,
  );
}

// Utilitaires de Shadow
class AppShadows {
  static List<BoxShadow> get subtle => [
        BoxShadow(
          color: AppColors.shadowColor,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: AppColors.shadowColor.withOpacity(0.15),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get large => [
        BoxShadow(
          color: AppColors.shadowColor.withOpacity(0.2),
          blurRadius: 20,
          spreadRadius: 4,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> coloredMedium(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.15),
          blurRadius: 12,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ];
}

// Gradients
class AppGradients {
  static LinearGradient get primaryToAccent => LinearGradient(
        colors: [
          AppColors.tropicalTeal,
          AppColors.accentColor,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get tealTint => LinearGradient(
        colors: [
          AppColors.tropicalTeal,
          AppColors.tealLight,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get background => LinearGradient(
        colors: [
          AppColors.softIvory,
          Colors.white,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

// Durées d'animation
class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration verySlow = Duration(milliseconds: 800);
}

// Courbes d'animation
class AppCurves {
  static const Curve smooth = Curves.easeInOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve bouncy = Curves.elasticOut;
}
