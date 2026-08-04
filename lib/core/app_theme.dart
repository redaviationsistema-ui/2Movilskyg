import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

@immutable
class AppColorRoles extends ThemeExtension<AppColorRoles> {
  const AppColorRoles({
    required this.background,
    required this.surfaceCard,
    required this.primary,
    required this.secondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });

  final Color background;
  final Color surfaceCard;
  final Color primary;
  final Color secondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  @override
  AppColorRoles copyWith({
    Color? background,
    Color? surfaceCard,
    Color? primary,
    Color? secondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
  }) {
    return AppColorRoles(
      background: background ?? this.background,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
    );
  }

  @override
  AppColorRoles lerp(ThemeExtension<AppColorRoles>? other, double t) {
    if (other is! AppColorRoles) return this;
    return AppColorRoles(
      background: Color.lerp(background, other.background, t) ?? background,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t) ?? surfaceCard,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      border: Color.lerp(border, other.border, t) ?? border,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static const Color gold = Color(0xFFE7C06A);
  static const Color navy = Color(0xFF123047);
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color darkBackground = Color(0xFF06121C);
  static const Color darkSurface = Color(0xFF10293C);

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
    ).copyWith(
      primary: navy,
      onPrimary: Colors.white,
      secondary: gold,
      onSecondary: const Color(0xFF1B1A17),
      surface: const Color(0xFFFFFFFF),
      onSurface: const Color(0xFF102438),
      error: const Color(0xFFC44536),
      onError: Colors.white,
      errorContainer: const Color(0xFFFFECE8),
      onErrorContainer: const Color(0xFF641A10),
    );
    return _buildTheme(
      scheme: scheme,
      roles: const AppColorRoles(
        background: lightBackground,
        surfaceCard: Color(0xFFFFFFFF),
        primary: navy,
        secondary: gold,
        textPrimary: Color(0xFF102438),
        textSecondary: Color(0xFF607080),
        border: Color(0xFFD8E0E7),
      ),
    );
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF16384F),
      onPrimary: Colors.white,
      secondary: gold,
      onSecondary: const Color(0xFF16120A),
      surface: darkSurface,
      onSurface: const Color(0xFFF3F7FB),
      error: const Color(0xFFFF8A7A),
      onError: const Color(0xFF2F0B06),
      errorContainer: const Color(0xFF5F1E16),
      onErrorContainer: const Color(0xFFFFDAD5),
    );
    return _buildTheme(
      scheme: scheme,
      roles: const AppColorRoles(
        background: darkBackground,
        surfaceCard: darkSurface,
        primary: Color(0xFF16384F),
        secondary: gold,
        textPrimary: Color(0xFFF3F7FB),
        textSecondary: Color(0xFFC2CFD9),
        border: Color(0x335C7690),
      ),
    );
  }

  static ThemeData _buildTheme({
    required ColorScheme scheme,
    required AppColorRoles roles,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: roles.background,
      fontFamily: 'Roboto',
      extensions: [roles],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    return base.copyWith(
      cardColor: roles.surfaceCard,
      canvasColor: roles.surfaceCard,
      dividerColor: roles.border,
      appBarTheme: AppBarTheme(
        backgroundColor: roles.background,
        foregroundColor: roles.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color:
              scheme.brightness == Brightness.dark
                  ? scheme.primary
                  : roles.textPrimary,
        ),
        actionsIconTheme: IconThemeData(
          color:
              scheme.brightness == Brightness.dark
                  ? scheme.primary
                  : roles.textPrimary,
        ),
      ),
      iconTheme: IconThemeData(
        color:
            scheme.brightness == Brightness.dark
                ? scheme.primary
                : roles.textPrimary,
      ),
      primaryIconTheme: IconThemeData(
        color:
            scheme.brightness == Brightness.dark
                ? scheme.primary
                : roles.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: roles.textPrimary,
        displayColor: roles.textPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: roles.surfaceCard,
        contentTextStyle: TextStyle(
          color: roles.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Color.lerp(roles.surfaceCard, roles.background, 0.08),
        hintStyle: TextStyle(color: roles.textSecondary, fontSize: 14),
        labelStyle: TextStyle(color: roles.textSecondary),
        prefixIconColor:
            scheme.brightness == Brightness.dark
                ? scheme.primary
                : roles.textSecondary,
        suffixIconColor:
            scheme.brightness == Brightness.dark
                ? scheme.primary
                : roles.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: roles.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: roles.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.secondary, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.error, width: 1.3),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: Color.lerp(
            roles.surfaceCard,
            roles.primary,
            0.45,
          ),
          disabledForegroundColor: roles.textSecondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: roles.textPrimary,
          side: BorderSide(color: roles.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.secondary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: roles.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get appTheme => Theme.of(this);
  ColorScheme get scheme => appTheme.colorScheme;
  AppColorRoles get appColors =>
      appTheme.extension<AppColorRoles>() ??
      const AppColorRoles(
        background: AppTheme.lightBackground,
        surfaceCard: Colors.white,
        primary: AppTheme.navy,
        secondary: AppTheme.gold,
        textPrimary: Color(0xFF102438),
        textSecondary: Color(0xFF607080),
        border: Color(0xFFD8E0E7),
      );
  bool get isDarkMode => appTheme.brightness == Brightness.dark;
}
