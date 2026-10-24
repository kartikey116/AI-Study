import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
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
    final isFocus = timerState.mode == 'FOCUS';
    final ringColor = isFocus ? AppColors.accent : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: Text('Focus Timer', style: AppTypography.heading3),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Segmented mode switch
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadius.md + 2),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModeButton(
                    title: 'Focus',
                    isSelected: isFocus,
                    onTap: () => notifier.switchMode('FOCUS'),
                  ),
                  _ModeButton(
                    title: 'Break',
                    isSelected: timerState.mode == 'BREAK',
                    onTap: () => notifier.switchMode('BREAK'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Text(
              isFocus ? 'DEEP WORK' : 'SHORT BREAK',
              style: AppTypography.label,
            ),
            const SizedBox(height: AppSpacing.md),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 260,
                  height: 260,
                  child: CircularProgressIndicator(
                    value: timerState.remainingSeconds / (isFocus ? 25 * 60 : 5 * 60),
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: AppColors.surfaceSunken,
                    valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                  ),
                ),
                Container(
                  width: 210,
                  height: 210,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    '$minutes:$seconds',
                    style: AppTypography.mono.copyWith(
                      fontSize: 56,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 56),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Featured: play / pause
                Semantics(
                  button: true,
                  label: timerState.isRunning ? 'Pause timer' : 'Start timer',
                  child: GestureDetector(
                    onTap: () => notifier.toggleTimer(),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(AppRadius.xl + 6),
                        border: Border.all(color: AppColors.ink, width: 1.5),
                        boxShadow: AppShadows.hard,
                      ),
                      child: Icon(
                        timerState.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: AppColors.highlighter,
                        size: 44,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xl),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: IconButton(
                    tooltip: 'Reset timer',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.line),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    onPressed: () => notifier.reset(),
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                  ),
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
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            title,
            style: AppTypography.title.copyWith(
              fontSize: 14,
              color: isSelected ? AppColors.onInk : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
