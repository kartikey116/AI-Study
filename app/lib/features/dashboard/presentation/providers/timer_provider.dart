import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';

class TimerState {
  final int remainingSeconds;
  final bool isRunning;
  final String mode; // 'FOCUS' or 'BREAK'

  TimerState({
    required this.remainingSeconds,
    required this.isRunning,
    required this.mode,
  });

  TimerState copyWith({int? remainingSeconds, bool? isRunning, String? mode}) {
    return TimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      mode: mode ?? this.mode,
    );
  }
}

class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _timer;
  final int _focusTime = 25 * 60;
  final int _breakTime = 5 * 60;

  TimerNotifier() : super(TimerState(remainingSeconds: 25 * 60, isRunning: false, mode: 'FOCUS'));

  void toggleTimer() {
    if (state.isRunning) {
      _timer?.cancel();
      state = state.copyWith(isRunning: false);
    } else {
      state = state.copyWith(isRunning: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (state.remainingSeconds > 0) {
          state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
        } else {
          _timer?.cancel();
          _handleTimerComplete();
        }
      });
    }
  }

  void reset() {
    _timer?.cancel();
    state = TimerState(remainingSeconds: state.mode == 'FOCUS' ? _focusTime : _breakTime, isRunning: false, mode: state.mode);
  }

  void switchMode(String mode) {
    _timer?.cancel();
    state = TimerState(remainingSeconds: mode == 'FOCUS' ? _focusTime : _breakTime, isRunning: false, mode: mode);
  }

  Future<void> _handleTimerComplete() async {
    state = state.copyWith(isRunning: false);
    if (state.mode == 'FOCUS') {
      // Sync completed focus session to backend
      try {
        await DioClient().dio.post('/study/session/sync', data: {
          'durationMinutes': 25,
          'type': 'FOCUS_TIMER'
        });
      } catch (e) {
        // Silently fail for now, ideally queue for offline sync
        print('Offline: failed to sync session');
      }
      // Switch to break
      switchMode('BREAK');
    } else {
      switchMode('FOCUS');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final timerProvider = StateNotifierProvider<TimerNotifier, TimerState>((ref) => TimerNotifier());
