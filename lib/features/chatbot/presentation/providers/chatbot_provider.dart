import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lms/core/providers/network_providers.dart';
import 'package:lms/features/auth/presentation/providers/auth_provider.dart';
import 'package:lms/features/auth/presentation/providers/auth_state.dart';
import 'package:lms/features/chatbot/data/chatbot_api_service.dart';

final chatbotApiServiceProvider = Provider<ChatbotApiService>((ref) {
  return ChatbotApiService(ref.read(dioClientProvider).dio);
});

final chatbotProvider = NotifierProvider<ChatbotNotifier, ChatbotState>(
  ChatbotNotifier.new,
);

class ChatbotState {
  const ChatbotState({
    this.conversationId,
    this.messages = const [],
    this.isSending = false,
    this.isLoadingHistory = false,
    this.conversations = const [],
    this.isLoadingConversations = false,
    this.deletingConversationId,
    this.isForbidden = false,
    this.historyError,
  });

  final String? conversationId;
  final List<ChatbotMessage> messages;
  final bool isSending;
  final bool isLoadingHistory;
  final List<ChatbotConversation> conversations;
  final bool isLoadingConversations;
  final String? deletingConversationId;
  final bool isForbidden;
  final String? historyError;

  ChatbotState copyWith({
    String? conversationId,
    bool clearConversationId = false,
    List<ChatbotMessage>? messages,
    bool? isSending,
    bool? isLoadingHistory,
    List<ChatbotConversation>? conversations,
    bool? isLoadingConversations,
    String? deletingConversationId,
    bool clearDeletingConversation = false,
    bool? isForbidden,
    String? historyError,
    bool clearHistoryError = false,
  }) => ChatbotState(
    conversationId: clearConversationId
        ? null
        : conversationId ?? this.conversationId,
    messages: messages ?? this.messages,
    isSending: isSending ?? this.isSending,
    isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
    conversations: conversations ?? this.conversations,
    isLoadingConversations:
        isLoadingConversations ?? this.isLoadingConversations,
    deletingConversationId: clearDeletingConversation
        ? null
        : deletingConversationId ?? this.deletingConversationId,
    isForbidden: isForbidden ?? this.isForbidden,
    historyError: clearHistoryError ? null : historyError ?? this.historyError,
  );
}

class ChatbotNotifier extends Notifier<ChatbotState> {
  late ChatbotApiService _api;
  String? _currentUserId;

  @override
  ChatbotState build() {
    _api = ref.read(chatbotApiServiceProvider);
    final auth = ref.read(authProvider);
    _currentUserId = _userId(auth);
    ref.listen<AuthState>(authProvider, (previous, next) {
      final nextUserId = _userId(next);
      if (_currentUserId != nextUserId) {
        _currentUserId = nextUserId;
        state = const ChatbotState();
      }
    });
    return const ChatbotState();
  }

  Future<void> loadConversation() async {
    final id = state.conversationId;
    if (id == null || state.isLoadingHistory || state.isSending) return;

    state = state.copyWith(isLoadingHistory: true, clearHistoryError: true);
    try {
      final response = await _api.getConversation(id);
      final messages = response['messages'];
      final remoteMessages = messages is List
          ? messages
                .whereType<Map>()
                .map(
                  (item) =>
                      ChatbotMessage.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : <ChatbotMessage>[];
      final failedUserIds = state.messages
          .where((message) => message.isError)
          .map((message) => message.id.replaceFirst('error-', 'user-'))
          .toSet();
      final unsavedMessages = state.messages
          .where(
            (message) => message.isError || failedUserIds.contains(message.id),
          )
          .toList();
      state = state.copyWith(
        messages: [...remoteMessages, ...unsavedMessages],
        isLoadingHistory: false,
      );
    } on ChatbotApiException catch (error) {
      if (error.statusCode == 404) {
        state = const ChatbotState();
      } else {
        _setForbiddenIfNeeded(error);
        state = state.copyWith(
          isLoadingHistory: false,
          historyError: error.message,
        );
      }
    } catch (_) {
      state = state.copyWith(
        isLoadingHistory: false,
        historyError: 'Unable to load this conversation. Please try again.',
      );
    }
  }

  Future<void> loadConversations() async {
    if (state.isLoadingConversations) return;
    state = state.copyWith(
      isLoadingConversations: true,
      clearHistoryError: true,
    );
    try {
      final conversations = await _api.getConversations();
      state = state.copyWith(
        conversations: conversations,
        isLoadingConversations: false,
      );
    } on ChatbotApiException catch (error) {
      _setForbiddenIfNeeded(error);
      state = state.copyWith(
        isLoadingConversations: false,
        historyError: error.message,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingConversations: false,
        historyError: 'Unable to load chat history. Please try again.',
      );
    }
  }

  Future<void> openConversation(String id) async {
    state = state.copyWith(
      conversationId: id,
      messages: const [],
      clearHistoryError: true,
    );
    await loadConversation();
  }

  Future<void> deleteConversation(String id) async {
    if (state.deletingConversationId != null) return;
    state = state.copyWith(deletingConversationId: id, clearHistoryError: true);
    try {
      await _api.deleteConversation(id);
    } on ChatbotApiException catch (error) {
      if (error.statusCode != 404) {
        _setForbiddenIfNeeded(error);
        state = state.copyWith(
          clearDeletingConversation: true,
          historyError: error.message,
        );
        return;
      }
    } catch (_) {
      state = state.copyWith(
        clearDeletingConversation: true,
        historyError: 'Unable to delete this conversation. Please try again.',
      );
      return;
    }

    final wasCurrentConversation = state.conversationId == id;
    state = state.copyWith(
      conversations: state.conversations
          .where((conversation) => conversation.id != id)
          .toList(),
      clearConversationId: wasCurrentConversation,
      messages: wasCurrentConversation ? const [] : null,
      clearDeletingConversation: true,
    );
  }

  void startNewChat() {
    if (state.isSending || state.isLoadingHistory) return;
    state = ChatbotState(isForbidden: state.isForbidden);
  }

  Future<void> send(String text) => _send(text, addUserMessage: true);

  Future<void> retry(ChatbotMessage errorMessage) {
    final retryText = errorMessage.retryText;
    if (retryText == null || state.isSending) return Future.value();
    state = state.copyWith(
      messages: state.messages
          .where((message) => message.id != errorMessage.id)
          .toList(),
    );
    return _send(
      retryText,
      addUserMessage: false,
      localId: errorMessage.id.replaceFirst('error-', ''),
    );
  }

  Future<void> _send(
    String text, {
    required bool addUserMessage,
    String? localId,
  }) async {
    final message = text.trim();
    if (message.isEmpty ||
        message.runes.length > 1000 ||
        state.isSending ||
        state.isLoadingHistory) {
      return;
    }

    final messageId =
        localId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final userMessages = addUserMessage
        ? [
            ...state.messages,
            ChatbotMessage(
              id: 'user-$messageId',
              role: 'user',
              content: message,
            ),
          ]
        : state.messages;
    state = state.copyWith(
      messages: userMessages,
      isSending: true,
      clearHistoryError: true,
    );

    try {
      final response = await _sendWithExpiredConversationRecovery(message);
      final conversation = response['conversation'];
      final answer = response['message'];
      if (conversation is! Map || answer is! Map) {
        throw const ChatbotApiException(
          statusCode: null,
          message: 'The HR assistant returned an invalid response.',
        );
      }
      final conversationId = conversation['id']?.toString();
      if (conversationId == null || conversationId.isEmpty) {
        throw const ChatbotApiException(
          statusCode: null,
          message: 'The HR assistant returned an invalid response.',
        );
      }
      final assistantMessage = ChatbotMessage.fromJson(
        Map<String, dynamic>.from(answer),
      );
      state = state.copyWith(
        conversationId: conversationId,
        messages: [...state.messages, assistantMessage],
        isSending: false,
      );
    } on ChatbotApiException catch (error) {
      _setForbiddenIfNeeded(error);
      final errorId = 'error-$messageId';
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatbotMessage.error(
            id: errorId,
            content: error.message,
            retryText: message,
          ),
        ],
        isSending: false,
      );
    } catch (_) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatbotMessage.error(
            id: 'error-$messageId',
            content: 'Something went wrong, please try again.',
            retryText: message,
          ),
        ],
        isSending: false,
      );
    }
  }

  Future<Map<String, dynamic>> _sendWithExpiredConversationRecovery(
    String text,
  ) async {
    final conversationId = state.conversationId;
    try {
      return await _api.sendMessage(text, conversationId: conversationId);
    } on ChatbotApiException catch (error) {
      if (error.statusCode != 404 || conversationId == null) rethrow;
      final latestMessage = state.messages.isEmpty ? null : state.messages.last;
      state = state.copyWith(
        clearConversationId: true,
        messages: latestMessage == null ? const [] : [latestMessage],
      );
      return _api.sendMessage(text);
    }
  }

  void _setForbiddenIfNeeded(ChatbotApiException error) {
    if (error.statusCode == 403) {
      state = state.copyWith(isForbidden: true);
    }
  }

  String? _userId(AuthState auth) => auth.authUser?.id ?? auth.profile?.userId;
}
