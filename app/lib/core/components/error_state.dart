import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import 'app_button.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({
    super.key,
    this.message = 'Something went wrong. Please try again.',
    required this.onRetry,
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
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              "That didn't load",
              style: AppTypography.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              text: 'Try again',
              onPressed: onRetry,
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }
}
