import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
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
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.highlighterSoft,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.ink, width: 1.5),
                boxShadow: AppShadows.hard,
              ),
              child: Icon(icon, size: 40, color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.heading2, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
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
