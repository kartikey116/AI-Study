import '../../../../core/network/dio_client.dart';

class FlashcardRepository {
  final DioClient _dioClient;

  FlashcardRepository(this._dioClient);

  Future<List<dynamic>> getDecks() async {
    final response = await _dioClient.dio.get('/flashcards/decks');
    return response.data;
  }

  Future<Map<String, dynamic>> generateDeck(String title, String? documentId, int numCards) async {
    final response = await _dioClient.dio.post('/flashcards/generate', data: {
      'title': title,
      'documentId': documentId,
      'numCards': numCards
    });
    return response.data;
  }

  Future<List<dynamic>> getDueCards(String deckId) async {
    final response = await _dioClient.dio.get('/flashcards/decks/$deckId/review');
    return response.data;
  }

  Future<void> reviewCard(String cardId, int quality) async {
    await _dioClient.dio.post('/flashcards/review/$cardId', data: {
      'quality': quality
    });
  }
}
