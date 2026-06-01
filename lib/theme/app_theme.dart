import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

class AppTheme {
  // Expose color tokens expected by the codebase
  static const Color primary = AppColors.kAccentBlue;
  static const Color primaryLight = AppColors.kAccentLight;
  static const Color primaryPale = Color(0xFFEAF6FF);
  static const Color textPrimary = AppColors.kTextPrimary;
  static const Color textSecondary = AppColors.kTextSecond;
  static const Color textMuted = AppColors.kTextHint;
  static const Color border = Color(0xFF1E3A5F);
  // Backwards-compatible aliases used across the codebase
  static const Color darkBackground = AppColors.kBgDeep;
  static const Color danger = AppColors.kDanger;
  static const Color primaryGradientStart = AppColors.kAccentBlue;
  static const Color primaryGradientEnd = AppColors.kAccentLight;
  static const Color tint = AppColors.kAccentMuted;
  static const Color darkRed = Color(0xFF991B1B);
  static const Color primarySoft = primaryPale;

  static ThemeData _base(ColorScheme cs, bool isDark) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      ThemeData(brightness: isDark ? Brightness.dark : Brightness.light).textTheme,
    );

    return ThemeData(
      colorScheme: cs,
      primaryColor: primary,
      scaffoldBackgroundColor: AppColors.kBgDeep,
      canvasColor: AppColors.kBgDeep,
      cardColor: AppColors.kBgCard,
      dividerColor: AppColors.kDivider,
      textTheme: textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.kBgInput,
        hintStyle: TextStyle(color: AppColors.kTextHint, fontSize: 14.sp),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.kBgDeep,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontSize: 18.sp,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: textPrimary,
      ),
      
    );
  }

  static ThemeData get darkTheme {
    final cs = ColorScheme.dark(
      primary: primary,
      onPrimary: textPrimary,
      background: AppColors.kBgDeep,
      surface: AppColors.kBgCard,
      onSurface: textPrimary,
    );
    return _base(cs, true);
  }

  static ThemeData get lightTheme {
    final cs = ColorScheme.light(
      primary: primary,
      onPrimary: textPrimary,
      background: AppColors.kBgDeep,
      surface: AppColors.kBgCard,
      onSurface: textPrimary,
    );
    return _base(cs, false);
  }
}
