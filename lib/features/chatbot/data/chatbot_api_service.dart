import 'package:dio/dio.dart';
import 'package:lms/core/network/api_endpoints.dart';
import 'package:lms/core/services/crypto_helper.dart';

class ChatbotApiException implements Exception {
  const ChatbotApiException({
    required this.statusCode,
    required this.message,
    this.retryAfter,
  });

  final int? statusCode;
  final String message;
  final Duration? retryAfter;
}

class ChatbotApiService {
  const ChatbotApiService(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> sendMessage(
    String message, {
    String? conversationId,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.chatbotMessage,
        data: CryptoHelper.encryptPayload({
          'message': message,
          if (conversationId != null) 'conversation_id': conversationId,
        }),
        options: Options(
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      return _asMap(CryptoHelper.decryptPayload(response.data));
    } on DioException catch (error) {
      throw _toChatbotException(error);
    }
  }

  Future<Map<String, dynamic>> getConversation(String id) async {
    try {
      final response = await _dio.get(ApiEndpoints.chatbotConversation(id));
      return _asMap(CryptoHelper.decryptPayload(response.data));
    } on DioException catch (error) {
      throw _toChatbotException(error);
    }
  }

  Future<List<ChatbotConversation>> getConversations() async {
    try {
      final response = await _dio.get(ApiEndpoints.chatbotConversations);
      final body = _asMap(CryptoHelper.decryptPayload(response.data));
      final data = body['data'];
      if (data is! List) {
        throw const ChatbotApiException(
          statusCode: null,
          message: 'The HR assistant returned an invalid conversation list.',
        );
      }
      return data
          .whereType<Map>()
          .map(
            (item) =>
                ChatbotConversation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on DioException catch (error) {
      throw _toChatbotException(error);
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _dio.delete(ApiEndpoints.chatbotConversation(id));
    } on DioException catch (error) {
      throw _toChatbotException(error);
    }
  }

  ChatbotApiException _toChatbotException(DioException error) {
    final statusCode = error.response?.statusCode;
    final decoded = CryptoHelper.decryptPayload(error.response?.data);
    final body = decoded is Map ? decoded : const <String, dynamic>{};
    final serverMessage = body['message']?.toString();
    final message = switch (statusCode) {
      500 => 'Something went wrong, please try again.',
      429 || 503 =>
        serverMessage ??
            'The HR assistant is temporarily unavailable. Please try again shortly.',
      _ =>
        serverMessage ??
            (error.type == DioExceptionType.connectionError
                ? 'No internet connection. Please try again.'
                : 'Something went wrong, please try again.'),
    };
    final retryAfterValue = error.response?.headers.value('retry-after');
    final retryAfterSeconds = int.tryParse(retryAfterValue ?? '');

    return ChatbotApiException(
      statusCode: statusCode,
      message: message,
      retryAfter: retryAfterSeconds == null
          ? null
          : Duration(seconds: retryAfterSeconds),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const ChatbotApiException(
      statusCode: null,
      message: 'The HR assistant returned an invalid response.',
    );
  }
}

class ChatbotConversation {
  const ChatbotConversation({
    required this.id,
    required this.title,
    this.lastMessageAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  factory ChatbotConversation.fromJson(Map<String, dynamic> json) =>
      ChatbotConversation(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        lastMessageAt: DateTime.tryParse(
          json['last_message_at']?.toString() ?? '',
        ),
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      );
}

class ChatbotLink {
  const ChatbotLink({required this.label, required this.route});

  final String label;
  final String route;

  factory ChatbotLink.fromJson(Map<String, dynamic> json) => ChatbotLink(
    label: json['label']?.toString() ?? '',
    route: json['to']?.toString() ?? '',
  );
}

class ChatbotMessage {
  const ChatbotMessage({
    required this.id,
    required this.role,
    required this.content,
    this.links = const [],
    this.retryText,
    this.createdAt,
  });

  final String id;
  final String role;
  final String content;
  final List<ChatbotLink> links;
  final String? retryText;
  final DateTime? createdAt;

  bool get isError => role == 'error';

  factory ChatbotMessage.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['links'];
    return ChatbotMessage(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      links: rawLinks is List
          ? rawLinks
                .whereType<Map>()
                .map(
                  (item) =>
                      ChatbotLink.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  factory ChatbotMessage.error({
    required String id,
    required String content,
    required String retryText,
  }) => ChatbotMessage(
    id: id,
    role: 'error',
    content: content,
    retryText: retryText,
  );
}
