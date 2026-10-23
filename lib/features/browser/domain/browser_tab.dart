import 'dart:async';
import 'browser_engine.dart';
import 'hottea_shield_rules.dart';

/// Represents a single browser tab within the HotTea research workspace.
///
/// Invariant: Every tab encapsulates an independent [BrowserEngine] instance,
/// tracking its own URL history, navigation state, and title.
class BrowserTab {
  final String id;
  final BrowserEngine engine;
  final DateTime createdAt;

  StreamSubscription<Uri?>? _urlSub;
  StreamSubscription<String>? _titleSub;
  StreamSubscription<double>? _progressSub;
  StreamSubscription<bool>? _loadingSub;
  StreamSubscription<bool>? _canGoBackSub;
  StreamSubscription<bool>? _canGoForwardSub;
  StreamSubscription<BrowserNavigationError?>? _errorSub;

  final void Function()? onStateChanged;

  BrowserTab({
    required this.id,
    required this.engine,
    Uri? initialUrl,
    this.onStateChanged,
  }) : createdAt = DateTime.now() {
    _subscribe();
  }

  void _subscribe() {
    _urlSub = engine.urlStream.listen((_) => onStateChanged?.call());
    _titleSub = engine.titleStream.listen((_) => onStateChanged?.call());
    _progressSub = engine.progressStream.listen((_) => onStateChanged?.call());
    _loadingSub = engine.isLoadingStream.listen((_) => onStateChanged?.call());
    _canGoBackSub = engine.canGoBackStream.listen((_) => onStateChanged?.call());
    _canGoForwardSub = engine.canGoForwardStream.listen((_) => onStateChanged?.call());
    _errorSub = engine.errorStream.listen((_) => onStateChanged?.call());
  }

  Uri? get currentUrl => engine.currentUrl;
  String get currentTitle => engine.currentTitle;
  double get progress => engine.progress;
  bool get isLoading => engine.isLoading;
  bool get canGoBack => engine.canGoBack;
  bool get canGoForward => engine.canGoForward;
  BrowserNavigationError? get error => engine.currentError;
  bool get isPrivate => engine.isPrivate;
  double get zoomLevel => engine.zoomLevel;
  HotTeaShieldConfig get shieldConfig => engine.shieldConfig;

  void updateShieldConfig(HotTeaShieldConfig config) => engine.updateShieldConfig(config);

  Future<void> loadUrl(Uri url) => engine.loadUrl(url);
  Future<void> goBack() => engine.goBack();
  Future<void> goForward() => engine.goForward();
  Future<void> reload() => engine.reload();
  Future<void> stopLoading() => engine.stopLoading();
  void clearError() => engine.clearError();

  Future<void> findInPage(String text, {bool forward = true}) => engine.findInPage(text, forward: forward);
  Future<void> clearFindInPage() => engine.clearFindInPage();
  Future<void> zoomIn() => engine.zoomIn();
  Future<void> zoomOut() => engine.zoomOut();
  Future<void> resetZoom() => engine.resetZoom();
  Future<void> clearCache() => engine.clearCache();

  Future<void> dispose() async {
    await _urlSub?.cancel();
    await _titleSub?.cancel();
    await _progressSub?.cancel();
    await _loadingSub?.cancel();
    await _canGoBackSub?.cancel();
    await _canGoForwardSub?.cancel();
    await _errorSub?.cancel();
    await engine.dispose();
  }
}
