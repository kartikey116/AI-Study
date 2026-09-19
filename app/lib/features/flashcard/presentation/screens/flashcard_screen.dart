import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../../../../core/theme/app_colors.dart';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Review', style: AppTypography.heading3),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cards) {
          if (cards.isEmpty || _currentIndex >= cards.length) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 80, color: Colors.green),
                  const SizedBox(height: AppSpacing.md),
                  Text('All caught up!', style: AppTypography.heading2),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Return Home'),
                  )
                ],
              ),
            );
          }

          final card = cards[_currentIndex];

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Text('Card ${_currentIndex + 1} of ${cards.length}', style: AppTypography.bodySmall),
                const SizedBox(height: AppSpacing.xl),
                
                Expanded(
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
                      child: Container(
                        key: ValueKey(_isFlipped),
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _isFlipped ? card['back'] : card['front'],
                            style: AppTypography.heading2,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                
                if (!_isFlipped)
                  Text('Tap card to reveal answer', style: AppTypography.bodySmall)
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _RatingButton(
                        label: 'Hard',
                        color: Colors.red,
                        onTap: () => _submitRating(card['id'], 2),
                      ),
                      _RatingButton(
                        label: 'Good',
                        color: Colors.orange,
                        onTap: () => _submitRating(card['id'], 4),
                      ),
                      _RatingButton(
                        label: 'Perfect',
                        color: Colors.green,
                        onTap: () => _submitRating(card['id'], 5),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.xl),
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

class _RatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RatingButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
        ),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
