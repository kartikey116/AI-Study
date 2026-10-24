import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../quiz/presentation/providers/quiz_provider.dart';
import '../../../documents/presentation/providers/documents_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Log Out'),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of StudyAI? Your offline study progress will remain saved on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onInk,
              elevation: 0,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final firstName = user?.profile?.firstName?.isNotEmpty == true
        ? user!.profile!.firstName!
        : '';
    final lastName = user?.profile?.lastName?.isNotEmpty == true
        ? user!.profile!.lastName!
        : '';
    final fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
        ? '$firstName $lastName'.trim()
        : (user?.email.split('@').first ?? 'Learner');
    final email = user?.email ?? 'student@studyai.app';

    final quizzesAsync = ref.watch(quizzesProvider);
    final docsAsync = ref.watch(documentsProvider);

    final int quizCount = quizzesAsync.asData?.value.length ?? 0;
    final int docCount = docsAsync.asData?.value.length ?? 0;

    // Calculate average score
    final quizzesList = quizzesAsync.asData?.value ?? [];
    final completedQuizzes = quizzesList.where((q) {
      final attempts = q['attempts'] as List? ?? [];
      return attempts.isNotEmpty;
    }).toList();

    double avgScore = 0;
    if (completedQuizzes.isNotEmpty) {
      final totalScore = completedQuizzes.fold<double>(0, (sum, q) {
        final attempts = q['attempts'] as List? ?? [];
        final score = (attempts.first['score'] as num?)?.toDouble() ?? 0.0;
        return sum + score;
      });
      avgScore = totalScore / completedQuizzes.length;
    }

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Profile', style: AppTypography.heading2),
        backgroundColor: AppColors.paper,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Hero Profile Card (ink block) ─────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.highlighter,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                        style: AppTypography.heading1.copyWith(fontSize: 32, height: 1),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STUDYAI SCHOLAR',
                            style: AppTypography.label.copyWith(color: AppColors.highlighter),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fullName,
                            style: AppTypography.heading2.copyWith(color: AppColors.onInk),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.onInk.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── 2. Study Statistics Bar ──────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.line),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _ProfileStatItem(
                          label: 'Quizzes',
                          value: '$quizCount',
                          icon: Icons.quiz_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      const VerticalDivider(width: 1, color: AppColors.line),
                      Expanded(
                        child: _ProfileStatItem(
                          label: 'Docs',
                          value: '$docCount',
                          icon: Icons.description_outlined,
                          color: AppColors.tagSlate,
                        ),
                      ),
                      const VerticalDivider(width: 1, color: AppColors.line),
                      Expanded(
                        child: _ProfileStatItem(
                          label: 'Avg score',
                          value: completedQuizzes.isEmpty ? '—' : '${avgScore.round()}%',
                          icon: Icons.insights_rounded,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── 3. Study & Learning Options ──────────────────────────────
              const _SectionLabel('Study & practice'),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.quiz_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primarySoft,
                    title: 'My Quizzes & Tests',
                    subtitle: 'Review past attempts & resume saved tests',
                    onTap: () => context.push('/quizzes'),
                  ),
                  _SettingsTile(
                    icon: Icons.timer_rounded,
                    iconColor: AppColors.accent,
                    iconBg: AppColors.accentLight,
                    title: 'Focus Timer',
                    subtitle: 'Custom pomodoro intervals & study timer',
                    onTap: () => context.push('/timer'),
                  ),
                  _SettingsTile(
                    icon: Icons.description_rounded,
                    iconColor: AppColors.tagSlate,
                    iconBg: AppColors.infoSoft,
                    title: 'Study Documents',
                    subtitle: 'Manage uploaded PDFs and study materials',
                    onTap: () => context.go('/documents'),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── 4. Account & App Preferences ─────────────────────────────
              const _SectionLabel('Preferences & support'),
              _SettingsGroup(
                children: [
                  _SettingsTile(
                    icon: Icons.forum_outlined,
                    iconColor: AppColors.ink,
                    iconBg: AppColors.highlighterSoft,
                    title: 'Study Assistant',
                    subtitle: 'Configure tutor persona & questions',
                    onTap: () => context.go('/chat'),
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    iconColor: AppColors.tagSage,
                    iconBg: AppColors.successSoft,
                    title: 'Study Reminders',
                    subtitle: 'Daily learning notifications',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Study reminders are enabled'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    icon: Icons.help_outline_rounded,
                    iconColor: AppColors.textSecondary,
                    iconBg: AppColors.surfaceSunken,
                    title: 'Help & FAQ',
                    subtitle: 'Guides, tips, and assistance',
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('StudyAI Help'),
                          content: const Text(
                            'StudyAI is your AI-powered companion.\n\n'
                            '• Upload PDFs in Documents to generate quizzes.\n'
                            '• Use Focus Timer for 25-min Pomodoro sessions.\n'
                            '• Chat with the AI tutor for interactive problem solving.\n'
                            '• Resume unfinished quizzes anytime from My Quizzes.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── 5. Log Out Button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  onPressed: () => _confirmLogout(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: Text(
                    'Log Out',
                    style: AppTypography.button.copyWith(color: AppColors.error),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── 6. App Version Footer ─────────────────────────────────────
              Text(
                'STUDYAI · V1.0.0',
                textAlign: TextAlign.center,
                style: AppTypography.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subcomponents
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(), style: AppTypography.label),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 64, color: AppColors.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ProfileStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.heading2.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label.toUpperCase(), style: AppTypography.label.copyWith(fontSize: 10)),
          ],
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.title.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.lineStrong, size: 22),
          ],
        ),
      ),
    );
  }
}
