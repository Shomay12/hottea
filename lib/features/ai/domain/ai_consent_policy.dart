import 'ai_models.dart';

/// Disclosure describing what information will leave the device.
class ExternalTransmissionDisclosure {
  final String providerName;
  final String endpoint;
  final String model;
  final AiExecutionTarget target;
  final bool isCloudService;
  final int promptCharacterCount;
  final List<ResearchContextReference> attachedResearchPassages;
  final bool includesWebpageContext;

  const ExternalTransmissionDisclosure({
    required this.providerName,
    required this.endpoint,
    this.model = '',
    this.target = AiExecutionTarget.externalProvider,
    required this.isCloudService,
    required this.promptCharacterCount,
    this.attachedResearchPassages = const [],
    this.includesWebpageContext = false,
  });

  List<ResearchContextReference> get attachedPassages => attachedResearchPassages;
  bool get hasResearchContext => attachedResearchPassages.isNotEmpty;

  bool get containsSensitiveContext =>
      attachedResearchPassages.isNotEmpty || includesWebpageContext;

  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('Provider: $providerName ($endpoint)');
    if (model.isNotEmpty) buffer.writeln('Model: $model');
    buffer.writeln('Estimated character size: $promptCharacterCount chars');
    if (attachedResearchPassages.isNotEmpty) {
      buffer.writeln('Attached Research Passages: ${attachedResearchPassages.length}');
      for (final r in attachedResearchPassages) {
        buffer.writeln(' • "${r.title}" (Source: ${r.sourceUrl ?? "none"})');
      }
    }
    if (includesWebpageContext) {
      buffer.writeln('Includes current webpage text extract.');
    }
    return buffer.toString().trim();
  }
}

/// Result of evaluating privacy policy on an AI request.
class AiConsentDecision {
  final bool isPermitted;
  final bool requiresUserConfirmation;
  final ExternalTransmissionDisclosure disclosure;
  final String? rejectionReason;

  const AiConsentDecision({
    required this.isPermitted,
    required this.requiresUserConfirmation,
    required this.disclosure,
    this.rejectionReason,
  });

  factory AiConsentDecision.allowedLocal({
    required String providerName,
    required int promptLength,
  }) {
    return AiConsentDecision(
      isPermitted: true,
      requiresUserConfirmation: false,
      disclosure: ExternalTransmissionDisclosure(
        providerName: providerName,
        endpoint: 'localhost',
        target: AiExecutionTarget.localRuntime,
        isCloudService: false,
        promptCharacterCount: promptLength,
      ),
    );
  }

  factory AiConsentDecision.requiresCloudConfirmation({
    required ExternalTransmissionDisclosure disclosure,
  }) {
    return AiConsentDecision(
      isPermitted: false,
      requiresUserConfirmation: true,
      disclosure: disclosure,
      rejectionReason: 'Request requires explicit confirmation before transmitting data to remote provider.',
    );
  }

  factory AiConsentDecision.rejected({
    required ExternalTransmissionDisclosure disclosure,
    required String reason,
  }) {
    return AiConsentDecision(
      isPermitted: false,
      requiresUserConfirmation: false,
      disclosure: disclosure,
      rejectionReason: reason,
    );
  }
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
  String toString() => 'UnconsentedExternalTransmissionException: $message';
}

/// Exception thrown when local inference fails and silent fallback is blocked.
class LocalInferenceFailureException implements Exception {
  final String reason;

  LocalInferenceFailureException(this.reason);

  String get message => reason;

  @override
  String toString() => 'LocalInferenceFailureException: $reason (Silent cloud fallback is prohibited by privacy policy).';
}

/// Evaluator enforcing HotTea's privacy invariants before any AI network call.
class AiConsentPolicy {
  const AiConsentPolicy();

  /// Creates a structured disclosure of what will be transmitted.
  ExternalTransmissionDisclosure createDisclosure({
    required AiProviderConfig config,
    required AiRequest request,
  }) {
    return ExternalTransmissionDisclosure(
      providerName: config.name,
      endpoint: config.baseUrl,
      model: request.model,
      target: config.isLocal ? AiExecutionTarget.localRuntime : AiExecutionTarget.externalProvider,
      isCloudService: !config.isLocal,
      promptCharacterCount: request.estimatedCharLength,
      attachedResearchPassages: request.researchContext,
      includesWebpageContext: false,
    );
  }

  /// Evaluates an [AiRequest] against privacy rules.
  AiConsentDecision evaluate({
    required AiRequest request,
    required AiProviderConfig config,
    required bool userHasExplicitlyConfirmed,
  }) {
    // 1. Local Runtime: If provider is strictly local, zero external transmission occurs.
    if (config.isLocal) {
      return AiConsentDecision.allowedLocal(
        providerName: config.name,
        promptLength: request.estimatedCharLength,
      );
    }

    // 2. Remote Cloud Provider: Build complete transmission disclosure
    final disclosure = createDisclosure(config: config, request: request);

    // If user has not confirmed transmission to the external provider:
    if (!userHasExplicitlyConfirmed) {
      return AiConsentDecision.requiresCloudConfirmation(disclosure: disclosure);
    }

    // If user explicitly confirmed, transmission is permitted
    return AiConsentDecision(
      isPermitted: true,
      requiresUserConfirmation: false,
      disclosure: disclosure,
    );
  }
}
