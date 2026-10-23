import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../domain/browser_engine.dart';
import '../domain/hottea_shield_rules.dart';
import 'download_manager.dart';

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
  Uri? _pendingUrl;
  String _currentTitle = '';
  double _progress = 0.0;
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  BrowserNavigationError? _currentError;
  bool _disposed = false;
  HotTeaShieldConfig _shieldConfig;

  final Uri _initialUrl;

  @override
  final bool isPrivate;

  @override
  final BrowserPlatformCapabilities capabilities;

  @override
  HotTeaShieldConfig get shieldConfig => _shieldConfig;

  @override
  void updateShieldConfig(HotTeaShieldConfig config) {
    _shieldConfig = config;
    if (_webViewController != null) {
      _webViewController?.setSettings(
        settings: InAppWebViewSettings(
          thirdPartyCookiesEnabled: !config.blockThirdPartyCookies,
          contentBlockers: HotTeaShieldRules.getContentBlockers(config: config),
        ),
      );
    }
  }

  InAppBrowserEngine({
    Uri? initialUrl,
    BrowserPlatformCapabilities? customCapabilities,
    this.isPrivate = false,
    HotTeaShieldConfig? shieldConfig,
  })  : _initialUrl = initialUrl ?? Uri.parse('about:blank'),
        capabilities = customCapabilities ?? _resolvePlatformCapabilities(),
        _shieldConfig = shieldConfig ?? const HotTeaShieldConfig() {
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

    if (_webViewController != null) {
      _pendingUrl = null;
      try {
        await _webViewController!.loadUrl(
          urlRequest: URLRequest(url: WebUri.uri(url)),
        );
      } catch (e) {
        _currentError = BrowserNavigationError(
          failedUrl: url,
          message: 'Failed to initiate navigation: $e',
        );
        _errorController.add(_currentError);
        _isLoading = false;
        _loadingController.add(false);
      }
    } else {
      _pendingUrl = url;
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
  Future<void> stopLoading() async {
    _isLoading = false;
    _loadingController.add(false);
    if (_webViewController != null) {
      await _webViewController!.stopLoading();
    }
  }

  @override
  Future<void> findInPage(String text, {bool forward = true}) async {
    if (_webViewController != null && text.trim().isNotEmpty) {
      final sanitized = text.replaceAll('"', '\\"');
      final backwards = !forward;
      await _webViewController!.evaluateJavascript(
        source: 'window.find("$sanitized", false, $backwards, true, false, true, false);',
      );
    }
  }

  @override
  Future<void> clearFindInPage() async {
    if (_webViewController != null) {
      await _webViewController!.evaluateJavascript(
        source: 'if (window.getSelection) { window.getSelection().removeAllRanges(); }',
      );
    }
  }

  double _zoomLevel = 1.0;

  @override
  double get zoomLevel => _zoomLevel;

  @override
  Future<void> zoomIn() async {
    _zoomLevel = (_zoomLevel * 1.25).clamp(0.25, 5.0);
    if (_webViewController != null) {
      await _webViewController!.zoomBy(zoomFactor: 1.25);
    }
  }

  @override
  Future<void> zoomOut() async {
    _zoomLevel = (_zoomLevel * 0.8).clamp(0.25, 5.0);
    if (_webViewController != null) {
      await _webViewController!.zoomBy(zoomFactor: 0.8);
    }
  }

  @override
  Future<void> resetZoom() async {
    _zoomLevel = 1.0;
    if (_webViewController != null) {
      await _webViewController!.zoomBy(zoomFactor: 1.0);
    }
  }

  @override
  Future<void> clearCache() async {
    if (_webViewController != null) {
      await InAppWebViewController.clearAllCache();
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
      key: ObjectKey(this),
      initialUrlRequest: URLRequest(
        url: WebUri.uri(_currentUrl ?? _initialUrl),
      ),
      initialSettings: InAppWebViewSettings(
        isInspectable: false,
        javaScriptEnabled: true,
        supportZoom: true,
        transparentBackground: false,
        incognito: isPrivate,
        cacheEnabled: !isPrivate,
        clearCache: isPrivate,
        clearSessionCache: isPrivate,
        useOnDownloadStart: true,
        allowsBackForwardNavigationGestures: true,
        allowsInlineMediaPlayback: true,
        isFraudulentWebsiteWarningEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        sharedCookiesEnabled: true,
        // HotTea Shield & Redirection Protections
        useShouldOverrideUrlLoading: true,
        javaScriptCanOpenWindowsAutomatically: false,
        supportMultipleWindows: true,
        thirdPartyCookiesEnabled: !_shieldConfig.blockThirdPartyCookies,
        contentBlockers: HotTeaShieldRules.getContentBlockers(config: _shieldConfig),
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        HotTeaShieldRules.getShieldUserScript(config: _shieldConfig),
      ]),
      onCreateWindow: (controller, createWindowAction) async {
        final request = createWindowAction.request;
        final targetUrl = request.url?.uriValue;
        if (targetUrl != null) {
          // Block known malicious ad or tracking popups
          if (_shieldConfig.shieldEnabled &&
              _shieldConfig.blockAdsAndTrackers &&
              HotTeaShieldRules.isAdOrTracker(targetUrl)) {
            return true; // Filtered & suppressed
          }
          // Same-tab redirection: load destination in the active tab without spawning external windows or losing place
          if (_shieldConfig.keepNavigationsInSameTab) {
            await controller.loadUrl(urlRequest: request);
            return true;
          }
        }
        return true;
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final uri = navigationAction.request.url?.uriValue;
        if (uri == null) return NavigationActionPolicy.ALLOW;

        final scheme = uri.scheme.toLowerCase();
        // Block external non-web protocol hijacks commonly triggered by ad networks
        if (scheme != 'http' && scheme != 'https' && scheme != 'about' && scheme != 'data' && scheme != 'javascript') {
          return NavigationActionPolicy.CANCEL;
        }

        // Block ad network redirects attempting to hijack the active tab
        if (_shieldConfig.shieldEnabled &&
            _shieldConfig.blockAdsAndTrackers &&
            HotTeaShieldRules.isAdOrTracker(uri)) {
          return NavigationActionPolicy.CANCEL;
        }

        return NavigationActionPolicy.ALLOW;
      },
      onWebViewCreated: (controller) async {
        _webViewController = controller;
        if (_pendingUrl != null) {
          final target = _pendingUrl!;
          _pendingUrl = null;
          try {
            await controller.loadUrl(
              urlRequest: URLRequest(url: WebUri.uri(target)),
            );
          } catch (e) {
            _currentError = BrowserNavigationError(
              failedUrl: target,
              message: 'Failed to load pending URL: $e',
            );
            _errorController.add(_currentError);
          }
        }
      },
      onDownloadStartRequest: (controller, downloadStartRequest) {
        DownloadManager.instance.handleDownloadRequest(
          url: downloadStartRequest.url.uriValue,
          suggestedFilename: downloadStartRequest.suggestedFilename,
          contentLength: downloadStartRequest.contentLength,
          mimeType: downloadStartRequest.mimeType,
        );
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
        final isMainFrame = request.isForMainFrame == true;
        if (!isMainFrame) {
          // Subresource (tracker, ad, image, iframe, script) failure must NEVER break the page
          return;
        }

        final desc = error.description.toLowerCase();
        // Skip user or engine cancelled navigation errors (redirects, new URL entered, WebKit -999, policy 102)
        if (error.type == WebResourceErrorType.CANCELLED ||
            desc.contains('cancel') ||
            desc.contains('-999') ||
            desc.contains('102') ||
            desc.contains('frameloadinterruptedbypolicychange')) {
          return;
        }

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
        // Intentionally no-op:
        // HTTP status codes (4xx and 5xx) return valid HTML bodies from web servers.
        // For instance, Cloudflare Turnstile challenge pages return HTTP 403 Forbidden with
        // an HTML payload containing the interactive verification widget. Similarly, custom
        // 404 or 500 pages often provide navigation or login options.
        // Real browsers render the response page directly. Replacing the entire WebView
        // with an error screen on HTTP 4xx/5xx blocks challenge completion and prevents
        // users from accessing sites.
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
