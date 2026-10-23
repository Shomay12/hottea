/// Foundational privacy constraints that HotTea guarantees by contract.
class HotTeaPrivacyPolicy {
  HotTeaPrivacyPolicy._();

  /// Core Requirement 10: Telemetry is strictly disabled by default.
  static const bool defaultTelemetryEnabled = false;

  /// Core Requirement 2: Local inference MUST NOT silently fall back to cloud inference.
  static const bool allowSilentCloudFallback = false;

  /// Core Requirement 3: Users MUST be explicitly notified and must consent before
  /// prompts or page contents are sent to external providers.
  static const bool requireExplicitCloudConsent = true;

  /// Core Requirement 1: Provider-independent; no hardcoded reliance on a single vendor.
  static const String appName = 'HotTea';
  static const String appTagline = 'Local-first, privacy-focused AI browser & research workspace';
  static const String projectVersion = '1.1.0';
}
