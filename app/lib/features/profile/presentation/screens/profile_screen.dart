import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Profile & Settings', style: AppTypography.heading2.copyWith(fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Hero Profile Card ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar with gradient ring
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFFF0EEFF),
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // User Name
                    Text(
                      fullName,
                      style: AppTypography.heading2.copyWith(fontSize: 22),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    // Email
                    Text(
                      email,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EEFF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'StudyAI Scholar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── 2. Study Statistics Bar ──────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ProfileStatItem(
                      label: 'Quizzes',
                      value: '$quizCount',
                      icon: Icons.quiz_outlined,
                      color: AppColors.primary,
                    ),
                    Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                    _ProfileStatItem(
                      label: 'Documents',
                      value: '$docCount',
                      icon: Icons.description_outlined,
                      color: const Color(0xFF2563EB),
                    ),
                    Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                    _ProfileStatItem(
                      label: 'Avg Score',
                      value: completedQuizzes.isEmpty ? '—' : '${avgScore.round()}%',
                      icon: Icons.insights_rounded,
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── 3. Study & Learning Options ──────────────────────────────
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'STUDY & PRACTICE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.quiz_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      iconBg: const Color(0xFFF3E8FF),
                      title: 'My Quizzes & Tests',
                      subtitle: 'Review past attempts & resume saved tests',
                      onTap: () => context.push('/quizzes'),
                    ),
                    const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                    _SettingsTile(
                      icon: Icons.timer_rounded,
                      iconColor: const Color(0xFFD97706),
                      iconBg: const Color(0xFFFEF3C7),
                      title: 'Focus Timer',
                      subtitle: 'Custom pomodoro intervals & study timer',
                      onTap: () => context.push('/timer'),
                    ),
                    const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                    _SettingsTile(
                      icon: Icons.description_rounded,
                      iconColor: const Color(0xFF2563EB),
                      iconBg: const Color(0xFFEFF6FF),
                      title: 'Study Documents',
                      subtitle: 'Manage uploaded PDFs and study materials',
                      onTap: () => context.go('/documents'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── 4. Account & App Preferences ─────────────────────────────
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'PREFERENCES & SUPPORT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: AppColors.primary,
                      iconBg: const Color(0xFFF0EEFF),
                      title: 'AI Study Companion',
                      subtitle: 'Configure tutor persona & questions',
                      onTap: () => context.go('/chat'),
                    ),
                    const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      iconColor: const Color(0xFF0D9488),
                      iconBg: const Color(0xFFCCFBF1),
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
                    const Divider(height: 1, indent: 64, color: Color(0xFFF1F5F9)),
                    _SettingsTile(
                      icon: Icons.help_outline_rounded,
                      iconColor: const Color(0xFF64748B),
                      iconBg: const Color(0xFFF1F5F9),
                      title: 'Help & FAQ',
                      subtitle: 'Guides, tips, and assistance',
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── 5. Log Out Button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                    backgroundColor: const Color(0xFFFEF2F2),
                    foregroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _confirmLogout(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── 6. App Version Footer ─────────────────────────────────────
              Text(
                'StudyAI • Version 1.0.0\nEmpowering your learning journey',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.4,
                ),
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: AppTypography.heading2.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
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
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 22),
          ],
        ),
      ),
    );
  }
}
