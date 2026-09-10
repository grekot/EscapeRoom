enum AiErrorKind {
  noApiKey,
  unauthorized,
  rateLimited,
  refusal,
  truncated,
  badJson,
  network,
  timeout,
  server,
  badRequest,
  unknown,
}

class AiException implements Exception {
  AiException(this.kind, this.message, {this.statusCode, this.body});

  final AiErrorKind kind;
  final String message;
  final int? statusCode;
  final String? body;

  bool get isRetryable =>
      kind == AiErrorKind.rateLimited ||
      kind == AiErrorKind.server ||
      kind == AiErrorKind.network ||
      kind == AiErrorKind.timeout;

  /// Polish, user-facing.
  String get userMessage => switch (kind) {
        AiErrorKind.noApiKey =>
          'Brak klucza API. Wpisz go w Ustawieniach.',
        AiErrorKind.unauthorized =>
          'Klucz API został odrzucony. Sprawdź go w Ustawieniach.',
        AiErrorKind.rateLimited =>
          'Za dużo zapytań lub wyczerpany limit. Odczekaj chwilę i spróbuj ponownie.',
        AiErrorKind.refusal =>
          'Model odmówił wykonania tego zadania. Zmień treść i spróbuj ponownie.',
        AiErrorKind.truncated =>
          'Odpowiedź modelu została ucięta. Spróbuj ponownie lub zmniejsz liczbę etapów.',
        AiErrorKind.badJson =>
          'Model zwrócił niepoprawne dane. Spróbuj ponownie.${message.trim().isEmpty ? '' : '\n\nSzczegóły: $message'}',
        AiErrorKind.network =>
          'Brak połączenia z internetem lub serwer nieosiągalny.',
        AiErrorKind.timeout =>
          'Serwer nie odpowiedział na czas. Spróbuj ponownie.',
        AiErrorKind.server =>
          'Serwer AI zgłosił błąd. Spróbuj ponownie za chwilę.',
        AiErrorKind.badRequest =>
          'Serwer AI odrzucił zapytanie: $message',
        AiErrorKind.unknown => 'Nieoczekiwany błąd: $message',
      };

  @override
  String toString() =>
      'AiException(${kind.name}${statusCode != null ? ' $statusCode' : ''}): $message';
}
