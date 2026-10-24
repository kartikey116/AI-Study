import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_radius.dart';

class AppChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      avatar: icon != null ? Icon(icon, size: 16, color: AppColors.primary) : null,
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      onPressed: onTap ?? () {},
    );
  }
}
