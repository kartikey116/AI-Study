import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/components/app_button.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),
              Text('STUDYAI · 01', style: AppTypography.label),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Your notes,', style: AppTypography.display),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      children: [
                        Text('turned into ', style: AppTypography.display),
                        Stack(
                          children: [
                            Positioned(
                              left: -2,
                              right: -4,
                              bottom: 6,
                              height: 18,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.highlighter,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            Text('grades.', style: AppTypography.display),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Upload your notes, ask questions, and get personalized study plans to ace your exams.',
                      style: AppTypography.bodyLarge.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _FeatureRow(icon: Icons.upload_file_rounded, text: 'Upload PDFs and lecture notes'),
                    const _FeatureRow(icon: Icons.quiz_outlined, text: 'Quiz yourself on what matters'),
                    const _FeatureRow(icon: Icons.calendar_month_outlined, text: 'Follow a plan built around your exams'),
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
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.line),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: AppTypography.title.copyWith(fontSize: 15))),
        ],
      ),
    );
  }
}
