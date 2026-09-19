import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF8B5CF6); // Lavender/Soft Purple
  static const Color primaryLight = Color(0xFFC4B5FD);
  static const Color primaryDark = Color(0xFF6D28D9);

  // Accent
  static const Color accent = Color(0xFFF472B6); // Subtle Pink
  static const Color accentLight = Color(0xFFFBCFE8);

  // Background
  static const Color background = Color(0xFFF8FAFC); // Off-white
  static const Color surface = Color(0xFFFFFFFF); // White Cards

  // Text
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // States
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  
  // Custom gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient aiBubbleGradient = LinearGradient(
    colors: [Color(0xFFE0E7FF), Color(0xFFFCE7F3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
