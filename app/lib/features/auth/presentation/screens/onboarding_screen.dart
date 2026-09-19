import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/components/app_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu_book, size: 100, color: AppColors.primary),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Your Personal\nAI Tutor',
                      style: AppTypography.heading1,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Upload your notes, ask questions, and get personalized study plans to ace your exams.',
                      style: AppTypography.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              AppButton(
                text: 'Get Started',
                onPressed: () => context.go('/register'),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                text: 'Log In',
                isPrimary: false,
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
