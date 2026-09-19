import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final Widget? centerChild;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 100.0,
    this.centerChild,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 8,
              color: AppColors.background,
            ),
          ),
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 8,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeCap: StrokeCap.round,
            ),
          ),
          if (centerChild != null) centerChild!,
        ],
      ),
    );
  }
}
