import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class ClientThemeColors {
  const ClientThemeColors._();

  static const Color bg = Color(0xFF07121D);
  static const Color surface = Color(0xFF102438);
  static const Color softSurface = Color(0xFF18364D);
  static const Color border = Color(0x335C7690);

  static const Color brandNight = Color(0xFF07121D);
  static const Color brandNavy = Color(0xFF102438);
  static const Color brandBlue = Color(0xFF173B55);

  static const Color text = Colors.white;
  static const Color muted = Color(0xFFD8E2EA);
  static const Color accent = Color(0xFFE0B86E);
  static const Color accentSoft = Color(0xFFFFF8E7);
  static const Color accentBorder = Color(0x33E0B86E);
  static const Color textOnAccent = Color(0xFF102438);
  static const Color darkCard = Color(0xFF102438);
  static const Color darkCardStrong = Color(0xFF0E2235);
  static const Color darkCardSoft = Color(0xFF183C55);
  static const Color darkStroke = Color(0x335C7690);

  static const List<Color> appGradient = [brandNight, brandNavy, brandBlue];
  static const List<Color> headerGradient = [
    Color(0xFF0E2235),
    Color(0xFF183C55),
  ];
  static const List<Color> heroGradient = [
    Color(0xFF0E2235),
    Color(0xFF183C55),
  ];
  static const List<Color> accentGradient = [
    Color(0xFFFFF8E7),
    Color(0xFFEBD39B),
  ];
}

@immutable
class ClientPalette {
  const ClientPalette({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceStrong,
    required this.primary,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.heroTextPrimary,
    required this.heroTextSecondary,
    required this.accent,
    required this.accentSoft,
    required this.accentBorder,
    required this.textOnAccent,
    required this.appGradient,
    required this.headerGradient,
    required this.heroGradient,
    required this.accentGradient,
  });

  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color surfaceStrong;
  final Color primary;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color heroTextPrimary;
  final Color heroTextSecondary;
  final Color accent;
  final Color accentSoft;
  final Color accentBorder;
  final Color textOnAccent;
  final List<Color> appGradient;
  final List<Color> headerGradient;
  final List<Color> heroGradient;
  final List<Color> accentGradient;

  factory ClientPalette.of(BuildContext context) {
    final roles = context.appColors;
    final scheme = context.scheme;
    final isDark = context.isDarkMode;

    final surfaceSoft =
        Color.lerp(roles.surfaceCard, roles.primary, isDark ? 0.28 : 0.08) ??
        roles.surfaceCard;
    final surfaceStrong =
        Color.lerp(roles.primary, roles.surfaceCard, isDark ? 0.24 : 0.58) ??
        roles.primary;
    final accentSoft =
        Color.lerp(roles.secondary, roles.surfaceCard, isDark ? 0.14 : 0.72) ??
        roles.secondary;
    final accentBorder =
        Color.lerp(roles.secondary, roles.border, isDark ? 0.55 : 0.35) ??
        roles.border;

    return ClientPalette(
      background: roles.background,
      surface: roles.surfaceCard,
      surfaceSoft: surfaceSoft,
      surfaceStrong: surfaceStrong,
      primary: roles.primary,
      border: roles.border,
      textPrimary: roles.textPrimary,
      textSecondary: roles.textSecondary,
      heroTextPrimary:
          isDark ? const Color(0xFFF4F8FC) : const Color(0xFFFDFEFF),
      heroTextSecondary:
          isDark ? const Color(0xFFD3DEE7) : const Color(0xFFE5EDF5),
      accent: roles.secondary,
      accentSoft: accentSoft,
      accentBorder: accentBorder,
      textOnAccent: scheme.onSecondary,
      appGradient:
          isDark
              ? [
                roles.background,
                Color.lerp(roles.background, roles.primary, 0.52) ??
                    roles.primary,
                Color.lerp(roles.primary, const Color(0xFF1C4A67), 0.55) ??
                    roles.primary,
              ]
              : [
                Color.lerp(roles.background, Colors.white, 0.35) ??
                    roles.background,
                Color.lerp(roles.background, const Color(0xFFE7EEF4), 0.72) ??
                    roles.background,
                Color.lerp(roles.primary, Colors.white, 0.84) ?? roles.primary,
              ],
      headerGradient:
          isDark
              ? [surfaceStrong, roles.primary]
              : [
                Color.lerp(roles.primary, Colors.white, 0.32) ?? roles.primary,
                Color.lerp(roles.primary, roles.surfaceCard, 0.18) ??
                    roles.surfaceCard,
              ],
      heroGradient:
          isDark
              ? [surfaceStrong, roles.primary]
              : [
                Color.lerp(roles.primary, Colors.white, 0.22) ?? roles.primary,
                Color.lerp(roles.primary, roles.surfaceCard, 0.10) ??
                    roles.surfaceCard,
              ],
      accentGradient:
          isDark
              ? [
                Color.lerp(roles.secondary, Colors.white, 0.04) ??
                    roles.secondary,
                Color.lerp(roles.secondary, const Color(0xFFF6D79A), 0.55) ??
                    roles.secondary,
              ]
              : [
                Color.lerp(roles.secondary, Colors.white, 0.62) ??
                    roles.secondary,
                Color.lerp(roles.secondary, Colors.white, 0.34) ??
                    roles.secondary,
              ],
    );
  }
}

extension ClientThemeContext on BuildContext {
  ClientPalette get clientPalette => ClientPalette.of(this);
}
