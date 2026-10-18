import 'dart:async';

/// Defines where an AI inference request will be executed.
enum AiExecutionTarget {
  /// Executed completely on the user's local hardware (e.g. llama.cpp, ONNX, MediaPipe).
  /// ZERO network packets are sent outside the machine.
  localRuntime,

  /// Executed on a remote cloud provider (e.g. OpenAI, Anthropic, OpenRouter, self-hosted Ollama server).
  externalProvider,
}

/// Information disclosing what data is being transmitted to an external service.
class ExternalTransmissionDisclosure {
  final String providerName;
  final String endpoint;
  final bool includesPageContent;
  final bool includesHistoryContext;
  final int estimatedPromptLength;

  const ExternalTransmissionDisclosure({
    required this.providerName,
    required this.endpoint,
    required this.includesPageContent,
    required this.includesHistoryContext,
    required this.estimatedPromptLength,
  });
}

/// Policy governing whether external fallback is permitted.
/// Strict rule: Silent fallback is FORBIDDEN by default.
enum FallbackPolicy {
  /// If local inference fails, fail explicitly with an informative error.
  /// Never redirect data to an external provider without user confirmation.
  strictLocalNeverFallback,

  /// Require the user to click "Confirm transmission to cloud" before retry.
  promptUserOnFailure,
}

/// Result of an AI inference request.
class AiResponse {
  final String text;
  final AiExecutionTarget executedOn;
  final String providerOrModelName;
  final Duration duration;

  const AiResponse({
    required this.text,
    required this.executedOn,
    required this.providerOrModelName,
    required this.duration,
  });
}

/// Abstract contract for the provider-independent AI Gateway.
abstract class AiGateway {
  /// Currently configured execution target.
  AiExecutionTarget get preferredTarget;

  /// Current fallback policy. Defaults to [FallbackPolicy.strictLocalNeverFallback].
  FallbackPolicy get fallbackPolicy;

  /// Sends a prompt for completion.
  ///
  /// If [target] is [AiExecutionTarget.externalProvider], [disclosure] must be provided
  /// and confirmed by the user before transmission.
  Future<AiResponse> completePrompt({
    required String prompt,
    String? pageContext,
    AiExecutionTarget? target,
    bool userConsentedToExternalTransmission = false,
  });

  /// Streams token-by-token completion.
  Stream<String> streamPrompt({
    required String prompt,
    String? pageContext,
    AiExecutionTarget? target,
    bool userConsentedToExternalTransmission = false,
  });
}

/// Exception thrown when an attempt is made to transmit data externally without explicit consent.
class UnconsentedExternalTransmissionException implements Exception {
  final String message;
  final ExternalTransmissionDisclosure disclosure;

  UnconsentedExternalTransmissionException({
    required this.message,
    required this.disclosure,
  });

  @override
  String toString() => 'UnconsentedExternalTransmissionException: $message ($disclosure)';
}

/// Exception thrown when local inference fails and silent fallback is blocked.
class LocalInferenceFailureException implements Exception {
  final String reason;

  LocalInferenceFailureException(this.reason);

  @override
  String toString() => 'LocalInferenceFailureException: $reason. Silent fallback to cloud is prohibited.';
}
