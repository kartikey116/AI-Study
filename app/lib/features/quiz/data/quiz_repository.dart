import '../../../../core/network/dio_client.dart';

class QuizRepository {
  final DioClient _dioClient;

  QuizRepository(this._dioClient);

  Future<Map<String, dynamic>> generateQuiz(String title, String subject, String difficulty, String? documentId, int numQuestions) async {
    final response = await _dioClient.dio.post('/quizzes/generate', data: {
      'title': title,
      'subject': subject,
      'difficulty': difficulty,
      'documentId': documentId,
      'numQuestions': numQuestions
    });
    return response.data;
  }

  Future<List<dynamic>> getQuizzes() async {
    final response = await _dioClient.dio.get('/quizzes');
    return response.data;
  }

  Future<Map<String, dynamic>> getQuizDetails(String id) async {
    final response = await _dioClient.dio.get('/quizzes/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> submitAttempt(String quizId, List<Map<String, dynamic>> answers, int timeTaken) async {
    final response = await _dioClient.dio.post('/quizzes/$quizId/submit', data: {
      'answers': answers,
      'timeTaken': timeTaken
    });
    return response.data;
  }

  Future<void> deleteQuiz(String id) async {
    await _dioClient.dio.delete('/quizzes/$id');
  }
}
