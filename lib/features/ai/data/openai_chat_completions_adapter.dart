import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../domain/ai_models.dart';
import '../domain/ai_provider_adapter.dart';

/// Provider adapter for OpenAI-compatible `/chat/completions` APIs.
/// Compatible with OpenAI, OpenRouter, Groq, Mistral, vLLM, and self-hosted server endpoints.
class OpenAiChatCompletionsAdapter implements AiProviderAdapter {
  http.Client? _activeClient;
  bool _isCancelled = false;

  @override
  String get id => 'openai-compatible';

  @override
  String get name => 'Hosted Cloud (OpenAI-Compatible)';

  @override
  AiProviderCapability get capability => const AiProviderCapability(
        isLocal: false,
        isAvailable: true,
        supportsStreaming: false,
        supportsResearchContext: true,
        availabilityMessage: 'Direct HTTPS connection to OpenAI-compatible endpoints.',
      );

  @override
  Future<AiResponse> executeRequest({
    required AiRequest request,
    required AiProviderConfig config,
    http.Client? client,
  }) async {
    _isCancelled = false;
    final httpClient = client ?? http.Client();
    if (client == null) {
      _activeClient = httpClient;
    }

    final stopwatch = Stopwatch()..start();

    try {
      // 1. Validate Base URL
      final parsedUrl = _resolveEndpoint(config.baseUrl);

      // 2. Validate API key for remote providers
      final isLocalhost = parsedUrl.host == 'localhost' || parsedUrl.host == '127.0.0.1';
      if (!isLocalhost && config.apiKey.trim().isEmpty) {
        throw AiAuthenticationException(
          'API key is required for remote AI provider. Configure your key in Settings.',
        );
      }

      // 3. Assemble messages with attached research context
      final messages = <Map<String, dynamic>>[];

      // System prompt + research evidence formatting
      final systemBuffer = StringBuffer();
      if (request.systemPrompt != null && request.systemPrompt!.trim().isNotEmpty) {
        systemBuffer.writeln(request.systemPrompt!.trim());
      }

      if (request.researchContext.isNotEmpty) {
        systemBuffer.writeln('\n[User Attached Research Context]:');
        for (var i = 0; i < request.researchContext.length; i++) {
          final ctx = request.researchContext[i];
          systemBuffer.writeln('${i + 1}. Title: ${ctx.title}');
          if (ctx.sourceUrl != null) {
            systemBuffer.writeln('   Source URL: ${ctx.sourceUrl}');
          }
          systemBuffer.writeln('   Passage: ${ctx.contentSnippet}');
        }
        systemBuffer.writeln('\nGuideline: Reference the supplied source materials accurately without inventing URLs.');
      }

      if (systemBuffer.isNotEmpty) {
        messages.add({
          'role': 'system',
          'content': systemBuffer.toString().trim(),
        });
      }

      for (final m in request.messages) {
        messages.add(m.toJson());
      }

      final requestBody = jsonEncode({
        'model': config.defaultModel.isNotEmpty ? config.defaultModel : 'gpt-4o-mini',
        'messages': messages,
      });

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (config.apiKey.trim().isNotEmpty) 'Authorization': 'Bearer ${config.apiKey.trim()}',
      };

      // 4. Send HTTP POST request with configured timeout
      final httpResponse = await httpClient
          .post(
            parsedUrl,
            headers: headers,
            body: requestBody,
          )
          .timeout(request.timeout);

      stopwatch.stop();

      if (_isCancelled) {
        return AiResponse(
          text: '',
          executedOn: AiExecutionTarget.externalProvider,
          providerId: id,
          model: config.defaultModel,
          duration: stopwatch.elapsed,
          sourceReferences: request.researchContext,
          status: AiCompletionStatus.cancelled,
          errorMessage: 'Request was cancelled by the user.',
        );
      }

      // 5. Handle HTTP status codes
      if (httpResponse.statusCode == 200) {
        try {
          final json = jsonDecode(httpResponse.body) as Map<String, dynamic>;
          final choices = json['choices'] as List<dynamic>?;
          if (choices == null || choices.isEmpty) {
            throw AiMalformedResponseException('Provider response contains no completion choices.');
          }

          final firstChoice = choices[0] as Map<String, dynamic>;
          final message = firstChoice['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String? ?? '';

          final usage = json['usage'] as Map<String, dynamic>?;
          final promptTokens = usage?['prompt_tokens'] as int?;
          final completionTokens = usage?['completion_tokens'] as int?;
          final modelReturned = json['model'] as String? ?? config.defaultModel;

          return AiResponse(
            text: content.trim(),
            executedOn: AiExecutionTarget.externalProvider,
            providerId: id,
            model: modelReturned,
            duration: stopwatch.elapsed,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            sourceReferences: request.researchContext,
            status: AiCompletionStatus.completed,
          );
        } catch (e) {
          if (e is AiMalformedResponseException) rethrow;
          throw AiMalformedResponseException('Failed to parse provider response: $e');
        }
      } else if (httpResponse.statusCode == 401) {
        throw AiAuthenticationException(
          'Authentication failed (HTTP 401). Please check your API key in Settings.',
        );
      } else if (httpResponse.statusCode == 429) {
        throw AiRateLimitException(
          'Rate limit exceeded (HTTP 429). Please wait before trying again.',
        );
      } else if (httpResponse.statusCode >= 500) {
        throw AiProviderException(
          'AI provider service error (HTTP ${httpResponse.statusCode}).',
          statusCode: httpResponse.statusCode,
        );
      } else {
        String safeErrorDetail = '';
        try {
          final errorJson = jsonDecode(httpResponse.body) as Map<String, dynamic>?;
          final err = errorJson?['error'];
          if (err is Map<String, dynamic> && err['message'] is String) {
            safeErrorDetail = ': ${err['message']}';
          }
        } catch (_) {}

        throw AiProviderException(
          'AI provider returned HTTP ${httpResponse.statusCode}$safeErrorDetail',
          statusCode: httpResponse.statusCode,
        );
      }
    } on TimeoutException {
      throw AiTimeoutException('Request timed out after ${request.timeout.inSeconds} seconds.');
    } on http.ClientException catch (e) {
      if (_isCancelled) {
        return AiResponse(
          text: '',
          executedOn: AiExecutionTarget.externalProvider,
          providerId: id,
          model: config.defaultModel,
          duration: stopwatch.elapsed,
          sourceReferences: request.researchContext,
          status: AiCompletionStatus.cancelled,
          errorMessage: 'Request was cancelled.',
        );
      }
      throw AiProviderException('Network connection error: ${e.message}');
    } finally {
      if (client == null) {
        _activeClient = null;
      }
    }
  }

  @override
  void cancel() {
    _isCancelled = true;
    _activeClient?.close();
    _activeClient = null;
  }

  /// Appends `/chat/completions` if not already present in the endpoint URL.
  Uri _resolveEndpoint(String rawBaseUrl) {
    var trimmed = rawBaseUrl.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }

    final parsed = Uri.parse(trimmed);
    if (parsed.path.endsWith('/chat/completions')) {
      return parsed;
    }

    // Append /chat/completions safely
    final cleanPath = parsed.path.endsWith('/') ? '${parsed.path}chat/completions' : '${parsed.path}/chat/completions';
    return parsed.replace(path: cleanPath);
  }
}
