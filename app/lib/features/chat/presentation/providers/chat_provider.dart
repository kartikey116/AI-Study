import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/chat_repository.dart';

class ChatMessage {
  final String content;
  final bool isUser;

  ChatMessage({required this.content, required this.isUser});
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final String? currentConversationId;
  final String? streamingText; // Holds the currently streaming response

  ChatState({
    required this.messages,
    this.isLoading = false,
    this.error,
    this.currentConversationId,
    this.streamingText,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    String? currentConversationId,
    String? streamingText,
    bool clearError = false,
    bool clearStreamingText = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentConversationId: currentConversationId ?? this.currentConversationId,
      streamingText: clearStreamingText ? null : (streamingText ?? this.streamingText),
    );
  }
}

final chatRepositoryProvider = Provider((ref) => ChatRepository());

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;

  ChatNotifier(this._repository) : super(ChatState(messages: []));

  Future<void> loadConversation(String conversationId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final details = await _repository.getConversationDetails(conversationId);
      final List<dynamic> dbMessages = details['messages'] ?? [];
      
      final messages = dbMessages.map((m) {
        return ChatMessage(
          content: m['content'], 
          isUser: m['role'] == 'USER'
        );
      }).toList();

      state = state.copyWith(
        messages: messages,
        currentConversationId: conversationId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to load conversation', isLoading: false);
    }
  }

  Future<void> sendMessage(String text, {String? documentId}) async {
    if (text.trim().isEmpty) return;

    // Add user message to UI immediately
    final userMessage = ChatMessage(content: text, isUser: true);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
      clearError: true,
      streamingText: '',
    );

    try {
      final stream = _repository.sendMessageStream(
        text, 
        state.currentConversationId,
        documentId: documentId,
      );
      
      await for (final data in stream) {
        if (data['type'] == 'meta') {
          state = state.copyWith(currentConversationId: data['conversationId']);
        } else if (data['type'] == 'chunk') {
          final newStreamText = (state.streamingText ?? '') + data['text'];
          state = state.copyWith(streamingText: newStreamText, isLoading: false);
        } else if (data['type'] == 'error') {
          state = state.copyWith(error: data['message'], isLoading: false);
        } else if (data['type'] == 'done') {
          // Finalize stream into a message
          final finalMessage = ChatMessage(content: state.streamingText ?? '', isUser: false);
          state = state.copyWith(
            messages: [...state.messages, finalMessage],
            clearStreamingText: true,
            isLoading: false,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(
        error: 'Network error. Please try again.',
        isLoading: false,
        clearStreamingText: true,
      );
    }
  }

  void startNewChat() {
    state = ChatState(messages: []);
  }

  void retryLastMessage({String? documentId}) {
    if (state.messages.isEmpty) return;
    
    // Find the last user message to retry
    final lastUserMsgIndex = state.messages.lastIndexWhere((m) => m.isUser);
    if (lastUserMsgIndex != -1) {
      final text = state.messages[lastUserMsgIndex].content;
      // Remove everything from that point onwards to "retry"
      final messagesToKeep = state.messages.sublist(0, lastUserMsgIndex);
      state = state.copyWith(messages: messagesToKeep);
      sendMessage(text, documentId: documentId);
    }
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(chatRepositoryProvider));
});
