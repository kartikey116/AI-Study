import 'package:flutter/material.dart';

/// "Study Notebook" palette — warm paper, ink, and a highlighter marker.
/// Screens should reference these tokens instead of raw hex values.
class AppColors {
  // Ink & paper (core neutrals)
  static const Color ink = Color(0xFF1A1915); // near-black, warm
  static const Color inkSoft = Color(0xFF2E2C26);
  static const Color paper = Color(0xFFF7F3EA); // page background
  static const Color surface = Color(0xFFFFFDF8); // cards / sheets
  static const Color surfaceSunken = Color(0xFFEFEADD); // wells, tracks, inputs
  static const Color line = Color(0xFFE4DDCC); // hairline borders
  static const Color lineStrong = Color(0xFFCFC6B1);

  // Primary — forest-green ink
  static const Color primary = Color(0xFF23533F);
  static const Color primaryLight = Color(0xFF8DB5A0);
  static const Color primaryDark = Color(0xFF173A2B);
  static const Color primarySoft = Color(0xFFDDEAE1);

  // Highlighter — marker yellow, used for emphasis and active states
  static const Color highlighter = Color(0xFFF2C94C);
  static const Color highlighterSoft = Color(0xFFFBEDB8);

  // Accent — tomato, used for streaks, timers, urgency
  static const Color accent = Color(0xFFD9573B);
  static const Color accentLight = Color(0xFFF6D5CB);

  // Background (alias kept for existing call sites)
  static const Color background = paper;

  // Text
  static const Color textPrimary = ink;
  static const Color textSecondary = Color(0xFF55503F);
  static const Color textMuted = Color(0xFF6F685A);
  static const Color onInk = Color(0xFFFBF8F1);

  // States
  static const Color success = Color(0xFF2F7D4F);
  static const Color successSoft = Color(0xFFDCEEDF);
  static const Color error = Color(0xFFC2361F);
  static const Color errorSoft = Color(0xFFF7DCD5);
  static const Color warning = Color(0xFFB7791F);
  static const Color warningSoft = Color(0xFFF8E9C8);
  static const Color info = Color(0xFF2F5C9E);
  static const Color infoSoft = Color(0xFFDCE6F4);

  // Subject / category tags — muted, print-like hues
  static const Color tagSage = Color(0xFF5E7F62);
  static const Color tagClay = Color(0xFFB0643F);
  static const Color tagOchre = Color(0xFFA77B16);
  static const Color tagSlate = Color(0xFF4A6382);
  static const Color tagPlum = Color(0xFF7D4E6B);
  static const List<Color> tags = [tagSage, tagClay, tagOchre, tagSlate, tagPlum];

  // Kept for compatibility; flat-ish ink fill rather than a neon gradient.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aiBubbleGradient = LinearGradient(
    colors: [surface, surface],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
