import 'package:flutter/material.dart';

/// Centralized design tokens for HotTea's premium glassmorphism interface.
///
/// Blends deep graphite and charcoal backgrounds with subtle icy-blue accents
/// and the official HotTea amber accent (#D48B47).
class GlassTheme {
  // --- COLOR PALETTE ---
  /// Deep graphite background matching the official HotTea website.
  static const Color backgroundDeep = Color(0xFF0C0D11);

  /// Secondary dark surface.
  static const Color backgroundCharcoal = Color(0xFF13151C);
  static const Color charcoal = Color(0xFF13151C);

  /// Tertiary container background.
  static const Color backgroundTertiary = Color(0xFF1B1E27);

  /// Semi-transparent glass surface for cards and panes (~65% opacity).
  static const Color surfaceGlass = Color(0xA6171A23);

  /// Denser semi-transparent glass surface for toolbars and appbars (~80% opacity).
  static const Color surfaceGlassDense = Color(0xCC13151C);

  /// Dark tinted surface for address bars and input fields (~85% opacity).
  static const Color surfaceGlassDark = Color(0xD90E1015);

  /// High-opacity glass surface for dialogs and sheets (~90% opacity).
  static const Color surfaceGlassModal = Color(0xE613151C);

  /// Subtle light tint for hover and active card states (~15% opacity).
  static const Color surfaceGlassHover = Color(0x26FFFFFF);

  /// Thin, low-opacity border for resting glass surfaces (~10% opacity).
  static const Color borderSubtle = Color(0x1AFFFFFF);

  /// Soft inner highlight border for focused, active, or top surfaces (~20% opacity).
  static const Color borderHighlight = Color(0x33FFFFFF);

  /// Subtle icy-blue accent for modern chrome highlights and active state rings.
  static const Color accentIcyBlue = Color(0xFF7DD3FC);

  /// Subtle icy-blue glow for hover and focus borders.
  static const Color accentIcyBlueGlow = Color(0x337DD3FC);

  /// Official HotTea brand amber accent from the website.
  static const Color accentTea = Color(0xFFD48B47);

  /// Light tea amber for secondary highlights.
  static const Color accentTeaLight = Color(0xFFEAA86C);

  /// Subtle tea amber glow for buttons and badges.
  static const Color accentTeaGlow = Color(0x2ED48B47);

  /// Private / Incognito browsing accent.
  static const Color accentPrivate = Color(0xFFC084FC);
  static const Color accentPrivateGlow = Color(0x33C084FC);

  // --- TYPOGRAPHY COLORS ---
  static const Color textPrimary = Color(0xFFF0F2F5);
  static const Color textSecondary = Color(0xFF9DA5B4);
  static const Color textMuted = Color(0xFF656C7B);

  // --- BLUR METRICS ---
  static const double blurLow = 8.0;
  static const double blurStandard = 16.0;
  static const double blurModal = 20.0;
  static const double blurHeavy = 24.0;

  // --- CORNER RADII ---
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 16.0;
  static const double radiusFull = 999.0;

  // --- ANIMATIONS ---
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animStandard = Duration(milliseconds: 250);

  /// Creates a unified frosted glass BoxDecoration with optional inner top highlight.
  static BoxDecoration glassDecoration({
    Color? color,
    BorderRadius? borderRadius,
    Color? borderColor,
    double borderWidth = 1.0,
    bool topHighlight = true,
    List<BoxShadow>? shadows,
  }) {
    final effectiveColor = color ?? surfaceGlass;
    final effectiveBorder = borderColor ?? borderSubtle;

    return BoxDecoration(
      color: effectiveColor,
      borderRadius: borderRadius ?? BorderRadius.circular(radiusMd),
      border: Border.all(color: effectiveBorder, width: borderWidth),
      boxShadow: shadows ?? [
        BoxShadow(
          color: Colors.black.withAlpha(50),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
