import 'dart:core';

/// Execution target classification for an AI provider.
enum AiExecutionTarget {
  /// Executed completely on the user's local hardware (e.g., llama.cpp, ONNX).
  /// Zero network packets leave the device.
  localRuntime,

  /// Executed on a remote cloud provider (e.g., OpenAI, Anthropic, OpenRouter, self-hosted server).
  externalProvider,
}

/// Completion status of an AI inference request.
enum AiCompletionStatus {
  completed,
  cancelled,
  failed,
}

/// A structured reference to saved research context attached to a prompt.
class ResearchContextReference {
  final String title;
  final String contentSnippet;
  final Uri? sourceUrl;

  const ResearchContextReference({
    required this.title,
    required this.contentSnippet,
    this.sourceUrl,
  });

  String get excerpt => contentSnippet;

  Map<String, dynamic> toMap() => {
    'title': title,
    'contentSnippet': contentSnippet,
    if (sourceUrl != null) 'sourceUrl': sourceUrl.toString(),
  };

  @override
  String toString() => 'ResearchContextReference(title: $title, source: $sourceUrl)';
}

/// An individual message in a conversation.
class AiMessage {
  final String role; // 'system', 'user', 'assistant'
  final String content;

  const AiMessage({
    required this.role,
    required this.content,
  });

  factory AiMessage.user(String content) => AiMessage(role: 'user', content: content);
  factory AiMessage.assistant(String content) => AiMessage(role: 'assistant', content: content);
  factory AiMessage.system(String content) => AiMessage(role: 'system', content: content);

  Map<String, String> toJson() => {
    'role': role,
    'content': content,
  };
}

/// Request model for the AI Gateway.
class AiRequest {
  final List<AiMessage> messages;
  final String? systemPrompt;
  final List<ResearchContextReference> researchContext;
  final String providerId;
  final String model;
  final Duration timeout;

  const AiRequest({
    required this.messages,
    this.systemPrompt,
    this.researchContext = const [],
    required this.providerId,
    required this.model,
    this.timeout = const Duration(seconds: 30),
  });

  /// Convenience constructor for single-turn prompt requests.
  factory AiRequest.prompt({
    required String prompt,
    String? systemPrompt,
    List<ResearchContextReference> researchContext = const [],
    required String providerId,
    required String model,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return AiRequest(
      messages: [AiMessage.user(prompt)],
      systemPrompt: systemPrompt,
      researchContext: researchContext,
      providerId: providerId,
      model: model,
      timeout: timeout,
    );
  }

  /// Calculates total prompt character length for disclosure estimates.
  int get estimatedCharLength {
    int total = 0;
    if (systemPrompt != null) total += systemPrompt!.length;
    for (final m in messages) {
      total += m.content.length;
    }
    for (final r in researchContext) {
      total += r.title.length + r.contentSnippet.length;
    }
    return total;
  }
}

/// Response model returned by the AI Gateway.
class AiResponse {
  final String text;
  final AiExecutionTarget executedOn;
  final String providerId;
  final String model;
  final Duration duration;
  final int? promptTokens;
  final int? completionTokens;
  final List<ResearchContextReference> sourceReferences;
  final AiCompletionStatus status;
  final String? errorMessage;

  const AiResponse({
    required this.text,
    required this.executedOn,
    required this.providerId,
    required this.model,
    required this.duration,
    this.promptTokens,
    this.completionTokens,
    this.sourceReferences = const [],
    this.status = AiCompletionStatus.completed,
    this.errorMessage,
  });

  bool get isSuccess => status == AiCompletionStatus.completed && errorMessage == null;

  AiTokenUsage? get usage {
    if (promptTokens == null && completionTokens == null) return null;
    final p = promptTokens ?? 0;
    final c = completionTokens ?? 0;
    return AiTokenUsage(promptTokens: p, completionTokens: c, totalTokens: p + c);
  }
}

/// Token usage details for an AI completion response.
class AiTokenUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const AiTokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });
}

/// Declares the capabilities of a provider adapter.
class AiProviderCapability {
  final bool isLocal;
  final bool isAvailable;
  final bool supportsStreaming;
  final bool supportsResearchContext;
  final String availabilityMessage;

  const AiProviderCapability({
    required this.isLocal,
    required this.isAvailable,
    this.supportsStreaming = false,
    this.supportsResearchContext = true,
    required this.availabilityMessage,
  });
}

/// Configuration settings for an AI provider.
class AiProviderConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String defaultModel;
  final String apiKey;
  final bool isLocal;

  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    this.apiKey = '',
    this.isLocal = false,
  });

  String get model => defaultModel;

  AiProviderConfig copyWith({
    String? baseUrl,
    String? defaultModel,
    String? model,
    String? apiKey,
  }) {
    return AiProviderConfig(
      id: id,
      name: name,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: model ?? defaultModel ?? this.defaultModel,
      apiKey: apiKey ?? this.apiKey,
      isLocal: isLocal,
    );
  }
}
