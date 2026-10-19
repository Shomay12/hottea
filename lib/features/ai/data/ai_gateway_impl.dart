import 'package:http/http.dart' as http;
import '../domain/ai_gateway.dart';
import 'local_runtime_stub_adapter.dart';
import 'openai_chat_completions_adapter.dart';

/// Production implementation of [AiGateway].
/// Enforces strict privacy evaluation, provider routing, and explicit cloud consent.
class AiGatewayImpl implements AiGateway {
  final Map<String, AiProviderAdapter> _adapters = {};
  final Map<String, AiProviderConfig> _configs = {};
  final AiConsentPolicy _consentPolicy;
  final http.Client? _injectedClient;

  String _activeProviderId = 'openai-compatible';
  AiProviderAdapter? _currentRunningAdapter;
  bool _isRequestInProgress = false;

  AiGatewayImpl({
    List<AiProviderAdapter>? customAdapters,
    Map<String, AiProviderConfig>? initialConfigs,
    AiConsentPolicy? consentPolicy,
    http.Client? injectedClient,
    http.Client? client,
  })  : _consentPolicy = consentPolicy ?? const AiConsentPolicy(),
        _injectedClient = client ?? injectedClient {
    // Register default adapters
    final defaultAdapters = customAdapters ??
        [
          OpenAiChatCompletionsAdapter(),
          LocalRuntimeStubAdapter(),
        ];

    for (final adapter in defaultAdapters) {
      _adapters[adapter.id] = adapter;
    }

    // Register default configurations
    if (initialConfigs != null) {
      _configs.addAll(initialConfigs);
    } else {
      _configs['openai-compatible'] = const AiProviderConfig(
        id: 'openai-compatible',
        name: 'OpenAI-Compatible',
        baseUrl: 'https://api.openai.com/v1',
        defaultModel: 'gpt-4o-mini',
        isLocal: false,
      );
      _configs['local-runtime'] = const AiProviderConfig(
        id: 'local-runtime',
        name: 'Local Runtime Engine',
        baseUrl: 'http://localhost:11434/v1',
        defaultModel: 'llama-3.2-3b',
        isLocal: true,
      );
    }
  }

  @override
  List<AiProviderConfig> get availableProviders => _configs.values.toList();

  @override
  AiProviderConfig get activeConfig =>
      _configs[_activeProviderId] ?? _configs.values.first;

  @override
  void setActiveProvider(String providerId) {
    if (_configs.containsKey(providerId)) {
      _activeProviderId = providerId;
    }
  }

  @override
  void updateProviderConfig(AiProviderConfig config) {
    _configs[config.id] = config;
  }

  @override
  AiProviderCapability getCapability(String providerId) {
    final adapter = _adapters[providerId];
    if (adapter == null) {
      return const AiProviderCapability(
        isLocal: false,
        isAvailable: false,
        availabilityMessage: 'Unknown provider identifier.',
      );
    }
    return adapter.capability;
  }

  @override
  bool get isRequestInProgress => _isRequestInProgress;

  @override
  AiConsentPolicy get consentPolicy => _consentPolicy;

  @override
  Future<AiResponse> complete(
    AiRequest request, {
    bool userConsentGiven = false,
  }) async {
    final config = _configs[request.providerId] ?? activeConfig;
    final adapter = _adapters[config.id];

    if (adapter == null) {
      throw AiProviderException('No adapter registered for provider "${config.id}".');
    }

    // 1. Enforce Privacy Policy & Cloud Consent Boundary
    final decision = _consentPolicy.evaluate(
      request: request,
      config: config,
      userHasExplicitlyConfirmed: userConsentGiven,
    );

    if (decision.requiresUserConfirmation && !userConsentGiven) {
      throw UnconsentedExternalTransmissionException(
        message: 'Explicit consent required before transmitting data to ${config.name}.',
        disclosure: decision.disclosure,
      );
    }

    if (!decision.isPermitted && decision.rejectionReason != null) {
      throw AiProviderException(decision.rejectionReason!);
    }

    // 2. Dispatch to Provider Adapter
    _isRequestInProgress = true;
    _currentRunningAdapter = adapter;

    try {
      final response = await adapter.executeRequest(
        request: request,
        config: config,
        client: _injectedClient,
      );
      return response;
    } finally {
      _isRequestInProgress = false;
      _currentRunningAdapter = null;
    }
  }

  @override
  void cancelActiveRequest() {
    _currentRunningAdapter?.cancel();
    _isRequestInProgress = false;
    _currentRunningAdapter = null;
  }

  @override
  void cancelCurrentRequest() => cancelActiveRequest();
}
