import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/quiz_provider.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String quizId;
  const QuizScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  int _currentIndex = 0;
  final List<Map<String, dynamic>> _answers = [];
  final DateTime _startTime = DateTime.now();
  String? _selectedOption;
  bool _showExplanation = false;
  bool _isResumed = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedProgress();
  }

  Future<void> _loadSavedProgress() async {
    try {
      final storage = ref.read(quizStorageServiceProvider);
      final saved = await storage.getProgress(widget.quizId);
      if (saved != null && mounted) {
        if (saved.answers.isNotEmpty || saved.currentIndex > 0) {
          setState(() {
            _currentIndex = saved.currentIndex;
            _answers.clear();
            _answers.addAll(saved.answers);
            _isResumed = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _restartQuiz() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restart quiz?'),
        content: const Text('Your current answers will be reset, and you will start over from Question 1.'),
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
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(quizStorageServiceProvider).clearProgress(widget.quizId);
      ref.invalidate(activeQuizIdsProvider);
      setState(() {
        _currentIndex = 0;
        _answers.clear();
        _selectedOption = null;
        _showExplanation = false;
        _isResumed = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz reset to Question 1'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(currentQuizProvider(widget.quizId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Quiz', style: AppTypography.heading3),
        backgroundColor: AppColors.paper,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/quizzes');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded, color: AppColors.textSecondary),
            tooltip: 'Restart from Question 1',
            onPressed: _restartQuiz,
          ),
        ],
      ),
      body: SafeArea(
        child: quizAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e', style: AppTypography.bodyMedium)),
          data: (quiz) {
            final questions = quiz['questions'] as List;
            if (questions.isEmpty) {
              return Center(child: Text('No questions found.', style: AppTypography.bodyMedium));
            }

            // Clamp index in case questions length changed
            if (_currentIndex >= questions.length) {
              _currentIndex = questions.length - 1;
            }

            final q = questions[_currentIndex];
            final qType = q['type'] as String? ?? 'MCQ';
            final rawOptions = q['options'];
            final List<String> options;
            if (rawOptions != null && (rawOptions as List).isNotEmpty) {
              // Use stored options — MCQ always has 4 here
              options = List<String>.from(rawOptions);
            } else if (qType == 'TRUE_FALSE') {
              options = ['True', 'False'];
            } else {
              options = [];
            }
            final isMCQ = qType == 'MCQ' || qType == 'SCENARIO';
            final letters = ['A', 'B', 'C', 'D', 'E'];
            final progress = (_currentIndex + 1) / questions.length;

            return Column(
              children: [
                // ── 1. Sticky Progress Header ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'QUESTION ${(_currentIndex + 1).toString().padLeft(2, '0')} / ${questions.length.toString().padLeft(2, '0')}',
                            style: AppTypography.label.copyWith(color: AppColors.textPrimary),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: AppTypography.mono.copyWith(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => LinearProgressIndicator(
                            value: value,
                            backgroundColor: AppColors.surfaceSunken,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ink),
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Resumed Banner ──────────────────────────────────────────
                if (_isResumed)
                  Container(
                    margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      color: AppColors.highlighterSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark_rounded, size: 18, color: AppColors.ink),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Picked up at Question ${_currentIndex + 1}',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _restartQuiz,
                          style: TextButton.styleFrom(foregroundColor: AppColors.ink),
                          child: Text(
                            'Start over',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(height: 1),

                // ── 2. Scrollable Question & Options ────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Question Text
                        Text(
                          q['text'],
                          style: AppTypography.heading2.copyWith(
                            fontSize: 22,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Options List
                        ...options.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final opt = entry.value;
                          final isSelected = _selectedOption == opt;
                          final isCorrect = opt == q['correctAnswer'];

                          Color bgColor = AppColors.surface;
                          Color borderColor = AppColors.line;
                          double borderWidth = 1;
                          Color letterBg = AppColors.surfaceSunken;
                          Color letterColor = AppColors.textSecondary;
                          Widget? trailingIcon;

                          if (_showExplanation) {
                            if (isCorrect) {
                              bgColor = AppColors.successSoft;
                              borderColor = AppColors.success;
                              borderWidth = 1.5;
                              letterBg = AppColors.success;
                              letterColor = AppColors.onInk;
                              trailingIcon = const Icon(Icons.check_rounded, color: AppColors.success, size: 22);
                            } else if (isSelected && !isCorrect) {
                              bgColor = AppColors.errorSoft;
                              borderColor = AppColors.error;
                              borderWidth = 1.5;
                              letterBg = AppColors.error;
                              letterColor = AppColors.onInk;
                              trailingIcon = const Icon(Icons.close_rounded, color: AppColors.error, size: 22);
                            }
                          } else if (isSelected) {
                            bgColor = AppColors.highlighterSoft;
                            borderColor = AppColors.ink;
                            borderWidth = 1.5;
                            letterBg = AppColors.ink;
                            letterColor = AppColors.highlighter;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                            child: Semantics(
                              selected: isSelected,
                              button: !_showExplanation,
                              child: InkWell(
                                onTap: _showExplanation ? null : () => setState(() => _selectedOption = opt),
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  constraints: const BoxConstraints(minHeight: 56),
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    border: Border.all(color: borderColor, width: borderWidth),
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: letterBg,
                                          borderRadius: BorderRadius.circular(AppRadius.sm),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          isMCQ ? (idx < letters.length ? letters[idx] : '') : (opt == 'True' ? 'T' : 'F'),
                                          style: AppTypography.mono.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: letterColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Text(
                                          opt,
                                          style: AppTypography.bodyLarge.copyWith(
                                            fontSize: 15,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                      if (trailingIcon != null) ...[
                                        const SizedBox(width: 8),
                                        trailingIcon,
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),

                        // Explanation Card
                        if (_showExplanation) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: const BoxDecoration(
                              color: AppColors.surface,
                              border: Border(
                                left: BorderSide(color: AppColors.highlighter, width: 4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lightbulb_outline_rounded, color: AppColors.ink, size: 18),
                                    const SizedBox(width: 8),
                                    Text('WHY', style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  q['explanation'] ?? 'No explanation provided.',
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontSize: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // ── 3. Sticky Bottom Action Bar ──────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _selectedOption == null || _isSubmitting
                          ? null
                          : () {
                              if (!_showExplanation) {
                                setState(() => _showExplanation = true);
                                _answers.add({
                                  'questionId': q['id'],
                                  'userResponse': _selectedOption,
                                  'isCorrect': _selectedOption == q['correctAnswer'],
                                  'timeTaken': 10,
                                });
                                // Save current answered state
                                ref.read(quizStorageServiceProvider).saveProgress(
                                      widget.quizId,
                                      _currentIndex,
                                      _answers,
                                    );
                              } else {
                                if (_currentIndex < questions.length - 1) {
                                  setState(() {
                                    _currentIndex++;
                                    _selectedOption = null;
                                    _showExplanation = false;
                                  });
                                  // Update index in storage
                                  ref.read(quizStorageServiceProvider).saveProgress(
                                        widget.quizId,
                                        _currentIndex,
                                        _answers,
                                      );
                                } else {
                                  _submitQuiz(questions.length);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: AppColors.surfaceSunken,
                        disabledForegroundColor: AppColors.textMuted,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: AppColors.highlighter, strokeWidth: 2.5),
                            )
                          : Text(
                              _selectedOption == null
                                  ? 'Select an answer'
                                  : (_showExplanation
                                      ? (_currentIndex < questions.length - 1 ? 'Next question →' : 'Finish quiz')
                                      : 'Check answer'),
                              style: AppTypography.button.copyWith(
                                fontSize: 16,
                                color: _selectedOption == null ? AppColors.textMuted : AppColors.onInk,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _submitQuiz(int totalQuestions) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final timeTaken = DateTime.now().difference(_startTime).inSeconds;
      final res = await ref.read(quizRepositoryProvider).submitAttempt(widget.quizId, _answers, timeTaken);
      await ref.read(quizStorageServiceProvider).clearProgress(widget.quizId);
      ref.invalidate(quizzesProvider);
      ref.invalidate(activeQuizIdsProvider);

      if (!mounted) return;

      final score = (res['score'] as num?)?.toDouble() ??
          ((_answers.where((a) => a['isCorrect'] == true).length / (totalQuestions > 0 ? totalQuestions : 1)) * 100);
      final correctCount = _answers.where((a) => a['isCorrect'] == true).length;
      final passed = score >= 70;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                passed ? 'NICE WORK' : 'QUIZ COMPLETE',
                style: AppTypography.label.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              // Featured score card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: passed ? AppColors.highlighter : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.ink, width: 1.5),
                  boxShadow: AppShadows.hard,
                ),
                child: Column(
                  children: [
                    Text(
                      '${score.round()}%',
                      style: AppTypography.display.copyWith(fontSize: 56),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$correctCount of $totalQuestions correct',
                      style: AppTypography.mono.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                passed ? 'You know this material well.' : 'Review the explanations and try again.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/quizzes');
                  },
                  child: const Text('View all quizzes'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/home');
                },
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit quiz: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
