import 'package:flutter/material.dart';

class AppColors {
  // Legacy (kept for backward compatibility)
  static const Color primary = Color(0xFF4CAF50);
  static const Color secondary = Color(0xFFFFB300);
  static const Color background = Color(0xFFF5F5F5);
  static const Color textDark = Color(0xFF212121);
  static const Color textLight = Color(0xFF757575);
  static const Color white = Colors.white;

  // ── New Pink/Pastel Pet App Palette ──────────────────────────────────
  /// Main salmon/coral accent – buttons, active chips, highlighted prices
  static const Color accent = Color(0xFFE8847A);

  /// Light version of accent for icon button backgrounds
  static const Color accentLight = Color(0xFFFAE8E7);

  /// Soft pink page/scaffold background
  static const Color pinkBackground = Color(0xFFFBD5D8);

  /// Card text – dark
  static const Color cardTextDark = Color(0xFF1A1A1A);

  /// Card text – secondary/gray
  static const Color cardTextGray = Color(0xFF888888);

  /// Cycling pastel backgrounds for pet card image areas
  static const List<Color> petCardBgs = [
    Color(0xFFE8C97A), // golden yellow
    Color(0xFFF5A5A0), // salmon pink
    Color(0xFFA8D8D5), // light teal
    Color(0xFFF5C5A8), // peach
    Color(0xFFF5B8C0), // rose pink
    Color(0xFFA8D5B0), // sage green
  ];
}
