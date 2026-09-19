import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/flashcard_repository.dart';

final flashcardRepositoryProvider = Provider((ref) => FlashcardRepository(DioClient()));

final decksProvider = FutureProvider((ref) {
  return ref.watch(flashcardRepositoryProvider).getDecks();
});

final dueCardsProvider = FutureProvider.family<List<dynamic>, String>((ref, deckId) {
  return ref.watch(flashcardRepositoryProvider).getDueCards(deckId);
});
