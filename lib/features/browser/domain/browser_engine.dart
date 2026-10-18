import 'dart:async';
import 'package:flutter/widgets.dart';

/// Defines the operational rendering mode of the browser engine on a given platform.
enum BrowserRenderMode {
  /// Renders as an inline widget directly inside the Flutter widget hierarchy.
  inlineWidget,

  /// Renders via off-screen texture streaming (e.g. CEF / Chromium texture).
  textureStream,

  /// Spawns a secondary native platform window managed alongside Flutter.
  nativeWindow,

  /// Lightweight headless or simulated engine (used in tests and unsupported environments).
  headless,
}

/// Explicit capabilities and limitations of the browser engine on the active platform.
class BrowserPlatformCapabilities {
  final String platformName;
  final BrowserRenderMode renderMode;
  final bool supportsDomExtraction;
  final bool supportsScriptInjection;
  final bool supportsCookieIsolation;
  final bool supportsInlineDevTools;
  final String underlyingEngineName;
  final String license;
  final String notes;

  const BrowserPlatformCapabilities({
    required this.platformName,
    required this.renderMode,
    required this.supportsDomExtraction,
    required this.supportsScriptInjection,
    required this.supportsCookieIsolation,
    required this.supportsInlineDevTools,
    required this.underlyingEngineName,
    required this.license,
    required this.notes,
  });
}

/// Abstract contract decoupling browser engine implementations from shared UI code.
///
/// Any platform integration (WebView2, WKWebView, Android WebView, CEF, WebKitGTK)
/// must implement this interface. Shared UI components must ONLY interact with this contract.
abstract class BrowserEngine {
  /// Initializes the browser engine runtime.
  Future<void> initialize();

  /// Navigates to a specific URL.
  Future<void> loadUrl(Uri url);

  /// Navigates backwards in the session history.
  Future<void> goBack();

  /// Navigates forwards in the session history.
  Future<void> goForward();

  /// Reloads the current page.
  Future<void> reload();

  /// Safely extracts text/DOM content from the active page for local research.
  /// Content extraction must be explicit and user-consented.
  Future<String?> extractPageContent();

  /// Evaluates JavaScript within the page context.
  Future<dynamic> evaluateJavascript(String script);

  /// Builds the widget to display inside Flutter (or a placeholder if [renderMode] is nativeWindow).
  Widget buildWidget(BuildContext context);

  /// Disposes of the engine resources.
  Future<void> dispose();

  /// Streams for browser state observation.
  Stream<Uri?> get urlStream;
  Stream<String> get titleStream;
  Stream<double> get progressStream;
  Stream<bool> get isLoadingStream;

  /// Active platform capabilities for this engine.
  BrowserPlatformCapabilities get capabilities;
}

/// A safe, self-contained reference/mock browser engine used for testing,
/// CI, and fallback rendering when platform-native runtimes are unavailable.
class MockBrowserEngine implements BrowserEngine {
  final _urlController = StreamController<Uri?>.broadcast();
  final _titleController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();

  Uri? _currentUrl;
  String _currentTitle = 'HotTea Home';
  bool _disposed = false;

  @override
  final BrowserPlatformCapabilities capabilities;

  MockBrowserEngine({
    this.capabilities = const BrowserPlatformCapabilities(
      platformName: 'Mock/Fallback Engine',
      renderMode: BrowserRenderMode.inlineWidget,
      supportsDomExtraction: true,
      supportsScriptInjection: true,
      supportsCookieIsolation: true,
      supportsInlineDevTools: false,
      underlyingEngineName: 'HotTea Lightweight Mock Runtime',
      license: 'Apache-2.0',
      notes: 'Safe local mock engine for testing and headless validation.',
    ),
  });

  @override
  Future<void> initialize() async {
    _currentUrl = Uri.parse('about:blank');
    _urlController.add(_currentUrl);
    _titleController.add(_currentTitle);
    _progressController.add(1.0);
    _loadingController.add(false);
  }

  @override
  Future<void> loadUrl(Uri url) async {
    _loadingController.add(true);
    _progressController.add(0.2);
    _currentUrl = url;
    _urlController.add(url);
    _currentTitle = url.host.isEmpty ? url.toString() : url.host;
    _titleController.add(_currentTitle);
    _progressController.add(1.0);
    _loadingController.add(false);
  }

  @override
  Future<void> goBack() async {}

  @override
  Future<void> goForward() async {}

  @override
  Future<void> reload() async {
    if (_currentUrl != null) {
      await loadUrl(_currentUrl!);
    }
  }

  @override
  Future<String?> extractPageContent() async {
    return 'Content extracted from ${_currentUrl?.toString() ?? "empty page"}';
  }

  @override
  Future<dynamic> evaluateJavascript(String script) async {
    return null;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return Container();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _urlController.close();
    await _titleController.close();
    await _progressController.close();
    await _loadingController.close();
  }

  @override
  Stream<Uri?> get urlStream => _urlController.stream;

  @override
  Stream<String> get titleStream => _titleController.stream;

  @override
  Stream<double> get progressStream => _progressController.stream;

  @override
  Stream<bool> get isLoadingStream => _loadingController.stream;
}
