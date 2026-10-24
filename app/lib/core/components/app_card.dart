import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Featured cards get an ink outline and a hard offset shadow.
  final bool featured;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.featured = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    final decoration = BoxDecoration(
      color: color ?? AppColors.surface,
      borderRadius: radius,
      border: Border.all(
        color: featured ? AppColors.ink : AppColors.line,
        width: featured ? 1.5 : 1,
      ),
      boxShadow: featured ? AppShadows.hard : AppShadows.card,
    );

    if (onTap == null) {
      return Container(padding: padding, decoration: decoration, child: child);
    }
    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
