import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../providers/timer_provider.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final notifier = ref.read(timerProvider.notifier);

    final minutes = (timerState.remainingSeconds / 60).floor().toString().padLeft(2, '0');
    final seconds = (timerState.remainingSeconds % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Focus Timer', style: AppTypography.heading3),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ModeButton(
                  title: 'Focus',
                  isSelected: timerState.mode == 'FOCUS',
                  onTap: () => notifier.switchMode('FOCUS'),
                ),
                const SizedBox(width: AppSpacing.md),
                _ModeButton(
                  title: 'Break',
                  isSelected: timerState.mode == 'BREAK',
                  onTap: () => notifier.switchMode('BREAK'),
                ),
              ],
            ),
            const SizedBox(height: 60),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    value: timerState.remainingSeconds / (timerState.mode == 'FOCUS' ? 25 * 60 : 5 * 60),
                    strokeWidth: 12,
                    backgroundColor: AppColors.primaryLight.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                Text(
                  '$minutes:$seconds',
                  style: AppTypography.heading1.copyWith(fontSize: 64, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.large(
                  heroTag: 'play_pause',
                  backgroundColor: AppColors.primary,
                  onPressed: () => notifier.toggleTimer(),
                  child: Icon(timerState.isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                ),
                const SizedBox(width: AppSpacing.xl),
                FloatingActionButton(
                  heroTag: 'reset',
                  backgroundColor: Colors.white,
                  onPressed: () => notifier.reset(),
                  child: const Icon(Icons.refresh, color: AppColors.textSecondary),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({required this.title, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.textMuted),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textMuted,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
