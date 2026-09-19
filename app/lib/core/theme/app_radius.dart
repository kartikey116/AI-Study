import 'package:flutter/material.dart';

class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double pill = 999.0;
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
}
