import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/quiz_repository.dart';
import '../../data/quiz_storage_service.dart';

final quizStorageServiceProvider = Provider((ref) => const QuizStorageService());

final activeQuizIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  return ref.watch(quizStorageServiceProvider).getActiveQuizIds();
});

final quizRepositoryProvider = Provider((ref) => QuizRepository(DioClient()));

final quizzesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(quizRepositoryProvider).getQuizzes();
});

final currentQuizProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) {
  return ref.watch(quizRepositoryProvider).getQuizDetails(id);
});

class QuizGenerationNotifier extends StateNotifier<AsyncValue<void>> {
  final QuizRepository _repository;
  
  QuizGenerationNotifier(this._repository) : super(const AsyncData(null));

  Future<Map<String, dynamic>> generate(String title, String subject, String difficulty, String? documentId, int numQuestions) async {
    state = const AsyncLoading();
    try {
      final res = await _repository.generateQuiz(title, subject, difficulty, documentId, numQuestions);
      state = const AsyncData(null);
      return res;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

final quizGenerationProvider = StateNotifierProvider<QuizGenerationNotifier, AsyncValue<void>>((ref) {
  return QuizGenerationNotifier(ref.watch(quizRepositoryProvider));
});
