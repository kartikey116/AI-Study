import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/components/progress_ring.dart';
import '../../../../core/components/app_button.dart';

class FocusTimerScreen extends StatelessWidget {
  const FocusTimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('Focus Timer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('NOW FOCUSING', style: AppTypography.label),
              const SizedBox(height: AppSpacing.sm),
              Text('Database Systems', style: AppTypography.heading2),
              const SizedBox(height: AppSpacing.xl),
              ProgressRing(
                progress: 0.75,
                size: 250,
                color: AppColors.accent,
                centerChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '18:45',
                      style: AppTypography.mono.copyWith(
                        fontSize: 52,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('REMAINING', style: AppTypography.label),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              AppButton(
                text: 'Pause',
                onPressed: () {},
                isPrimary: false,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                text: 'Finish session',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
