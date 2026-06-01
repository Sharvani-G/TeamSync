import 'package:flutter/material.dart';

class AppColors {
  static const Color kBgDeep       = Color(0xFF0A0F1E);  // deepest background
  static const Color kBgCard       = Color(0xFF111827);  // card surface
  static const Color kBgElevated   = Color(0xFF1A2235);  // elevated surface
  static const Color kBgInput      = Color(0xFF1E2D45);  // input fields
  static const Color kAccentBlue   = Color(0xFF2563EB);  // primary CTA
  static const Color kAccentLight  = Color(0xFF3B82F6);  // hover / active
  static const Color kAccentMuted  = Color(0xFF1D4ED8);  // pressed state
  static const Color kTextPrimary  = Color(0xFFF1F5F9);  // main text — always readable
  static const Color kTextSecond   = Color(0xFF94A3B8);  // secondary / muted
  static const Color kTextHint     = Color(0xFF475569);  // hints, placeholders
  static const Color kSuccess      = Color(0xFF22C55E);  // green — keep as-is
  static const Color kDivider      = Color(0xFF1E3A5F);  // subtle dividers
  static const Color kDanger       = Color(0xFFEF4444);  // errors / destructive

  // To avoid hardcoding Colors.white/black as per instructions
  static const Color kWhite        = Color(0xFFFFFFFF);
  static const Color kBlack        = Color(0xFF000000);
}
