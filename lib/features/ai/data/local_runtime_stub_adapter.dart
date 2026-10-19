import 'package:http/http.dart' as http;
import '../domain/ai_consent_policy.dart';
import '../domain/ai_models.dart';
import '../domain/ai_provider_adapter.dart';

/// Represents a local on-device inference runtime (e.g., llama.cpp or ONNX).
///
/// Under Phase 3, this engine is declared with [isAvailable: false].
/// Attempting to execute inference here fails explicitly with [LocalInferenceFailureException]
/// to guarantee that local execution NEVER silently falls back to remote cloud providers.
class LocalRuntimeStubAdapter implements AiProviderAdapter {
  @override
  String get id => 'local-runtime';

  @override
  String get name => 'Local Runtime Engine';

  @override
  AiProviderCapability get capability => const AiProviderCapability(
        isLocal: true,
        isAvailable: false,
        supportsStreaming: false,
        supportsResearchContext: true,
        availabilityMessage:
            'On-device local inference is planned for Phase 5. No local runtime is currently installed.',
      );

  @override
  Future<AiResponse> executeRequest({
    required AiRequest request,
    required AiProviderConfig config,
    http.Client? client,
  }) async {
    // Explicit failure. Never redirect or fall back to an external cloud provider.
    throw LocalInferenceFailureException(
      'Local hardware inference runtime is not available on this device.',
    );
  }

  @override
  void cancel() {
    // No-op for unavailable engine
  }
}
