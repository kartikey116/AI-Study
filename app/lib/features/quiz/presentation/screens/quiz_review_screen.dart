import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/components/error_state.dart';
import '../../../../core/components/math_markdown.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../providers/quiz_provider.dart';

enum _ReviewFilter { all, wrong, correct }

/// Score summary plus a question-by-question breakdown of the latest attempt.
class QuizReviewScreen extends ConsumerStatefulWidget {
  final String quizId;
  const QuizReviewScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends ConsumerState<QuizReviewScreen> {
  _ReviewFilter _filter = _ReviewFilter.all;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/quizzes');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewAsync = ref.watch(quizReviewProvider(widget.quizId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: _back,
        ),
        title: const Text('Review'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: reviewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorState(
          message: "We couldn't load this attempt. Take the quiz first, or try again.",
          onRetry: () => ref.invalidate(quizReviewProvider(widget.quizId)),
        ),
        data: (data) {
          final quiz = Map<String, dynamic>.from(data['quiz'] as Map);
          final attempt = Map<String, dynamic>.from(data['attempt'] as Map);
          final questions = (quiz['questions'] as List? ?? [])
              .map((q) => Map<String, dynamic>.from(q as Map))
              .toList();
          final answers = <String, Map<String, dynamic>>{
            for (final a in (attempt['answers'] as List? ?? []))
              (a as Map)['questionId'].toString(): Map<String, dynamic>.from(a),
          };

          final correct = questions.where((q) => answers[q['id']]?['isCorrect'] == true).length;
          final wrong = questions.length - correct;
          final visible = questions.asMap().entries.where((e) {
            final isCorrect = answers[e.value['id']]?['isCorrect'] == true;
            return switch (_filter) {
              _ReviewFilter.all => true,
              _ReviewFilter.correct => isCorrect,
              _ReviewFilter.wrong => !isCorrect,
            };
          }).toList();

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
                  children: [
                    _ScoreCard(
                      title: quiz['title']?.toString() ?? 'Quiz',
                      subject: quiz['subject']?.toString(),
                      score: (attempt['score'] as num?)?.toDouble() ?? 0,
                      correct: correct,
                      total: questions.length,
                      timeTaken: (attempt['timeTaken'] as num?)?.toInt() ?? 0,
                      takenAt: DateTime.tryParse(attempt['createdAt']?.toString() ?? ''),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FilterBar(
                      filter: _filter,
                      counts: {
                        _ReviewFilter.all: questions.length,
                        _ReviewFilter.wrong: wrong,
                        _ReviewFilter.correct: correct,
                      },
                      onChanged: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Text(
                          _filter == _ReviewFilter.wrong
                              ? 'Nothing wrong here. Every answer was correct.'
                              : 'No correct answers in this attempt yet.',
                          style: AppTypography.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      ...visible.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _QuestionReviewCard(
                              number: e.key + 1,
                              question: e.value,
                              answer: answers[e.value['id']],
                            ),
                          )),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md + MediaQuery.of(context).padding.bottom,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => context.pushReplacement('/quiz/${widget.quizId}'),
                    icon: const Icon(Icons.replay_rounded, color: AppColors.highlighter, size: 20),
                    label: const Text('Retake quiz'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Score card — the screen's featured element
// ─────────────────────────────────────────────────────────────────────────────

class _ScoreCard extends StatelessWidget {
  final String title;
  final String? subject;
  final double score;
  final int correct;
  final int total;
  final int timeTaken;
  final DateTime? takenAt;

  const _ScoreCard({
    required this.title,
    required this.subject,
    required this.score,
    required this.correct,
    required this.total,
    required this.timeTaken,
    required this.takenAt,
  });

  static const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

  String get _duration {
    final m = timeTaken ~/ 60;
    final s = timeTaken % 60;
    return m > 0 ? '${m}m ${s.toString().padLeft(2, '0')}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final passed = score >= 70;
    final local = takenAt?.toLocal();
    final meta = [
      if (subject != null && subject!.isNotEmpty) subject!.toUpperCase(),
      if (local != null) '${local.day} ${_months[local.month - 1]}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg - 4),
      decoration: BoxDecoration(
        color: passed ? AppColors.highlighter : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.ink, width: 1.5),
        boxShadow: AppShadows.hard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meta.isNotEmpty)
            Text(meta, style: AppTypography.label.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            title,
            style: AppTypography.heading3,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${score.round()}%', style: AppTypography.display.copyWith(fontSize: 52)),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$correct / $total correct', style: AppTypography.mono.copyWith(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(_duration, style: AppTypography.mono.copyWith(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All / Wrong / Correct segmented filter
// ─────────────────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final _ReviewFilter filter;
  final Map<_ReviewFilter, int> counts;
  final ValueChanged<_ReviewFilter> onChanged;

  const _FilterBar({required this.filter, required this.counts, required this.onChanged});

  static const _labels = {
    _ReviewFilter.all: 'All',
    _ReviewFilter.wrong: 'Wrong',
    _ReviewFilter.correct: 'Correct',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: _ReviewFilter.values.map((f) {
          final selected = f == filter;
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              child: GestureDetector(
                onTap: () => onChanged(f),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: _labels[f]),
                      TextSpan(
                        text: '  ${counts[f] ?? 0}',
                        style: AppTypography.mono.copyWith(
                          fontSize: 12,
                          color: selected ? AppColors.highlighter : AppColors.textMuted,
                        ),
                      ),
                    ]),
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.onInk : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One question: prompt, options marked right / wrong, explanation
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionReviewCard extends StatelessWidget {
  final int number;
  final Map<String, dynamic> question;
  final Map<String, dynamic>? answer;

  const _QuestionReviewCard({required this.number, required this.question, required this.answer});

  static const _letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  Widget build(BuildContext context) {
    final type = question['type']?.toString() ?? 'MCQ';
    final correctAnswer = question['correctAnswer']?.toString() ?? '';
    final userResponse = answer?['userResponse']?.toString();
    final isCorrect = answer?['isCorrect'] == true;
    final skipped = answer == null;
    final rawOptions = question['options'];
    final options = rawOptions is List
        ? rawOptions.map((o) => o.toString()).toList()
        : (type == 'TRUE_FALSE' ? const ['True', 'False'] : const <String>[]);
    final explanation = question['explanation']?.toString();

    final (statusText, statusFg, statusBg, statusIcon) = skipped
        ? ('Skipped', AppColors.textSecondary, AppColors.surfaceSunken, Icons.remove_rounded)
        : isCorrect
            ? ('Correct', AppColors.success, AppColors.successSoft, Icons.check_rounded)
            : ('Wrong', AppColors.error, AppColors.errorSoft, Icons.close_rounded);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Q ${number.toString().padLeft(2, '0')}', style: AppTypography.label),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusFg),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: statusFg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MathText(
            question['text']?.toString() ?? '',
            style: AppTypography.title.copyWith(fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.md),
          if (options.isNotEmpty)
            ...options.asMap().entries.map((e) => _OptionRow(
                  badge: type == 'TRUE_FALSE'
                      ? e.value.substring(0, 1)
                      : (e.key < _letters.length ? _letters[e.key] : ''),
                  text: e.value,
                  isAnswer: e.value == correctAnswer,
                  isUserPick: e.value == userResponse,
                ))
          else ...[
            _AnswerLine(label: 'YOUR ANSWER', text: userResponse ?? '—', color: isCorrect ? AppColors.success : AppColors.error),
            if (!isCorrect) _AnswerLine(label: 'CORRECT ANSWER', text: correctAnswer, color: AppColors.success),
          ],
          if (explanation != null && explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                color: AppColors.paper,
                border: Border(left: BorderSide(color: AppColors.highlighter, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WHY', style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  MathText(
                    explanation,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String badge;
  final String text;
  final bool isAnswer;
  final bool isUserPick;

  const _OptionRow({required this.badge, required this.text, required this.isAnswer, required this.isUserPick});

  @override
  Widget build(BuildContext context) {
    final wrongPick = isUserPick && !isAnswer;
    final fg = isAnswer ? AppColors.success : (wrongPick ? AppColors.error : AppColors.textSecondary);
    final bg = isAnswer ? AppColors.successSoft : (wrongPick ? AppColors.errorSoft : Colors.transparent);
    final border = isAnswer ? AppColors.success : (wrongPick ? AppColors.error : AppColors.line);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isAnswer || wrongPick ? fg : AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                badge,
                style: AppTypography.mono.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isAnswer || wrongPick ? AppColors.onInk : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MathText(
                text,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: isAnswer || isUserPick ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (isUserPick) ...[
              const SizedBox(width: 8),
              Text('YOU', style: AppTypography.label.copyWith(fontSize: 10, color: fg)),
            ],
            if (isAnswer || wrongPick) ...[
              const SizedBox(width: 6),
              Icon(isAnswer ? Icons.check_rounded : Icons.close_rounded, size: 18, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _AnswerLine({required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label.copyWith(color: color)),
          const SizedBox(height: 4),
          MathText(text, style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
