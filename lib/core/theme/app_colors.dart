import 'package:flutter/material.dart';

/// Babaero brand tokens. Bold, charismatic, night-luxe palette:
/// deep rose-crimson → warm coral, with a gold highlight.
/// Use these tokens everywhere — never hardcode hex in widgets.
class AppColors {
  AppColors._();

  // Brand core — crimson-rose → warm coral
  static const Color primary = Color(0xFFE01E5A); // bold crimson-rose
  static const Color secondary = Color(0xFFFF7A59); // warm coral
  static const Color accent = Color(0xFFF5B54A); // luxe gold highlight

  /// Primary brand gradient — top-left → bottom-right.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Richer night-luxe wash behind hero sections / cards.
  static const LinearGradient nightGradient = LinearGradient(
    colors: [Color(0xFF2A0A1E), Color(0xFF7A1338), Color(0xFFE01E5A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Semantic
  static const Color verified = Color(0xFF2ECC9B); // verification badge green
  static const Color online = Color(0xFF43D67C);
  static const Color danger = Color(0xFFE5484D);

  // Photo scrims — dark wash behind text over an image (bottom of hero cards).
  static const Color scrim = Color(0xB3000000); // ~70% black
  static const Color scrimStrong = Color(0xCC000000); // ~80% black

  // Light surfaces
  static const Color bgLight = Color(0xFFFFF6F3); // warm off-white
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF1C121A);
  static const Color textMutedLight = Color(0xFF897F87);

  // Dark surfaces (the brand's home base — night-luxe)
  static const Color bgDark = Color(0xFF130A11);
  static const Color surfaceDark = Color(0xFF1E1119);
  static const Color textDark = Color(0xFFF7EFF3);
  static const Color textMutedDark = Color(0xFF9E8F98);
}
