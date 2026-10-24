import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !isLoading && onPressed != null;
    final fg = isPrimary ? AppColors.onInk : AppColors.ink;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppColors.ink : AppColors.surface,
          foregroundColor: fg,
          disabledBackgroundColor:
              isPrimary ? AppColors.inkSoft.withValues(alpha: 0.55) : AppColors.surface,
          disabledForegroundColor: isPrimary ? AppColors.onInk : AppColors.textMuted,
          textStyle: AppTypography.button,
          side: isPrimary ? null : const BorderSide(color: AppColors.ink, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
        onPressed: enabled ? onPressed : null,
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: isPrimary ? AppColors.highlighter : AppColors.ink,
                  strokeWidth: 2,
                ),
              )
            : Text(text),
      ),
    );
  }
}
