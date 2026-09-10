import 'dart:convert';

import 'ai_errors.dart';

class ChatMessage {
  const ChatMessage.user(this.text) : role = 'user';
  const ChatMessage.assistant(this.text) : role = 'assistant';

  /// `user` | `assistant`
  final String role;
  final String text;
}

/// Uniform access to a chat model. Implementations: Anthropic, Gemini.
abstract class AiProvider {
  /// `anthropic` | `gemini`
  String get id;
  String get model;

  /// Ask for a JSON document conforming to [schema]. Returns the parsed object.
  Future<Map<String, dynamic>> completeJson({
    required String system,
    required String user,
    required Map<String, dynamic> schema,
    int maxTokens = 16000,
    Duration timeout = const Duration(seconds: 180),
  });

  /// Plain text reply for a conversation.
  Future<String> chat({
    required String system,
    required List<ChatMessage> history,
    int maxTokens = 1024,
    Duration timeout = const Duration(seconds: 45),
  });

  /// Cheap request that fails on a bad key.
  Future<void> ping();
}

/// Extracts a JSON object from model text, tolerating code fences and
/// leading/trailing prose.
Map<String, dynamic> parseJsonObject(String text) {
  var t = text.trim();
  final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$', multiLine: false);
  final m = fence.firstMatch(t);
  if (m != null) t = m.group(1)!.trim();
  try {
    final v = jsonDecode(t);
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  } on FormatException {
    // fall through to substring search
  }
  final start = t.indexOf('{');
  final end = t.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try {
      final v = jsonDecode(t.substring(start, end + 1));
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    } on FormatException catch (e) {
      throw AiException(AiErrorKind.badJson, 'Niepoprawny JSON: ${e.message}',
          body: text);
    }
  }
  throw AiException(AiErrorKind.badJson, 'Brak obiektu JSON w odpowiedzi.',
      body: text);
}

/// Runs [fn] with retries for retryable [AiException]s (exponential backoff).
Future<T> withRetry<T>(Future<T> Function() fn, {int attempts = 3}) async {
  var delay = const Duration(seconds: 2);
  for (var i = 1;; i++) {
    try {
      return await fn();
    } on AiException catch (e) {
      if (!e.isRetryable || i >= attempts) rethrow;
      await Future<void>.delayed(delay);
      delay *= 2;
    }
  }
}
