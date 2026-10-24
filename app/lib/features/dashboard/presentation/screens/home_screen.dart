import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/layout/main_layout.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../../quiz/presentation/providers/quiz_provider.dart';
import '../../../flashcard/presentation/providers/flashcard_provider.dart';

const _weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final String firstName = user?.profile?.firstName?.isNotEmpty == true
        ? user!.profile!.firstName!
        : (user?.email.split('@').first ?? 'kartikey');

    final dashboardAsync = ref.watch(dashboardProvider);
    final now = DateTime.now();
    final dateLabel = '${_weekdays[now.weekday - 1]} · ${now.day} ${_months[now.month - 1]}';

    return MainLayout(
      currentIndex: 0,
      child: Container(
        color: AppColors.paper,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            bottom: 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Top Bar: Monogram + Greeting + Menu ──────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // User monogram
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.highlighterSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.ink, width: 1.5),
                      ),
                      child: Text(
                        firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                        style: AppTypography.heading3.copyWith(fontSize: 22, height: 1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date & Greeting
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateLabel, style: AppTypography.label),
                          const SizedBox(height: 2),
                          Text(
                            'Hello, $firstName',
                            style: AppTypography.heading2.copyWith(fontSize: 24),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick navigation button with badge dot
                    Tooltip(
                      message: 'Quick navigation',
                      child: Material(
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          side: const BorderSide(color: AppColors.line),
                        ),
                        child: InkWell(
                          onTap: () => _showQuickNavigationSheet(context, ref),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(
                                  Icons.notifications_none_rounded,
                                  color: AppColors.ink,
                                  size: 22,
                                ),
                                Positioned(
                                  top: 10,
                                  right: 11,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.surface, width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(72, 6, 16, 0),
                child: Text.rich(
                  TextSpan(
                    text: 'Level up your skills with ',
                    style: AppTypography.bodyMedium,
                    children: [
                      TextSpan(
                        text: ' StudyAI ',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w700,
                          backgroundColor: AppColors.highlighter,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 20),

              // ── 2. 4-Card Stats Row ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: dashboardAsync.when(
                  data: (data) {
                    final studyTime = data['studyTime']?.toString() ?? '12h 30m';
                    final tasksDone = data['tasksCompleted']?.toString() ?? '8';
                    final streak = data['streakDays']?.toString() ?? '12 Days';
                    final level = data['userLevel']?.toString() ?? 'Level 3';

                    return Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.schedule_rounded,
                            iconColor: AppColors.primary,
                            iconBgColor: AppColors.primarySoft,
                            value: studyTime,
                            label: 'Study Time',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.task_alt_rounded,
                            iconColor: AppColors.success,
                            iconBgColor: AppColors.successSoft,
                            value: tasksDone,
                            label: 'Tasks Done',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_fire_department_rounded,
                            iconColor: AppColors.accent,
                            iconBgColor: AppColors.accentLight,
                            value: streak.contains('Day') ? streak : '$streak Days',
                            label: 'Streak',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.trending_up_rounded,
                            iconColor: AppColors.info,
                            iconBgColor: AppColors.infoSoft,
                            value: level,
                            label: 'Learner',
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const _StatsRowFallback(),
                  error: (_, __) => const _StatsRowFallback(),
                ),
              ),

              const SizedBox(height: 20),

              // ── 3. Hero Card ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 20, 0),
                child: _AiHeroCard(
                  onTap: () => context.push('/quiz-setup'),
                ),
              ),

              const SizedBox(height: 28),

              // ── 4. Quick Actions Header & 2x2 Grid ──────────────────────────
              _SectionHeader(
                title: 'Quick actions',
                actionLabel: 'See all',
                onAction: () => _showQuickNavigationSheet(context, ref),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.forum_outlined,
                            iconColor: AppColors.primary,
                            iconBgColor: AppColors.primarySoft,
                            title: 'AI Tutor',
                            subtitle: 'Ask, learn, explore',
                            onTap: () => context.go('/chat'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.timer_outlined,
                            iconColor: AppColors.accent,
                            iconBgColor: AppColors.accentLight,
                            title: 'Focus Timer',
                            subtitle: 'Start a 25-min session',
                            onTap: () => context.push('/timer'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.quiz_outlined,
                            iconColor: AppColors.tagSlate,
                            iconBgColor: AppColors.infoSoft,
                            title: 'Quizzes & Tests',
                            subtitle: 'Test your knowledge',
                            onTap: () => context.push('/quizzes'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.style_outlined,
                            iconColor: AppColors.tagOchre,
                            iconBgColor: AppColors.highlighterSoft,
                            title: 'Flashcard Decks',
                            subtitle: 'Spaced repetition',
                            onTap: () => _showFlashcardsBottomSheet(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── 5. Recent Quizzes Header & List ─────────────────────────────
              _SectionHeader(
                title: 'Recent quizzes',
                actionLabel: 'View all',
                onAction: () => context.push('/quizzes'),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _RecentQuizzesSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header: serif title + text action
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.heading3),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: AppColors.ink),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.highlighter,
                    decorationThickness: 3,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.ink),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Stats Card (Study Time, Tasks Done, Streak, Learner)
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRowFallback extends StatelessWidget {
  const _StatsRowFallback();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.schedule_rounded,
            iconColor: AppColors.primary,
            iconBgColor: AppColors.primarySoft,
            value: '12h 30m',
            label: 'Study Time',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.task_alt_rounded,
            iconColor: AppColors.success,
            iconBgColor: AppColors.successSoft,
            value: '8',
            label: 'Tasks Done',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: AppColors.accent,
            iconBgColor: AppColors.accentLight,
            value: '12 Days',
            label: 'Streak',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up_rounded,
            iconColor: AppColors.info,
            iconBgColor: AppColors.infoSoft,
            value: 'Level 3',
            label: 'Learner',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.mono.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label.toUpperCase(),
              style: AppTypography.label.copyWith(fontSize: 9, letterSpacing: 0.8),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Hero Card — ink block with a highlighter offset shadow
// ─────────────────────────────────────────────────────────────────────────────

class _AiHeroCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AiHeroCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.ink, width: 1.5),
        boxShadow: const [
          BoxShadow(color: AppColors.highlighter, offset: Offset(4, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
        child: Row(
          children: [
            // Text & Button on Left
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "TODAY'S SUGGESTION",
                    style: AppTypography.label.copyWith(color: AppColors.highlighter),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Turn your notes into a quiz.',
                    style: AppTypography.heading3.copyWith(
                      color: AppColors.onInk,
                      fontSize: 21,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try generating a quiz from your uploaded documents to test your knowledge!',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onInk.withValues(alpha: 0.72),
                      fontSize: 12.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Material(
                    color: AppColors.highlighter,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Generate a quiz',
                              style: AppTypography.button.copyWith(
                                color: AppColors.ink,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, color: AppColors.ink, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Illustration on Right
            const _QuizStackArt(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Quiz card stack illustration (replaces the robot mascot)
// ─────────────────────────────────────────────────────────────────────────────

class _QuizStackArt extends StatelessWidget {
  const _QuizStackArt();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 92,
        height: 108,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -0.14,
              child: _paperCard(color: AppColors.primaryLight),
            ),
            Transform.rotate(
              angle: 0.07,
              child: _paperCard(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Q.04', style: AppTypography.label.copyWith(fontSize: 9, color: AppColors.ink)),
                      const SizedBox(height: 6),
                      _line(52),
                      const SizedBox(height: 4),
                      _line(38),
                      const SizedBox(height: 10),
                      _option(false),
                      const SizedBox(height: 5),
                      _option(true),
                      const SizedBox(height: 5),
                      _option(false),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _paperCard({required Color color, Widget? child}) {
    return Container(
      width: 74,
      height: 94,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: child,
    );
  }

  static Widget _line(double width) {
    return Container(
      width: width,
      height: 3,
      decoration: BoxDecoration(
        color: AppColors.lineStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  static Widget _option(bool selected) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected ? AppColors.highlighter : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: 1.2),
          ),
        ),
        const SizedBox(width: 5),
        _line(selected ? 34 : 28),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Quick Action Card
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon on left, arrow on right
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                  const Icon(Icons.north_east_rounded, color: AppColors.textMuted, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTypography.title.copyWith(fontSize: 14.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Recent Quizzes Section
// ─────────────────────────────────────────────────────────────────────────────

class _RecentQuizzesSection extends ConsumerWidget {
  const _RecentQuizzesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizzesAsync = ref.watch(quizzesProvider);

    return quizzesAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildMockQuizzesList(context),
      data: (quizzes) {
        if (quizzes.isEmpty) {
          return _buildMockQuizzesList(context);
        }

        // Display user's actual recent quizzes
        return Column(
          children: quizzes.take(3).toList().asMap().entries.map((entry) {
            final quiz = entry.value;
            final id = quiz['id']?.toString() ?? '';
            final title = quiz['title']?.toString() ?? 'Quiz';
            final questionsCount = (quiz['questions'] as List?)?.length ?? 10;
            final attempts = quiz['attempts'] as List? ?? [];
            final hasAttempt = attempts.isNotEmpty;
            final score = hasAttempt ? (attempts.first['score'] as num?)?.round() : null;
            final isCompleted = hasAttempt;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecentQuizItemCard(
                title: title,
                subtitle: '$questionsCount questions · ${score ?? 80}%',
                icon: Icons.storage_rounded,
                tint: AppColors.tags[entry.key % AppColors.tags.length],
                statusText: isCompleted ? 'Completed' : 'In Progress',
                statusBgColor: isCompleted ? AppColors.successSoft : AppColors.warningSoft,
                statusTextColor: isCompleted ? AppColors.success : AppColors.warning,
                onTap: () => context.push('/quiz/$id'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMockQuizzesList(BuildContext context) {
    return Column(
      children: [
        _RecentQuizItemCard(
          title: 'DBMS – Normalization',
          subtitle: '10 questions · 85%',
          icon: Icons.storage_rounded,
          tint: AppColors.tagSage,
          statusText: 'Completed',
          statusBgColor: AppColors.successSoft,
          statusTextColor: AppColors.success,
          onTap: () => context.push('/quizzes'),
        ),
        const SizedBox(height: 8),
        _RecentQuizItemCard(
          title: 'Operating Systems',
          subtitle: '15 questions · 60%',
          icon: Icons.memory_rounded,
          tint: AppColors.tagClay,
          statusText: 'In Progress',
          statusBgColor: AppColors.warningSoft,
          statusTextColor: AppColors.warning,
          onTap: () => context.push('/quizzes'),
        ),
      ],
    );
  }
}

class _RecentQuizItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final String statusText;
  final Color statusBgColor;
  final Color statusTextColor;
  final VoidCallback onTap;

  const _RecentQuizItemCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.statusText,
    required this.statusBgColor,
    required this.statusTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Subject tile
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.title.copyWith(fontSize: 14.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.mono.copyWith(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  statusText,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheets: Quick Navigation & Flashcards
// ─────────────────────────────────────────────────────────────────────────────

Widget _sheetHandle() {
  return Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.lineStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

const _sheetDecoration = BoxDecoration(
  color: AppColors.surface,
  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
  border: Border(top: BorderSide(color: AppColors.line)),
);

void _showQuickNavigationSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (ctx) => Container(
      decoration: _sheetDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            Text('JUMP TO', style: AppTypography.label),
            const SizedBox(height: 4),
            Text('Quick navigation', style: AppTypography.heading3),
            const SizedBox(height: 10),
            _QuickNavItem(
              icon: Icons.forum_outlined,
              color: AppColors.primary,
              title: 'AI Tutor Chat',
              subtitle: 'Chat, ask doubts & get instant explanations',
              onTap: () {
                Navigator.pop(ctx);
                context.go('/chat');
              },
            ),
            _QuickNavItem(
              icon: Icons.quiz_outlined,
              color: AppColors.tagSlate,
              title: 'Quizzes & Practice Tests',
              subtitle: 'Take tests, view history & practice',
              onTap: () {
                Navigator.pop(ctx);
                context.push('/quizzes');
              },
            ),
            _QuickNavItem(
              icon: Icons.style_outlined,
              color: AppColors.tagOchre,
              title: 'Flashcard Decks',
              subtitle: 'Review cards with spaced repetition',
              onTap: () {
                Navigator.pop(ctx);
                _showFlashcardsBottomSheet(context, ref);
              },
            ),
            _QuickNavItem(
              icon: Icons.timer_outlined,
              color: AppColors.accent,
              title: 'Focus Timer',
              subtitle: 'Pomodoro focus study sessions',
              onTap: () {
                Navigator.pop(ctx);
                context.push('/timer');
              },
            ),
            _QuickNavItem(
              icon: Icons.calendar_month_outlined,
              color: AppColors.tagSage,
              title: 'Study Schedule',
              subtitle: 'Structured study planner',
              onTap: () {
                Navigator.pop(ctx);
                context.go('/study-plan');
              },
            ),
            _QuickNavItem(
              icon: Icons.description_outlined,
              color: AppColors.tagPlum,
              title: 'Documents & Notes',
              subtitle: 'Upload PDFs & study materials',
              onTap: () {
                Navigator.pop(ctx);
                context.go('/documents');
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _QuickNavItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickNavItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title, style: AppTypography.title.copyWith(fontSize: 14.5)),
      subtitle: Text(subtitle, style: AppTypography.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

void _showFlashcardsBottomSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: _sheetDecoration,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sheetHandle(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Flashcard decks', style: AppTypography.heading3),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/documents');
                    },
                    style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New deck'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, _) {
                  final decksAsync = ref.watch(decksProvider);
                  return decksAsync.when(
                    data: (decks) {
                      if (decks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.highlighterSoft,
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    border: Border.all(color: AppColors.ink, width: 1.5),
                                  ),
                                  child: const Icon(Icons.style_outlined, size: 30, color: AppColors.ink),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'No flashcard decks yet',
                                  style: AppTypography.heading3.copyWith(fontSize: 18),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Go to Documents and tap "Cards" on any PDF to generate flashcards!',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    context.go('/documents');
                                  },
                                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                                  label: const Text('View documents'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.45,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: decks.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final deck = decks[index];
                            final dueCount = deck['dueCards'] ?? 0;
                            final totalCount = deck['totalCards'] ?? 0;
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 6),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.highlighterSoft,
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: const Icon(Icons.style_rounded, color: AppColors.tagOchre, size: 22),
                              ),
                              title: Text(
                                deck['title'],
                                style: AppTypography.title.copyWith(fontSize: 14.5),
                              ),
                              subtitle: Text(
                                '$totalCount cards · $dueCount due',
                                style: AppTypography.mono.copyWith(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(72, 40),
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  context.push('/flashcard/${deck['id']}');
                                },
                                child: Text(
                                  'Review',
                                  style: AppTypography.button.copyWith(fontSize: 13),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'Error loading decks: $e',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
