import 'ai_consent_policy.dart';
import 'ai_models.dart';

export 'ai_consent_policy.dart';
export 'ai_models.dart';
export 'ai_provider_adapter.dart';

/// Abstract contract for the provider-independent AI Gateway.
abstract class AiGateway {
  /// The list of registered provider configurations.
  List<AiProviderConfig> get availableProviders;

  /// The currently active provider configuration.
  AiProviderConfig get activeConfig;

  /// Selects and updates configuration for an AI provider.
  void setActiveProvider(String providerId);

  /// Updates settings (baseUrl, model, apiKey) for a provider.
  void updateProviderConfig(AiProviderConfig config);

  /// Inspects capabilities of a provider.
  AiProviderCapability getCapability(String providerId);

  /// Executes an AI inference completion.
  ///
  /// Throws [UnconsentedExternalTransmissionException] if [userConsentGiven] is false
  /// for a request targeting an external cloud provider.
  /// Throws [LocalInferenceFailureException] if local inference fails and silent fallback is blocked.
  Future<AiResponse> complete(
    AiRequest request, {
    bool userConsentGiven = false,
  });

  /// Cancels any currently executing in-flight inference request.
  void cancelActiveRequest();

  /// Alias for [cancelActiveRequest].
  void cancelCurrentRequest();

  /// Whether an inference request is currently executing.
  bool get isRequestInProgress;

  /// Privacy and consent policy governing all outbound requests.
  AiConsentPolicy get consentPolicy;
}
