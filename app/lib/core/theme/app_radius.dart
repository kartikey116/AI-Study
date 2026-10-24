import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppRadius {
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double lg = 14.0;
  static const double xl = 18.0;
  static const double pill = 999.0;
}

class AppShadows {
  /// Default cards rely on a hairline border, not blur.
  static List<BoxShadow> get card => const [];

  /// Hard offset "sticker" shadow for hero / featured elements only.
  static List<BoxShadow> get hard => const [
        BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
      ];

  static List<BoxShadow> get hardSmall => const [
        BoxShadow(color: AppColors.ink, offset: Offset(2, 2)),
      ];

  /// Soft lift for floating layers (sheets, menus).
  static List<BoxShadow> get float => [
        BoxShadow(
          color: AppColors.ink.withValues(alpha: 0.10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
