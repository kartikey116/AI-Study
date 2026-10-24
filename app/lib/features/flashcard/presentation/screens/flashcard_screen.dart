import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../../../../core/components/empty_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/flashcard_provider.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  final String deckId;
  const FlashcardScreen({super.key, required this.deckId});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  int _currentIndex = 0;
  bool _isFlipped = false;

  @override
  Widget build(BuildContext context) {
    final cardsAsync = ref.watch(dueCardsProvider(widget.deckId));

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: Text('Review', style: AppTypography.heading3),
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Error: $e', style: AppTypography.bodyMedium, textAlign: TextAlign.center),
          ),
        ),
        data: (cards) {
          if (cards.isEmpty || _currentIndex >= cards.length) {
            return EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'All caught up',
              message: 'No cards are due in this deck right now. Come back later for the next review.',
              buttonText: 'Return home',
              onAction: () => context.go('/home'),
            );
          }

          final card = cards[_currentIndex];
          final progress = (_currentIndex + 1) / cards.length;

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                // Progress: mono counter + thin ink bar
                Row(
                  children: [
                    Text('CARD', style: AppTypography.label),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${(_currentIndex + 1).toString().padLeft(2, '0')} / ${cards.length.toString().padLeft(2, '0')}',
                      style: AppTypography.mono,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    color: AppColors.ink,
                    backgroundColor: AppColors.surfaceSunken,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                Expanded(
                  child: Semantics(
                    button: true,
                    label: _isFlipped ? 'Answer card. Tap to show question' : 'Question card. Tap to reveal answer',
                    child: GestureDetector(
                      onTap: () => setState(() => _isFlipped = !_isFlipped),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
                          return AnimatedBuilder(
                            animation: rotateAnim,
                            child: child,
                            builder: (context, widget) {
                              final isUnder = (ValueKey(_isFlipped) != widget?.key);
                              var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                              tilt *= isUnder ? -1.0 : 1.0;
                              final value = isUnder ? min(rotateAnim.value, pi / 2) : rotateAnim.value;
                              return Transform(
                                transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                                alignment: Alignment.center,
                                child: widget,
                              );
                            },
                          );
                        },
                        child: _IndexCard(
                          key: ValueKey(_isFlipped),
                          isAnswer: _isFlipped,
                          text: _isFlipped ? card['back'] : card['front'],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                if (!_isFlipped)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text('Tap the card to reveal the answer', style: AppTypography.bodySmall),
                    ],
                  )
                else ...[
                  Text('HOW WELL DID YOU KNOW IT?', style: AppTypography.label),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _RatingButton(
                          label: 'Hard',
                          color: AppColors.error,
                          bgColor: AppColors.errorSoft,
                          onTap: () => _submitRating(card['id'], 2),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _RatingButton(
                          label: 'Good',
                          color: AppColors.warning,
                          bgColor: AppColors.warningSoft,
                          onTap: () => _submitRating(card['id'], 4),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _RatingButton(
                          label: 'Perfect',
                          color: AppColors.success,
                          bgColor: AppColors.successSoft,
                          onTap: () => _submitRating(card['id'], 5),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitRating(String cardId, int quality) async {
    try {
      await ref.read(flashcardRepositoryProvider).reviewCard(cardId, quality);
      setState(() {
        _isFlipped = false;
        _currentIndex++;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to submit rating')));
    }
  }
}

/// Paper index card — the screen's featured element (ink border + hard shadow).
class _IndexCard extends StatelessWidget {
  final bool isAnswer;
  final String text;

  const _IndexCard({super.key, required this.isAnswer, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isAnswer ? AppColors.highlighterSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.ink, width: 1.5),
        boxShadow: AppShadows.hard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Text(isAnswer ? 'ANSWER' : 'QUESTION', style: AppTypography.label),
          ),
          // Index-card header rule
          Container(height: 1.5, color: AppColors.accent.withValues(alpha: 0.6)),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  text,
                  style: AppTypography.heading2,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _RatingButton({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Text(
            label,
            style: AppTypography.title.copyWith(color: color),
          ),
        ),
      ),
    );
  }
}
