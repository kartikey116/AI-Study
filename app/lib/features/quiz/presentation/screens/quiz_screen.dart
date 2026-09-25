import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restart Quiz?'),
        content: const Text('Your current answers will be reset, and you will start over from Question 1.'),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Quiz', style: AppTypography.heading3),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
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
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (quiz) {
            final questions = quiz['questions'] as List;
            if (questions.isEmpty) return const Center(child: Text('No questions found.'));

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

            return Column(
              children: [
                // ── 1. Sticky Progress Header ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentIndex + 1) / questions.length,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EEFF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Question ${_currentIndex + 1} of ${questions.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Text(
                            '${(((_currentIndex + 1) / questions.length) * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Resumed Banner ──────────────────────────────────────────
                if (_isResumed)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF93C5FD)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history_rounded, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Resumed from Question ${_currentIndex + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E40AF),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _restartQuiz,
                          child: const Text(
                            'Start Over',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(height: 1, color: Color(0xFFF1F5F9)),

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
                          style: AppTypography.heading3.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Options List
                        ...options.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final opt = entry.value;
                          final isSelected = _selectedOption == opt;
                          final isCorrect = opt == q['correctAnswer'];

                          Color bgColor = Colors.white;
                          Color borderColor = const Color(0xFFE2E8F0);
                          Color letterBg = const Color(0xFFF8FAFC);
                          Color letterColor = AppColors.textSecondary;
                          Widget? trailingIcon;

                          if (_showExplanation) {
                            if (isCorrect) {
                              bgColor = const Color(0xFFF0FDF4);
                              borderColor = const Color(0xFF22C55E);
                              letterBg = const Color(0xFF22C55E);
                              letterColor = Colors.white;
                              trailingIcon = const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22);
                            } else if (isSelected && !isCorrect) {
                              bgColor = const Color(0xFFFEF2F2);
                              borderColor = const Color(0xFFEF4444);
                              letterBg = const Color(0xFFEF4444);
                              letterColor = Colors.white;
                              trailingIcon = const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 22);
                            }
                          } else if (isSelected) {
                            bgColor = const Color(0xFFF5F3FF);
                            borderColor = AppColors.primary;
                            letterBg = AppColors.primary;
                            letterColor = Colors.white;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: InkWell(
                              onTap: _showExplanation ? null : () => setState(() => _selectedOption = opt),
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  border: Border.all(color: borderColor, width: isSelected || (_showExplanation && isCorrect) ? 2 : 1.5),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: letterBg,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        isMCQ ? (idx < letters.length ? letters[idx] : '') : (opt == 'True' ? 'T' : 'F'),
                                        style: TextStyle(
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
                                        style: AppTypography.bodyMedium.copyWith(
                                          fontSize: 15,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          color: AppColors.textPrimary,
                                          height: 1.3,
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
                          );
                        }),

                        // Explanation Card
                        if (_showExplanation) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.lightbulb_rounded, color: Color(0xFF16A34A), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Explanation',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  q['explanation'] ?? 'No explanation provided.',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF14532D),
                                    height: 1.4,
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
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
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
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Text(
                              _selectedOption == null
                                  ? 'Select an answer'
                                  : (_showExplanation
                                      ? (_currentIndex < questions.length - 1 ? 'Next Question →' : 'Finish Quiz 🎉')
                                      : 'Check Answer'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _selectedOption == null ? AppColors.textMuted : Colors.white,
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

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: score >= 70 ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  score >= 70 ? Icons.emoji_events_rounded : Icons.psychology_rounded,
                  color: score >= 70 ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                score >= 70 ? 'Great Job!' : 'Quiz Completed!',
                style: AppTypography.heading2.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 8),
              Text(
                'You scored ${score.round()}% ($correctCount of $totalQuestions correct)',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.go('/quizzes');
                  },
                  child: const Text(
                    'View All Quizzes',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/home');
                },
                child: const Text('Back to Home'),
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
