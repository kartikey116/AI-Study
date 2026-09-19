import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class ChatRepository {
  final DioClient _api = DioClient();

  Future<List<dynamic>> getConversations() async {
    final response = await _api.dio.get('/chat/conversations');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getConversationDetails(String id) async {
    final response = await _api.dio.get('/chat/conversations/$id');
    return response.data as Map<String, dynamic>;
  }

  /// Streams a chat message and yields chunks back to the UI.
  Stream<Map<String, dynamic>> sendMessageStream(String message, String? conversationId, {String? documentId}) async* {
    try {
      final response = await _api.dio.post(
        '/chat',
        data: {
          'message': message,
          if (conversationId != null) 'conversationId': conversationId,
          if (documentId != null) 'documentId': documentId,
        },
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'text/event-stream',
          },
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      
      await for (final chunk in stream) {
        final decodedChunk = utf8.decode(chunk);
        final lines = decodedChunk.split('\n\n');
        
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final dataStr = line.substring(6);
            if (dataStr.trim().isEmpty) continue;
            
            try {
              final Map<String, dynamic> data = jsonDecode(dataStr);
              yield data;
            } catch (e) {
              // Ignore malformed JSON during streaming cuts
            }
          }
        }
      }
    } catch (e) {
      yield {'type': 'error', 'message': e.toString()};
    }
  }
}
