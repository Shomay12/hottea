import 'dart:async';
import 'package:flutter/widgets.dart';
import 'hottea_shield_rules.dart';

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

/// Information describing a navigation or engine error.
class BrowserNavigationError {
  final Uri? failedUrl;
  final String message;
  final int? statusCode;
  final DateTime timestamp;

  BrowserNavigationError({
    this.failedUrl,
    required this.message,
    this.statusCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => 'BrowserNavigationError($failedUrl, $message, status: $statusCode)';
}

/// Abstract contract decoupling browser engine implementations from shared UI code.
///
/// Any platform integration (InAppWebView, WebView2, WKWebView, WebKitGTK)
/// must implement this interface. Shared UI components must ONLY interact with this contract.
abstract class BrowserEngine {
  /// Initializes the browser engine runtime.
  Future<void> initialize({Uri? initialUrl});

  /// Navigates to a specific URL.
  Future<void> loadUrl(Uri url);

  /// Navigates backwards in the session history.
  Future<void> goBack();

  /// Navigates forwards in the session history.
  Future<void> goForward();

  /// Reloads the current page.
  Future<void> reload();

  /// Stops loading the current page.
  Future<void> stopLoading();

  /// Clears any active navigation error.
  void clearError();

  /// Safely extracts text/DOM content from the active page for local research.
  /// Content extraction must be explicit and user-consented.
  Future<String?> extractPageContent();

  /// Evaluates JavaScript within the page context.
  Future<dynamic> evaluateJavascript(String script);

  /// Searches for [text] within the active page.
  Future<void> findInPage(String text, {bool forward = true});

  /// Clears active find-in-page highlights.
  Future<void> clearFindInPage();

  /// Zooms in by the platform increment.
  Future<void> zoomIn();

  /// Zooms out by the platform increment.
  Future<void> zoomOut();

  /// Resets page zoom to 100%.
  Future<void> resetZoom();

  /// Clears browser cache, web storage, and session cookies for this engine.
  Future<void> clearCache();

  /// Builds the widget to display inside Flutter.
  Widget buildWidget(BuildContext context);

  /// Disposes of the engine resources.
  Future<void> dispose();

  /// Streams for browser state observation.
  Stream<Uri?> get urlStream;
  Stream<String> get titleStream;
  Stream<double> get progressStream;
  Stream<bool> get isLoadingStream;
  Stream<bool> get canGoBackStream;
  Stream<bool> get canGoForwardStream;
  Stream<BrowserNavigationError?> get errorStream;

  /// Current synchronous state getters.
  Uri? get currentUrl;
  String get currentTitle;
  double get progress;
  bool get isLoading;
  bool get canGoBack;
  bool get canGoForward;
  BrowserNavigationError? get currentError;

  /// Active platform capabilities for this engine.
  BrowserPlatformCapabilities get capabilities;

  /// Whether this engine instance operates in isolated private/incognito mode.
  bool get isPrivate;

  /// Current zoom level (1.0 = 100%).
  double get zoomLevel;

  /// Active HotTea Shield privacy and redirection configuration.
  HotTeaShieldConfig get shieldConfig;

  /// Updates HotTea Shield configuration rules.
  void updateShieldConfig(HotTeaShieldConfig config);
}

/// A safe, self-contained reference/mock browser engine used for testing,
/// CI, and fallback rendering when platform-native runtimes are unavailable.
class MockBrowserEngine implements BrowserEngine {
  final _urlController = StreamController<Uri?>.broadcast();
  final _titleController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _canGoBackController = StreamController<bool>.broadcast();
  final _canGoForwardController = StreamController<bool>.broadcast();
  final _errorController = StreamController<BrowserNavigationError?>.broadcast();

  final List<Uri> _history = [];
  int _historyIndex = -1;

  Uri? _currentUrl;
  String _currentTitle = 'HotTea Home';
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  BrowserNavigationError? _currentError;
  bool _disposed = false;
  HotTeaShieldConfig _shieldConfig;

  @override
  final BrowserPlatformCapabilities capabilities;

  MockBrowserEngine({
    this.capabilities = const BrowserPlatformCapabilities(
      platformName: 'Mock/Test Engine',
      renderMode: BrowserRenderMode.inlineWidget,
      supportsDomExtraction: true,
      supportsScriptInjection: true,
      supportsCookieIsolation: true,
      supportsInlineDevTools: false,
      underlyingEngineName: 'HotTea In-Memory Simulation Runtime',
      license: 'Apache-2.0',
      notes: 'Safe local mock engine for testing and headless validation.',
    ),
    this.isPrivate = false,
    HotTeaShieldConfig? shieldConfig,
  }) : _shieldConfig = shieldConfig ?? const HotTeaShieldConfig();

  @override
  HotTeaShieldConfig get shieldConfig => _shieldConfig;

  @override
  void updateShieldConfig(HotTeaShieldConfig config) {
    _shieldConfig = config;
  }

  @override
  Future<void> initialize({Uri? initialUrl}) async {
    final start = initialUrl ?? Uri.parse('about:blank');
    await loadUrl(start);
  }

  @override
  Future<void> loadUrl(Uri url) async {
    clearError();
    _isLoading = true;
    _loadingController.add(true);
    _progressController.add(0.2);

    // Validate URL scheme
    if (url.scheme != 'http' && url.scheme != 'https' && url.scheme != 'about') {
      _isLoading = false;
      _loadingController.add(false);
      _progressController.add(1.0);
      _currentError = BrowserNavigationError(
        failedUrl: url,
        message: 'Unsupported scheme: ${url.scheme}. Only HTTP/HTTPS/about URLs are supported.',
      );
      _errorController.add(_currentError);
      return;
    }

    // Shield check: Block ad/tracker domains
    if (_shieldConfig.shieldEnabled && _shieldConfig.blockAdsAndTrackers && HotTeaShieldRules.isAdOrTracker(url)) {
      _isLoading = false;
      _loadingController.add(false);
      _progressController.add(1.0);
      _currentError = BrowserNavigationError(
        failedUrl: url,
        message: 'Blocked by HotTea Shield: Identified as advertising or tracker network.',
      );
      _errorController.add(_currentError);
      return;
    }

    _currentUrl = url;
    _urlController.add(url);
    _currentTitle = url.host.isEmpty ? url.toString() : url.host;
    _titleController.add(_currentTitle);

    // Append to history
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(url);
    _historyIndex = _history.length - 1;

    _updateHistoryState();

    _progressController.add(1.0);
    _isLoading = false;
    _loadingController.add(false);
  }

  void _updateHistoryState() {
    _canGoBack = _historyIndex > 0;
    _canGoForward = _historyIndex < _history.length - 1;
    _canGoBackController.add(_canGoBack);
    _canGoForwardController.add(_canGoForward);
  }

  @override
  Future<void> goBack() async {
    if (_canGoBack && _historyIndex > 0) {
      _historyIndex--;
      _currentUrl = _history[_historyIndex];
      _urlController.add(_currentUrl);
      _currentTitle = _currentUrl!.host.isEmpty ? _currentUrl.toString() : _currentUrl!.host;
      _titleController.add(_currentTitle);
      _updateHistoryState();
    }
  }

  @override
  Future<void> goForward() async {
    if (_canGoForward && _historyIndex < _history.length - 1) {
      _historyIndex++;
      _currentUrl = _history[_historyIndex];
      _urlController.add(_currentUrl);
      _currentTitle = _currentUrl!.host.isEmpty ? _currentUrl.toString() : _currentUrl!.host;
      _titleController.add(_currentTitle);
      _updateHistoryState();
    }
  }

  @override
  Future<void> reload() async {
    if (_currentUrl != null) {
      await loadUrl(_currentUrl!);
    }
  }

  @override
  Future<void> stopLoading() async {
    _isLoading = false;
    _loadingController.add(false);
  }

  @override
  Future<void> findInPage(String text, {bool forward = true}) async {}

  @override
  Future<void> clearFindInPage() async {}

  double _zoomLevel = 1.0;

  @override
  double get zoomLevel => _zoomLevel;

  @override
  Future<void> zoomIn() async {
    _zoomLevel = (_zoomLevel * 1.25).clamp(0.25, 5.0);
  }

  @override
  Future<void> zoomOut() async {
    _zoomLevel = (_zoomLevel * 0.8).clamp(0.25, 5.0);
  }

  @override
  Future<void> resetZoom() async {
    _zoomLevel = 1.0;
  }

  @override
  Future<void> clearCache() async {}

  @override
  final bool isPrivate;

  @override
  void clearError() {
    _currentError = null;
    _errorController.add(null);
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
    await _canGoBackController.close();
    await _canGoForwardController.close();
    await _errorController.close();
  }

  @override
  Stream<Uri?> get urlStream => _urlController.stream;

  @override
  Stream<String> get titleStream => _titleController.stream;

  @override
  Stream<double> get progressStream => _progressController.stream;

  @override
  Stream<bool> get isLoadingStream => _loadingController.stream;

  @override
  Stream<bool> get canGoBackStream => _canGoBackController.stream;

  @override
  Stream<bool> get canGoForwardStream => _canGoForwardController.stream;

  @override
  Stream<BrowserNavigationError?> get errorStream => _errorController.stream;

  @override
  Uri? get currentUrl => _currentUrl;

  @override
  String get currentTitle => _currentTitle;

  @override
  double get progress => 1.0;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get canGoBack => _canGoBack;

  @override
  bool get canGoForward => _canGoForward;

  @override
  BrowserNavigationError? get currentError => _currentError;
}
