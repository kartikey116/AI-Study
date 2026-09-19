import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_colors.dart';
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
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Oops!',
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
              text: 'Try Again',
              onPressed: onRetry,
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }
}
