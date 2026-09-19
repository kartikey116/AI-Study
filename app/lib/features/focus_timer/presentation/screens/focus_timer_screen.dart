import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/components/progress_ring.dart';
import '../../../../core/components/app_button.dart';

class FocusTimerScreen extends StatelessWidget {
  const FocusTimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Timer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ProgressRing(
                progress: 0.75,
                size: 250,
                centerChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '18:45',
                      style: AppTypography.heading1.copyWith(fontSize: 48),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Focusing on Database',
                      style: AppTypography.bodyMedium,
                    ),
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
                text: 'Finish Session',
                onPressed: () => context.pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
