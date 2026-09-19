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
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w500,
        ),
      ),
      avatar: icon != null 
          ? Icon(icon, size: 16, color: AppColors.primaryDark) 
          : null,
      backgroundColor: AppColors.primaryLight.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        side: BorderSide.none,
      ),
      onPressed: onTap ?? () {},
    );
  }
}
