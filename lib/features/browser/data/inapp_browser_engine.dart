import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../domain/browser_engine.dart';

/// Real browser engine integration backed by [InAppWebView].
///
/// Supported natively on:
/// - Web (rendered via HTML5 iframe)
/// - macOS (rendered via WKWebView / AppKitView)
/// - iOS (rendered via WKWebView / UiKitView)
/// - Android (rendered via Android System WebView)
/// - Windows (rendered via Microsoft Edge WebView2)
class InAppBrowserEngine implements BrowserEngine {
  InAppWebViewController? _webViewController;

  final _urlController = StreamController<Uri?>.broadcast();
  final _titleController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _canGoBackController = StreamController<bool>.broadcast();
  final _canGoForwardController = StreamController<bool>.broadcast();
  final _errorController = StreamController<BrowserNavigationError?>.broadcast();

  Uri? _currentUrl;
  String _currentTitle = '';
  double _progress = 0.0;
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  BrowserNavigationError? _currentError;
  bool _disposed = false;

  final Uri _initialUrl;

  @override
  final BrowserPlatformCapabilities capabilities;

  InAppBrowserEngine({
    Uri? initialUrl,
    BrowserPlatformCapabilities? customCapabilities,
  })  : _initialUrl = initialUrl ?? Uri.parse('https://docs.flutter.dev'),
        capabilities = customCapabilities ?? _resolvePlatformCapabilities() {
    _currentUrl = _initialUrl;
  }

  static BrowserPlatformCapabilities _resolvePlatformCapabilities() {
    final String platformName = kIsWeb ? 'Web (Chrome/Browser Iframe)' : defaultTargetPlatform.name;
    final String engineName = kIsWeb
        ? 'HTML5 Iframe Container'
        : (defaultTargetPlatform == TargetPlatform.windows
            ? 'Microsoft Edge WebView2'
            : (defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS
                ? 'Apple WebKit (WKWebView)'
                : 'Android Chromium WebView'));

    return BrowserPlatformCapabilities(
      platformName: platformName,
      renderMode: BrowserRenderMode.inlineWidget,
      supportsDomExtraction: !kIsWeb, // Cross-origin iframe DOM extraction is restricted on web
      supportsScriptInjection: !kIsWeb,
      supportsCookieIsolation: true,
      supportsInlineDevTools: false,
      underlyingEngineName: engineName,
      license: 'Apache-2.0',
      notes: kIsWeb
          ? 'Web preview: Subject to browser cross-origin and X-Frame-Options policies.'
          : 'Native platform embedding with full DOM extraction capabilities.',
    );
  }

  @override
  Future<void> initialize({Uri? initialUrl}) async {
    final urlToLoad = initialUrl ?? _initialUrl;
    _currentUrl = urlToLoad;
    _urlController.add(_currentUrl);
    _titleController.add(_currentUrl?.host ?? 'HotTea');
    _progressController.add(0.0);
    _loadingController.add(false);
  }

  @override
  Future<void> loadUrl(Uri url) async {
    clearError();

    // Scheme validation
    if (url.scheme != 'http' && url.scheme != 'https' && url.scheme != 'about') {
      _currentError = BrowserNavigationError(
        failedUrl: url,
        message: 'Unsupported protocol scheme "${url.scheme}". HotTea requires http:// or https://.',
      );
      _errorController.add(_currentError);
      return;
    }

    _currentUrl = url;
    _urlController.add(url);
    _isLoading = true;
    _loadingController.add(true);
    _progressController.add(0.1);

    try {
      if (_webViewController != null) {
        await _webViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri(url.toString())),
        );
      }
    } catch (e) {
      _currentError = BrowserNavigationError(
        failedUrl: url,
        message: 'Failed to initiate navigation: $e',
      );
      _errorController.add(_currentError);
      _isLoading = false;
      _loadingController.add(false);
    }
  }

  @override
  Future<void> goBack() async {
    if (_webViewController != null) {
      final canBack = await _webViewController!.canGoBack();
      if (canBack) {
        await _webViewController!.goBack();
      }
    }
  }

  @override
  Future<void> goForward() async {
    if (_webViewController != null) {
      final canForward = await _webViewController!.canGoForward();
      if (canForward) {
        await _webViewController!.goForward();
      }
    }
  }

  @override
  Future<void> reload() async {
    clearError();
    if (_webViewController != null) {
      await _webViewController!.reload();
    } else if (_currentUrl != null) {
      await loadUrl(_currentUrl!);
    }
  }

  @override
  void clearError() {
    _currentError = null;
    _errorController.add(null);
  }

  @override
  Future<String?> extractPageContent() async {
    if (_webViewController == null) return null;
    try {
      final html = await _webViewController!.getHtml();
      return html;
    } catch (e) {
      return 'DOM extraction unavailable: $e';
    }
  }

  @override
  Future<dynamic> evaluateJavascript(String script) async {
    if (_webViewController == null) return null;
    try {
      return await _webViewController!.evaluateJavascript(source: script);
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateHistoryNavigationState() async {
    if (_webViewController != null) {
      try {
        final back = await _webViewController!.canGoBack();
        final forward = await _webViewController!.canGoForward();
        _canGoBack = back;
        _canGoForward = forward;
        _canGoBackController.add(back);
        _canGoForwardController.add(forward);
      } catch (_) {}
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    return InAppWebView(
      key: ValueKey('inapp_webview_${_initialUrl.toString()}'),
      initialUrlRequest: URLRequest(
        url: WebUri(_currentUrl?.toString() ?? _initialUrl.toString()),
      ),
      initialSettings: InAppWebViewSettings(
        isInspectable: false,
        javaScriptEnabled: true,
        supportZoom: true,
        transparentBackground: false,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;
      },
      onLoadStart: (controller, url) {
        clearError();
        _isLoading = true;
        _loadingController.add(true);
        if (url != null) {
          _currentUrl = url.uriValue;
          _urlController.add(_currentUrl);
        }
      },
      onProgressChanged: (controller, progress) {
        _progress = progress / 100.0;
        _progressController.add(_progress);
      },
      onLoadStop: (controller, url) async {
        _isLoading = false;
        _loadingController.add(false);
        _progress = 1.0;
        _progressController.add(1.0);
        if (url != null) {
          _currentUrl = url.uriValue;
          _urlController.add(_currentUrl);
        }
        await _updateHistoryNavigationState();
      },
      onTitleChanged: (controller, title) {
        if (title != null && title.isNotEmpty) {
          _currentTitle = title;
          _titleController.add(title);
        }
      },
      onUpdateVisitedHistory: (controller, url, isReload) async {
        if (url != null) {
          _currentUrl = url.uriValue;
          _urlController.add(_currentUrl);
        }
        await _updateHistoryNavigationState();
      },
      onReceivedError: (controller, request, error) {
        _isLoading = false;
        _loadingController.add(false);
        _currentError = BrowserNavigationError(
          failedUrl: request.url.uriValue,
          message: error.description,
          statusCode: null,
        );
        _errorController.add(_currentError);
      },
      onReceivedHttpError: (controller, request, response) {
        final code = response.statusCode ?? 0;
        if (code >= 400) {
          _currentError = BrowserNavigationError(
            failedUrl: request.url.uriValue,
            message: 'HTTP Error $code: ${response.reasonPhrase ?? "Request failed"}',
            statusCode: code,
          );
          _errorController.add(_currentError);
        }
      },
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _webViewController = null;
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
  double get progress => _progress;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get canGoBack => _canGoBack;

  @override
  bool get canGoForward => _canGoForward;

  @override
  BrowserNavigationError? get currentError => _currentError;
}
