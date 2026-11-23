import 'package:flutter/material.dart';

/// Authoritative Design Tokens for TeamSync UI/UX
/// Defines the core color palette and semantic status colors.
class AppColors {
  // Authoritative Core Design Tokens
  static const Color dpGround = Color(0xFFFCFCFD);             // --dp-color-ground: Main application background
  static const Color dpInk = Color(0xFF16191F);                // --dp-color-ink: Primary headings and text
  static const Color dpInkSecondary = Color(0xFF454C58);       // --dp-color-ink-secondary: Supporting text
  static const Color dpGroundMuted = Color(0xFFF3F4F6);        // --dp-color-ground-muted: Pale-grey section fills
  static const Color dpRule = Color(0xFFDDE0E6);               // --dp-color-rule: Dividers and subtle borders
  static const Color dpAccent = Color(0xFF074CE0);             // --dp-color-accent: Electric-blue primary actions
  static const Color dpOnAccent = Color(0xFFFFFFFF);           // --dp-color-on-accent: Text and icons on blue
  static const Color dpField = Color(0xFF16191F);              // --dp-color-field: Dark section backgrounds
  static const Color dpOnField = Color(0xFFFCFCFD);            // --dp-color-on-field: Text on dark sections
  static const Color dpOnFieldSecondary = Color(0xFFD0D4DD);   // --dp-color-on-field-secondary: Supporting text on dark
  static const Color dpPanel = Color(0xFFFFFFFF);              // --dp-color-panel: Cards and white surfaces

  // Semantic Status Tokens
  static const Color dpSuccess = Color(0xFF15803D);            // Green for success/completed
  static const Color dpSuccessBg = Color(0xFFDCFCE7);          // Soft green background
  static const Color dpWarning = Color(0xFFB45309);            // Amber for warning/pending
  static const Color dpWarningBg = Color(0xFFFEF3C7);          // Soft amber background
  static const Color dpDanger = Color(0xFFDC2626);             // Red for errors/destructive
  static const Color dpDangerBg = Color(0xFFFEE2E2);           // Soft red background
  static const Color dpInfo = Color(0xFF074CE0);               // Blue for info
  static const Color dpInfoBg = Color(0xFFEFF6FF);             // Soft blue background

  // Backward-compatible aliases mapped to the authoritative light palette
  static const Color kBgDeep = dpGround;                       // Replaced dark deep background with light ground
  static const Color kBgCard = dpPanel;                        // Replaced dark card with clean white panel
  static const Color kBgElevated = dpGroundMuted;              // Replaced dark elevated with pale-grey ground
  static const Color kBgInput = dpPanel;                       // Replaced dark input with clean white panel
  static const Color kAccentBlue = dpAccent;                   // Electric blue
  static const Color kAccentLight = Color(0xFF2563EB);         // Hover/lighter accent
  static const Color kAccentMuted = dpRule;                    // Replaced dark border with subtle rule
  static const Color kTextPrimary = dpInk;                     // Primary dark text on light ground
  static const Color kTextSecond = dpInkSecondary;             // Secondary supporting text
  static const Color kTextHint = Color(0xFF94A3B8);            // Hint/placeholder text
  static const Color kSuccess = dpSuccess;                     // Green
  static const Color kDivider = dpRule;                        // Subtle dividers
  static const Color kDanger = dpDanger;                       // Errors / destructive

  static const Color kWhite = Color(0xFFFFFFFF);
  static const Color kBlack = Color(0xFF16191F);
}
