import 'package:http/http.dart' as http;
import 'ai_models.dart';

/// Abstract adapter interface for a specific AI backend provider.
abstract class AiProviderAdapter {
  /// Unique identifier of the provider (e.g. 'openai-compatible', 'local-llama').
  String get id;

  /// Human-readable name.
  String get name;

  /// Exposes the static capabilities and availability of this provider.
  AiProviderCapability get capability;

  /// Dispatches an AI request to the provider.
  Future<AiResponse> executeRequest({
    required AiRequest request,
    required AiProviderConfig config,
    http.Client? client,
  });

  /// Aborts any in-flight execution on this provider adapter.
  void cancel();
}

/// Generic base exception for AI provider communication issues.
class AiProviderException implements Exception {
  final String message;
  final int? statusCode;

  AiProviderException(this.message, {this.statusCode});

  String get userMessage => message;

  @override
  String toString() => 'AiProviderException: $message';
}

class AiAuthenticationException extends AiProviderException {
  AiAuthenticationException([super.message = 'Authentication failed. Please verify your API key in Settings.'])
      : super(statusCode: 401);
}

class AiRateLimitException extends AiProviderException {
  AiRateLimitException([super.message = 'Provider rate limit reached. Please wait before retrying.'])
      : super(statusCode: 429);
}

class AiTimeoutException extends AiProviderException {
  AiTimeoutException([super.message = 'The request to the AI provider timed out.'])
      : super(statusCode: 408);
}

class AiMalformedResponseException extends AiProviderException {
  AiMalformedResponseException([super.message = 'Malformed response structure received from AI provider.']);
}
