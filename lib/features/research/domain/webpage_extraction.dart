import 'source_entity.dart';

/// Status of a webpage content extraction attempt.
enum WebpageExtractionStatus {
  /// Extraction completed successfully with readable content.
  success,

  /// Page was empty or lacked readable main content.
  emptyContent,

  /// Script injection or DOM access was restricted (e.g. cross-origin iframe or browser security policy).
  scriptRestricted,

  /// URL was invalid or page had not finished initial loading.
  invalidTarget,

  /// An unhandled platform error occurred during DOM parsing.
  failed,
}

/// Structured outcome of an on-device webpage extraction.
class WebpageExtractionResult {
  final WebpageExtractionStatus status;
  final SourceEntity? source;
  final String? activeSelection;
  final String? errorMessage;
  final DateTime timestamp;

  WebpageExtractionResult({
    required this.status,
    this.source,
    this.activeSelection,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isSuccess => status == WebpageExtractionStatus.success;

  factory WebpageExtractionResult.success({
    required SourceEntity source,
    String? activeSelection,
  }) {
    return WebpageExtractionResult(
      status: WebpageExtractionStatus.success,
      source: source,
      activeSelection: activeSelection?.trim().isNotEmpty == true ? activeSelection!.trim() : null,
    );
  }

  factory WebpageExtractionResult.empty({
    required Uri url,
    required String title,
    String? message,
  }) {
    return WebpageExtractionResult(
      status: WebpageExtractionStatus.emptyContent,
      source: SourceEntity(url: url, title: title),
      errorMessage: message ?? 'No readable main body text found on this page.',
    );
  }

  factory WebpageExtractionResult.restricted({
    required Uri url,
    required String title,
    String? message,
  }) {
    return WebpageExtractionResult(
      status: WebpageExtractionStatus.scriptRestricted,
      source: SourceEntity(url: url, title: title),
      errorMessage: message ?? 'DOM extraction was blocked by page or cross-origin restrictions.',
    );
  }

  factory WebpageExtractionResult.invalidTarget(String reason) {
    return WebpageExtractionResult(
      status: WebpageExtractionStatus.invalidTarget,
      errorMessage: reason,
    );
  }

  factory WebpageExtractionResult.failed({
    required String error,
    Uri? url,
    String? title,
  }) {
    return WebpageExtractionResult(
      status: WebpageExtractionStatus.failed,
      source: url != null ? SourceEntity(url: url, title: title ?? 'Untitled') : null,
      errorMessage: error,
    );
  }
}
