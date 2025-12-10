// lib/constants/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // Couleurs Principales
  static const Color tropicalTeal = Color(0xFF0F9E99);
  static const Color softIvory = Color(0xFFEFE9E0);
  static const Color accentColor = Color(0xFFF5B041);
  static const Color textColor = Color(0xFF1F2937);
  
  // Nuances Teal
  static const Color tealDark = Color(0xFF0A7A73);
  static const Color tealLight = Color(0xFF16B6AD);
  static const Color tealVeryLight = Color(0xFFE8F8F7);
  
  // Nuances Ivoire
  static const Color ivoryDark = Color(0xFFDED6CC);
  static const Color ivoryLight = Color(0xFFF5F1EB);
  
  // Nuances Accent (Or)
  static const Color accentDark = Color(0xFFD4941E);
  static const Color accentLight = Color(0xFFFDD787);
  
  // Statuts et États
  static const Color successColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color errorColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);
  
  // Nuances de Gris
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color mediumGrey = Color(0xFFD1D5DB);
  static const Color darkGrey = Color(0xFF6B7280);
  static const Color veryDarkGrey = Color(0xFF4B5563);
  
  // Ombres
  static const Color shadowColor = Color(0x1A000000);
  
  // Autres couleurs
  static Color get backgroundColor => softIvory;
  static Color get primaryColor => tropicalTeal;
  static Color get secondaryColor => accentColor;
  static Color get cardColor => Colors.white;
}
