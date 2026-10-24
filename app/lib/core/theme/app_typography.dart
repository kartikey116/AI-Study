import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Fraunces (serif) for headings, Instrument Sans for UI text,
/// JetBrains Mono for labels, stats and metadata.
class AppTypography {
  static TextStyle get display => GoogleFonts.fraunces(
        fontSize: 40,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -1.2,
        height: 1.05,
      );

  static TextStyle get heading1 => GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.9,
        height: 1.1,
      );

  static TextStyle get heading2 => GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
        height: 1.15,
      );

  static TextStyle get heading3 => GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
        height: 1.2,
      );

  static TextStyle get title => GoogleFonts.instrumentSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get bodyLarge => GoogleFonts.instrumentSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.instrumentSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        height: 1.45,
      );

  static TextStyle get bodySmall => GoogleFonts.instrumentSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        height: 1.4,
      );

  /// Uppercase mono eyebrow, e.g. "TODAY · 3 TASKS".
  static TextStyle get label => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      );

  /// Tabular numbers for stats, timers, scores.
  static TextStyle get mono => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get button => GoogleFonts.instrumentSans(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.onInk,
        letterSpacing: 0.1,
      );
}
