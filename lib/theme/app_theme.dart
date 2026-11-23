import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Authoritative Theme Configuration for TeamSync
/// Implements the light visual system with Host Grotesk display headings
/// and Instrument Sans interface & body typography.
class AppTheme {
  // Authoritative Color Tokens
  static const Color ground = AppColors.dpGround;
  static const Color ink = AppColors.dpInk;
  static const Color inkSecondary = AppColors.dpInkSecondary;
  static const Color groundMuted = AppColors.dpGroundMuted;
  static const Color rule = AppColors.dpRule;
  static const Color accent = AppColors.dpAccent;
  static const Color onAccent = AppColors.dpOnAccent;
  static const Color field = AppColors.dpField;
  static const Color onField = AppColors.dpOnField;
  static const Color onFieldSecondary = AppColors.dpOnFieldSecondary;
  static const Color panel = AppColors.dpPanel;

  // Semantic
  static const Color success = AppColors.dpSuccess;
  static const Color warning = AppColors.dpWarning;
  static const Color danger = AppColors.dpDanger;
  static const Color info = AppColors.dpInfo;

  // Backward-compatible properties
  static const Color primary = accent;
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color primaryPale = Color(0xFFEFF6FF);
  static const Color textPrimary = ink;
  static const Color textSecondary = inkSecondary;
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = rule;
  static const Color darkBackground = ground;
  static const Color primaryGradientStart = accent;
  static const Color primaryGradientEnd = Color(0xFF2563EB);
  static const Color tint = groundMuted;
  static const Color darkRed = Color(0xFF991B1B);
  static const Color primarySoft = primaryPale;

  // Layout & Spacing Tokens
  static const double radiusPanel = 12.0;
  static const double radiusMd = 8.0;
  static const double radiusSm = 6.0;
  static const double borderHairline = 1.0;
  static const double gridGap = 24.0;
  static const Duration interactionDuration = Duration(milliseconds: 160);
  static const Curve interactionCurve = Curves.easeOut;

  /// Helper to get Host Grotesk font with safe fallback to Instrument Sans
  static TextStyle hostGrotesk({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    try {
      return GoogleFonts.getFont(
        'Host Grotesk',
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.w600,
        color: color ?? ink,
        height: height,
        letterSpacing: letterSpacing,
      );
    } catch (_) {
      return GoogleFonts.instrumentSans(
        fontSize: fontSize,
        fontWeight: fontWeight ?? FontWeight.w600,
        color: color ?? ink,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
  }

  /// Helper to get Instrument Sans font for interface, body, and controls
  static TextStyle instrumentSans({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.instrumentSans(
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w400,
      color: color ?? ink,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Authoritative display font helper matching Host Grotesk specifications
  static TextStyle displayFont({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => hostGrotesk(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Authoritative body and UI font helper matching Instrument Sans specifications
  static TextStyle bodyFont({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => instrumentSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  // Authoritative Typography Tokens
  static TextStyle get display1 => hostGrotesk(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: ink,
        height: 1.15,
        letterSpacing: -0.5,
      );

  static TextStyle get display2 => hostGrotesk(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.20,
        letterSpacing: -0.4,
      );

  static TextStyle get heading1 => hostGrotesk(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ink,
        height: 1.25,
        letterSpacing: -0.3,
      );

  static TextStyle get heading2 => hostGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: ink,
        height: 1.30,
        letterSpacing: -0.2,
      );

  static TextStyle get heading3 => hostGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
        height: 1.35,
      );

  static TextStyle get bodyLarge => instrumentSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: ink,
        height: 1.6,
      );

  static TextStyle get interfaceText => instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: ink,
        height: 1.4,
      );

  static TextStyle get bodySmall => instrumentSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: inkSecondary,
        height: 1.45,
      );

  static TextStyle get metadataText => instrumentSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: inkSecondary,
        height: 1.4,
      );

  static TextStyle get labelText => instrumentSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: inkSecondary,
        letterSpacing: 0.4,
      );

  /// Authoritative Light Theme
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.instrumentSansTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: accent,
      scaffoldBackgroundColor: ground,
      canvasColor: ground,
      cardColor: panel,
      dividerColor: rule,
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: onAccent,
        secondary: accent,
        surface: panel,
        onSurface: ink,
        background: ground,
        onBackground: ink,
        error: danger,
        onError: Colors.white,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: display1,
        displayMedium: display2,
        headlineLarge: heading1,
        headlineMedium: heading2,
        headlineSmall: heading3,
        bodyLarge: bodyLarge,
        bodyMedium: interfaceText,
        bodySmall: bodySmall,
        labelMedium: metadataText,
        labelSmall: labelText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: panel,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: heading2,
        iconTheme: const IconThemeData(color: ink, size: 20),
        shape: const Border(
          bottom: BorderSide(color: rule, width: borderHairline),
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPanel),
          side: const BorderSide(color: rule, width: borderHairline),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: instrumentSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: onAccent,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: panel,
          foregroundColor: ink,
          elevation: 0,
          side: const BorderSide(color: rule, width: borderHairline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: instrumentSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: ink,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: instrumentSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        hintStyle: instrumentSans(
          fontSize: 14,
          color: const Color(0xFF94A3B8),
        ),
        labelStyle: instrumentSans(
          fontSize: 14,
          color: inkSecondary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: rule, width: borderHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: rule, width: borderHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: danger, width: borderHairline),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: panel,
        selectedItemColor: accent,
        unselectedItemColor: inkSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: rule, width: borderHairline),
        ),
        titleTextStyle: heading2,
        contentTextStyle: bodySmall,
      ),
      dividerTheme: const DividerThemeData(
        color: rule,
        thickness: borderHairline,
        space: 1,
      ),
    );
  }

  // In this redesign, darkTheme is configured identically to lightTheme to ensure
  // complete visual consistency across platforms and prevent unstyled dark regressions.
  static ThemeData get darkTheme => lightTheme;
}
