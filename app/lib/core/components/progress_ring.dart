import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final Widget? centerChild;
  final Color color;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 100.0,
    this.centerChild,
    this.color = AppColors.primary,
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
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                backgroundColor: AppColors.surfaceSunken,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeCap: StrokeCap.round,
              ),
            ),
          ),
          if (centerChild != null) centerChild!,
        ],
      ),
    );
  }
}
