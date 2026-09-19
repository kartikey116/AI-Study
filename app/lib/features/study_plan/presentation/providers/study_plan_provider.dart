import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/study_plan_repository.dart';

final studyPlanRepositoryProvider = Provider((ref) => StudyPlanRepository(DioClient()));

final studyPlanProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ref.watch(studyPlanRepositoryProvider).getActivePlan();
});

class StudyPlanNotifier extends StateNotifier<AsyncValue<void>> {
  final StudyPlanRepository _repository;
  final Ref _ref;

  StudyPlanNotifier(this._repository, this._ref) : super(const AsyncData(null));

  Future<Map<String, dynamic>> generatePlan({
    required DateTime targetDate,
    required List<String> subjects,
    required int hoursPerDay,
  }) async {
    if (state.isLoading) {
      throw Exception('Generation already in progress');
    }
    state = const AsyncLoading();
    try {
      final plan = await _repository.generatePlan(
        targetDate: targetDate,
        subjects: subjects,
        hoursPerDay: hoursPerDay,
      );
      state = const AsyncData(null);
      _ref.invalidate(studyPlanProvider);
      return plan;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> toggleTask(String taskId) async {
    try {
      await _repository.toggleTask(taskId);
      _ref.invalidate(studyPlanProvider);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePlan(String planId) async {
    try {
      await _repository.deletePlan(planId);
      _ref.invalidate(studyPlanProvider);
    } catch (e) {
      rethrow;
    }
  }
}

final studyPlanNotifierProvider = StateNotifierProvider<StudyPlanNotifier, AsyncValue<void>>((ref) {
  return StudyPlanNotifier(ref.watch(studyPlanRepositoryProvider), ref);
});
