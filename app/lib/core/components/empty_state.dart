import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import 'app_button.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.buttonText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.heading2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (buttonText != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                text: buttonText!,
                onPressed: onAction!,
                isPrimary: false,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
