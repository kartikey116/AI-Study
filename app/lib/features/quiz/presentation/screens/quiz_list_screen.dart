import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/quiz_provider.dart';

class QuizListScreen extends ConsumerStatefulWidget {
  const QuizListScreen({super.key});

  @override
  ConsumerState<QuizListScreen> createState() => _QuizListScreenState();
}

class _QuizListScreenState extends ConsumerState<QuizListScreen> {
  String _selectedFilter = 'All'; // 'All', 'In Progress', 'Completed'

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.success;
      case 'hard':
        return AppColors.error;
      case 'medium':
      default:
        return AppColors.warning;
    }
  }

  Color _getDifficultyBg(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.successSoft;
      case 'hard':
        return AppColors.errorSoft;
      case 'medium':
      default:
        return AppColors.warningSoft;
    }
  }

  Future<void> _deleteQuiz(String quizId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete quiz?'),
        content: Text('Are you sure you want to delete "$title"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onInk,
              minimumSize: const Size(64, 44),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(quizRepositoryProvider).deleteQuiz(quizId);
        await ref.read(quizStorageServiceProvider).clearProgress(quizId);
        ref.invalidate(quizzesProvider);
        ref.invalidate(activeQuizIdsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "$title"'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete quiz: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizzesAsync = ref.watch(quizzesProvider);
    final activeIdsAsync = ref.watch(activeQuizIdsProvider);
    final activeQuizIds = activeIdsAsync.asData?.value ?? <String>{};

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('My quizzes', style: AppTypography.heading2.copyWith(fontSize: 22)),
        backgroundColor: AppColors.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(quizzesProvider);
              ref.invalidate(activeQuizIdsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded, color: AppColors.highlighter),
        label: Text('New quiz', style: AppTypography.button),
        onPressed: () => context.push('/quiz-setup'),
      ),
      body: SafeArea(
        child: quizzesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.errorSoft,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(Icons.error_outline_rounded, size: 32, color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                  Text("Quizzes didn't load", style: AppTypography.heading3),
                  const SizedBox(height: 8),
                  Text('$e', style: AppTypography.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {
                      ref.invalidate(quizzesProvider);
                      ref.invalidate(activeQuizIdsProvider);
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
          data: (quizzes) {
            // Compute statistics
            final totalCount = quizzes.length;
            final completedList = quizzes.where((q) {
              final attempts = q['attempts'] as List? ?? [];
              return attempts.isNotEmpty;
            }).toList();
            final inProgressList = quizzes.where((q) {
              final id = q['id']?.toString() ?? '';
              return activeQuizIds.contains(id);
            }).toList();

            double avgScore = 0;
            if (completedList.isNotEmpty) {
              final totalScore = completedList.fold<double>(0, (sum, q) {
                final attempts = q['attempts'] as List? ?? [];
                final score = (attempts.first['score'] as num?)?.toDouble() ?? 0.0;
                return sum + score;
              });
              avgScore = totalScore / completedList.length;
            }

            // Filter items
            final filteredQuizzes = quizzes.where((q) {
              final id = q['id']?.toString() ?? '';
              final isInProgress = activeQuizIds.contains(id);
              final attempts = q['attempts'] as List? ?? [];
              final isCompleted = attempts.isNotEmpty;

              if (_selectedFilter == 'In Progress') {
                return isInProgress;
              } else if (_selectedFilter == 'Completed') {
                return isCompleted;
              }
              return true;
            }).toList();

            return RefreshIndicator(
              color: AppColors.ink,
              onRefresh: () async {
                ref.invalidate(quizzesProvider);
                ref.invalidate(activeQuizIdsProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Statistics Bar (featured ink block) ───────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatItem(
                                label: 'Total',
                                value: '$totalCount',
                              ),
                            ),
                            const VerticalDivider(color: AppColors.inkSoft, width: 1, thickness: 1),
                            Expanded(
                              child: _StatItem(
                                label: 'Completed',
                                value: '${completedList.length}',
                              ),
                            ),
                            const VerticalDivider(color: AppColors.inkSoft, width: 1, thickness: 1),
                            Expanded(
                              child: _StatItem(
                                label: 'Avg score',
                                value: completedList.isEmpty ? '—' : '${avgScore.round()}%',
                                highlight: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── 2. Filter Tabs ───────────────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            count: totalCount,
                            isSelected: _selectedFilter == 'All',
                            onTap: () => setState(() => _selectedFilter = 'All'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'In progress',
                            count: inProgressList.length,
                            isSelected: _selectedFilter == 'In Progress',
                            onTap: () => setState(() => _selectedFilter = 'In Progress'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Completed',
                            count: completedList.length,
                            isSelected: _selectedFilter == 'Completed',
                            onTap: () => setState(() => _selectedFilter = 'Completed'),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── 3. Quizzes List or Empty State ────────────────────────
                    if (filteredQuizzes.isEmpty)
                      _EmptyQuizzesView(
                        filter: _selectedFilter,
                        onGenerateTap: () => context.push('/quiz-setup'),
                      )
                    else
                      ...filteredQuizzes.map((quiz) {
                        final id = quiz['id']?.toString() ?? '';
                        final title = quiz['title']?.toString() ?? 'Quiz';
                        final subject = quiz['subject']?.toString() ?? 'General';
                        final difficulty = quiz['difficulty']?.toString() ?? 'Medium';
                        final questionCount = (quiz['_count']?['questions'] as num?)?.toInt() ?? 0;
                        final attempts = quiz['attempts'] as List? ?? [];
                        final hasAttempt = attempts.isNotEmpty;
                        final isInProgress = activeQuizIds.contains(id);

                        final latestAttempt = hasAttempt ? attempts.first : null;
                        final score = (latestAttempt?['score'] as num?)?.round();
                        final passed = (score ?? 0) >= 70;

                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: isInProgress ? AppColors.ink : AppColors.line,
                              width: isInProgress ? 1.5 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badges row & delete icon
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        subject.toUpperCase(),
                                        style: AppTypography.label.copyWith(color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getDifficultyBg(difficulty),
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: Text(
                                        difficulty.toUpperCase(),
                                        style: AppTypography.label.copyWith(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _getDifficultyColor(difficulty),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded,
                                          size: 20, color: AppColors.textMuted),
                                      tooltip: 'Delete quiz',
                                      onPressed: () => _deleteQuiz(id, title),
                                    ),
                                  ],
                                ),

                                Padding(
                                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Title
                                      Text(
                                        title,
                                        style: AppTypography.heading3.copyWith(fontSize: 19),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      const SizedBox(height: 8),

                                      // Metadata row (Questions + Attempt Score / Status)
                                      Row(
                                        children: [
                                          Text(
                                            '$questionCount Q',
                                            style: AppTypography.mono.copyWith(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          if (isInProgress)
                                            const _StatusTag(
                                              icon: Icons.bookmark_rounded,
                                              text: 'In progress',
                                              fg: AppColors.ink,
                                              bg: AppColors.highlighter,
                                            )
                                          else if (hasAttempt)
                                            _StatusTag(
                                              text: 'Score $score%',
                                              fg: passed ? AppColors.success : AppColors.warning,
                                              bg: passed ? AppColors.successSoft : AppColors.warningSoft,
                                            ),
                                        ],
                                      ),

                                      const SizedBox(height: 14),

                                      // Action Button
                                      SizedBox(
                                        width: double.infinity,
                                        height: 48,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: hasAttempt && !isInProgress
                                                ? AppColors.surface
                                                : AppColors.ink,
                                            foregroundColor: hasAttempt && !isInProgress
                                                ? AppColors.ink
                                                : AppColors.onInk,
                                            minimumSize: const Size(64, 48),
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            side: hasAttempt && !isInProgress
                                                ? const BorderSide(color: AppColors.ink, width: 1.5)
                                                : BorderSide.none,
                                          ),
                                          onPressed: () {
                                            context.push('/quiz/$id');
                                          },
                                          icon: Icon(
                                            isInProgress
                                                ? Icons.play_arrow_rounded
                                                : (hasAttempt ? Icons.replay_rounded : Icons.play_arrow_rounded),
                                            size: 20,
                                            color: hasAttempt && !isInProgress
                                                ? AppColors.ink
                                                : AppColors.highlighter,
                                          ),
                                          label: Text(
                                            isInProgress
                                                ? 'Resume quiz'
                                                : (hasAttempt ? 'Retake quiz' : 'Start quiz'),
                                            maxLines: 1,
                                            softWrap: false,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.button.copyWith(
                                              fontSize: 14,
                                              color: hasAttempt && !isInProgress
                                                  ? AppColors.ink
                                                  : AppColors.onInk,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subcomponents
// ─────────────────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.heading2.copyWith(
            fontSize: 24,
            color: highlight ? AppColors.highlighter : AppColors.onInk,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: AppTypography.label.copyWith(
            fontSize: 10,
            color: AppColors.onInk.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

class _StatusTag extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color fg;
  final Color bg;

  const _StatusTag({
    this.icon,
    required this.text,
    required this.fg,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.ink : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? AppColors.ink : AppColors.line,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.onInk : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: AppTypography.mono.copyWith(
                  fontSize: 12,
                  color: isSelected ? AppColors.highlighter : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyQuizzesView extends StatelessWidget {
  final String filter;
  final VoidCallback onGenerateTap;

  const _EmptyQuizzesView({
    required this.filter,
    required this.onGenerateTap,
  });

  @override
  Widget build(BuildContext context) {
    String title = 'No quizzes yet';
    String description =
        'Generate personalized quizzes from your documents or explore any subject of your choice.';

    if (filter == 'In Progress') {
      title = 'Nothing in progress';
      description = 'You don\'t have any unfinished quizzes. Start or resume one anytime.';
    } else if (filter == 'Completed') {
      title = 'No completed quizzes';
      description = 'Take a quiz to see your scores and mastery here.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.highlighterSoft,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.ink, width: 1.5),
              boxShadow: AppShadows.hard,
            ),
            child: const Icon(
              Icons.quiz_outlined,
              size: 34,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: AppTypography.heading3, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onGenerateTap,
            icon: const Icon(Icons.add_rounded, size: 20, color: AppColors.highlighter),
            label: const Text('Generate new quiz'),
          ),
        ],
      ),
    );
  }
}
