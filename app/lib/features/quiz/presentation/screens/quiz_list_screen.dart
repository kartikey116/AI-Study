import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
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
        return const Color(0xFF16A34A);
      case 'hard':
        return const Color(0xFFDC2626);
      case 'medium':
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _getDifficultyBg(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFFDCFCE7);
      case 'hard':
        return const Color(0xFFFEE2E2);
      case 'medium':
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  Future<void> _deleteQuiz(String quizId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Quiz?'),
        content: Text('Are you sure you want to delete "$title"? This action cannot be undone.'),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('My Quizzes', style: AppTypography.heading2.copyWith(fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
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
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(quizzesProvider);
              ref.invalidate(activeQuizIdsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Quiz',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
        onPressed: () => context.push('/quiz-setup'),
      ),
      body: SafeArea(
        child: quizzesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Failed to load quizzes', style: AppTypography.heading3),
                const SizedBox(height: 8),
                Text('$e', style: AppTypography.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(quizzesProvider);
                    ref.invalidate(activeQuizIdsProvider);
                  },
                  child: const Text('Try Again'),
                ),
              ],
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
              onRefresh: () async {
                ref.invalidate(quizzesProvider);
                ref.invalidate(activeQuizIdsProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 88),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Statistics Bar ─────────────────────────────────────
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
                          _StatItem(
                            label: 'Total',
                            value: '$totalCount',
                            icon: Icons.quiz_outlined,
                            iconColor: AppColors.primary,
                          ),
                          Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                          _StatItem(
                            label: 'Completed',
                            value: '${completedList.length}',
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: const Color(0xFF16A34A),
                          ),
                          Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
                          _StatItem(
                            label: 'Avg Score',
                            value: completedList.isEmpty ? '—' : '${avgScore.round()}%',
                            icon: Icons.insights_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── 2. Filter Pills ───────────────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All ($totalCount)',
                            isSelected: _selectedFilter == 'All',
                            onTap: () => setState(() => _selectedFilter = 'All'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'In Progress (${inProgressList.length})',
                            isSelected: _selectedFilter == 'In Progress',
                            highlightColor: const Color(0xFF2563EB),
                            onTap: () => setState(() => _selectedFilter = 'In Progress'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Completed (${completedList.length})',
                            isSelected: _selectedFilter == 'Completed',
                            highlightColor: const Color(0xFF16A34A),
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

                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isInProgress
                                  ? AppColors.primary.withOpacity(0.5)
                                  : const Color(0xFFE2E8F0),
                              width: isInProgress ? 1.8 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Badges row & delete icon
                                Row(
                                  children: [
                                    // Subject pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        subject,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    // Difficulty pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getDifficultyBg(difficulty),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        difficulty,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _getDifficultyColor(difficulty),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Delete menu button
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded,
                                          size: 20, color: Color(0xFF94A3B8)),
                                      tooltip: 'Delete Quiz',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _deleteQuiz(id, title),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Title
                                Text(
                                  title,
                                  style: AppTypography.heading3.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 6),

                                // Metadata row (Questions + Attempt Score / Status)
                                Row(
                                  children: [
                                    const Icon(Icons.format_list_bulleted_rounded,
                                        size: 15, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$questionCount questions',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    if (isInProgress) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF93C5FD)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_circle_outline_rounded,
                                                size: 13, color: Color(0xFF2563EB)),
                                            SizedBox(width: 4),
                                            Text(
                                              'In Progress',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF2563EB),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else if (hasAttempt) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (score ?? 0) >= 70
                                              ? const Color(0xFFDCFCE7)
                                              : const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Score: $score%',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: (score ?? 0) >= 70
                                                ? const Color(0xFF16A34A)
                                                : const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),

                                const SizedBox(height: 14),

                                // Action Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isInProgress
                                          ? const Color(0xFF2563EB)
                                          : (hasAttempt
                                              ? Colors.white
                                              : AppColors.primary),
                                      foregroundColor: hasAttempt && !isInProgress
                                          ? AppColors.primary
                                          : Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      side: hasAttempt && !isInProgress
                                          ? const BorderSide(color: AppColors.primary, width: 1.5)
                                          : BorderSide.none,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      context.push('/quiz/$id');
                                    },
                                    icon: Icon(
                                      isInProgress
                                          ? Icons.play_arrow_rounded
                                          : (hasAttempt ? Icons.replay_rounded : Icons.play_arrow_rounded),
                                      size: 20,
                                    ),
                                    label: Text(
                                      isInProgress
                                          ? 'Resume Quiz'
                                          : (hasAttempt ? 'Retake Quiz' : 'Start Quiz'),
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
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
  final IconData icon;
  final Color iconColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color highlightColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.highlightColor = AppColors.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? highlightColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? highlightColor : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: highlightColor.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
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
    String title = 'No Quizzes Yet';
    String description =
        'Generate personalized quizzes from your documents or explore any subject of your choice.';

    if (filter == 'In Progress') {
      title = 'No In-Progress Quizzes';
      description = 'You don\'t have any unfinished quizzes. Start or resume one anytime!';
    } else if (filter == 'Completed') {
      title = 'No Completed Quizzes';
      description = 'Take a quiz to see your scores and mastery here.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xxl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFF0EEFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.quiz_outlined,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppTypography.heading3.copyWith(fontSize: 18)),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onGenerateTap,
            icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
            label: const Text('Generate New Quiz', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
