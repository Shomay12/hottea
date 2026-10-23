import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/core/persistence/in_memory_persistence_repository.dart';
import 'package:hottea/main.dart';
import 'package:hottea/features/browser/domain/address_bar_parser.dart';
import 'package:hottea/features/browser/domain/browser_engine.dart';
import 'package:hottea/features/browser/domain/browser_tab.dart';
import 'package:hottea/features/browser/domain/search_engine.dart';
import 'package:hottea/features/browser/domain/hottea_shield_rules.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Search Engine Abstraction & Registry Tests', () {
    test('Default search engine is Google', () {
      expect(SearchEngineRegistry.defaultEngine, equals(SearchEngineRegistry.google));
      expect(SearchEngineRegistry.defaultEngine.id, equals('google'));
      expect(SearchEngineRegistry.defaultEngine.name, equals('Google'));
    });

    test('Registry contains all standard providers', () {
      final engines = SearchEngineRegistry.availableEngines;
      final ids = engines.map((e) => e.id).toList();

      expect(ids, containsAll(['google', 'duckduckgo', 'bing', 'brave']));
    });

    test('Search URL generation for Google', () {
      final uri = SearchEngineRegistry.google.buildSearchUri('flutter state management');
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('www.google.com'));
      expect(uri.path, equals('/search'));
      expect(uri.queryParameters['q'], equals('flutter state management'));
      expect(uri.toString(), equals('https://www.google.com/search?q=flutter+state+management'));
    });

    test('Search URL generation for DuckDuckGo', () {
      final uri = SearchEngineRegistry.duckDuckGo.buildSearchUri('privacy browser');
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('duckduckgo.com'));
      expect(uri.path, equals('/'));
      expect(uri.queryParameters['q'], equals('privacy browser'));
      expect(uri.toString(), equals('https://duckduckgo.com/?q=privacy+browser'));
    });

    test('Search URL generation for Bing', () {
      final uri = SearchEngineRegistry.bing.buildSearchUri('dart programming');
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('www.bing.com'));
      expect(uri.path, equals('/search'));
      expect(uri.queryParameters['q'], equals('dart programming'));
      expect(uri.toString(), equals('https://www.bing.com/search?q=dart+programming'));
    });

    test('Search URL generation for Brave Search', () {
      final uri = SearchEngineRegistry.brave.buildSearchUri('local AI models');
      expect(uri.scheme, equals('https'));
      expect(uri.host, equals('search.brave.com'));
      expect(uri.path, equals('/search'));
      expect(uri.queryParameters['q'], equals('local AI models'));
      expect(uri.toString(), equals('https://search.brave.com/search?q=local+AI+models'));
    });

    test('Search URL handles spaces, Unicode, punctuation, and question marks safely', () {
      const complexQuery = 'What is "HotTea"? 日本語 & math: 2+2=4?';
      final uri = SearchEngineRegistry.google.buildSearchUri(complexQuery);

      expect(uri.queryParameters['q'], equals(complexQuery));
      // Uri encoding ensures query parameters are percent-encoded
      expect(uri.toString(), contains('q=What+is+%22HotTea%22%3F+%E6%97%A5%E6%9C%AC%E8%AA%9E+%26+math%3A+2%2B2%3D4%3F'));
    });

    test('Provider lookup falls back safely to default without silent switching', () {
      expect(SearchEngineRegistry.getById('duckduckgo'), equals(SearchEngineRegistry.duckDuckGo));
      expect(SearchEngineRegistry.getById('bing'), equals(SearchEngineRegistry.bing));
      expect(SearchEngineRegistry.getById('brave'), equals(SearchEngineRegistry.brave));

      // Unknown ID falls back to default Google
      expect(SearchEngineRegistry.getById('unknown_engine'), equals(SearchEngineRegistry.google));
      expect(SearchEngineRegistry.getById(null), equals(SearchEngineRegistry.google));
    });
  });

  group('Address Bar Input Classification Tests', () {
    test('Explicit HTTP and HTTPS URLs are classified as directNavigation', () {
      final r1 = AddressBarParser.parse('https://flutter.dev');
      expect(r1.type, equals(AddressBarInputType.directNavigation));
      expect(r1.targetUri, equals(Uri.parse('https://flutter.dev')));

      final r2 = AddressBarParser.parse('http://example.com/path?arg=val#section');
      expect(r2.type, equals(AddressBarInputType.directNavigation));
      expect(r2.targetUri, equals(Uri.parse('http://example.com/path?arg=val#section')));

      final r3 = AddressBarParser.parse('https://sub.domain.co.uk:8080/app');
      expect(r3.type, equals(AddressBarInputType.directNavigation));
      expect(r3.targetUri, equals(Uri.parse('https://sub.domain.co.uk:8080/app')));
    });

    test('Bare domains are normalized to HTTPS directNavigation', () {
      final r1 = AddressBarParser.parse('youtube.com');
      expect(r1.type, equals(AddressBarInputType.directNavigation));
      expect(r1.targetUri, equals(Uri.parse('https://youtube.com')));

      final r2 = AddressBarParser.parse('docs.flutter.dev/get-started');
      expect(r2.type, equals(AddressBarInputType.directNavigation));
      expect(r2.targetUri, equals(Uri.parse('https://docs.flutter.dev/get-started')));

      final r3 = AddressBarParser.parse('example.org:3000/api');
      expect(r3.type, equals(AddressBarInputType.directNavigation));
      expect(r3.targetUri, equals(Uri.parse('https://example.org:3000/api')));
    });

    test('Localhost and IPv4 addresses navigate directly', () {
      final r1 = AddressBarParser.parse('localhost:3000');
      expect(r1.type, equals(AddressBarInputType.directNavigation));
      expect(r1.targetUri, equals(Uri.parse('http://localhost:3000')));

      final r2 = AddressBarParser.parse('127.0.0.1:8080');
      expect(r2.type, equals(AddressBarInputType.directNavigation));
      expect(r2.targetUri, equals(Uri.parse('http://127.0.0.1:8080')));
    });

    test('Ordinary text containing a period is classified as search', () {
      // Natural language phrases with periods
      final r1 = AddressBarParser.parse('Dr. Smith');
      expect(r1.type, equals(AddressBarInputType.search));
      expect(r1.searchQuery, equals('Dr. Smith'));
      expect(r1.targetUri?.host, equals('www.google.com'));

      final r2 = AddressBarParser.parse('version 1.0.0 released');
      expect(r2.type, equals(AddressBarInputType.search));
      expect(r2.searchQuery, equals('version 1.0.0 released'));

      final r3 = AddressBarParser.parse('what is flutter.dev?');
      expect(r3.type, equals(AddressBarInputType.search));
      expect(r3.searchQuery, equals('what is flutter.dev?'));

      // Non-domain abbreviations with dots
      final r4 = AddressBarParser.parse('e.g.');
      expect(r4.type, equals(AddressBarInputType.search));

      final r5 = AddressBarParser.parse('test..item');
      expect(r5.type, equals(AddressBarInputType.search));
    });

    test('Empty input is classified as empty', () {
      expect(AddressBarParser.parse('').type, equals(AddressBarInputType.empty));
      expect(AddressBarParser.parse('   ').type, equals(AddressBarInputType.empty));
      expect(AddressBarParser.parse('\t\n').type, equals(AddressBarInputType.empty));
    });

    test('Unsupported or dangerous URL schemes are rejected with error', () {
      final r1 = AddressBarParser.parse('javascript:alert(1)');
      expect(r1.type, equals(AddressBarInputType.unsupportedScheme));
      expect(r1.errorMessage, contains('Blocked unsupported scheme "javascript:"'));

      final r2 = AddressBarParser.parse('file:///etc/passwd');
      expect(r2.type, equals(AddressBarInputType.unsupportedScheme));
      expect(r2.errorMessage, contains('Blocked unsupported scheme "file:"'));

      final r3 = AddressBarParser.parse('data:text/html,<h1>Test</h1>');
      expect(r3.type, equals(AddressBarInputType.unsupportedScheme));
      expect(r3.errorMessage, contains('Blocked unsupported scheme "data:"'));
    });

    test('Selected search engine is respected without silent provider switching', () {
      final query = 'how to build privacy browser';

      final googleResult = AddressBarParser.parse(query, engine: SearchEngineRegistry.google);
      expect(googleResult.type, equals(AddressBarInputType.search));
      expect(googleResult.targetUri?.host, equals('www.google.com'));

      final ddgResult = AddressBarParser.parse(query, engine: SearchEngineRegistry.duckDuckGo);
      expect(ddgResult.type, equals(AddressBarInputType.search));
      expect(ddgResult.targetUri?.host, equals('duckduckgo.com'));

      final braveResult = AddressBarParser.parse(query, engine: SearchEngineRegistry.brave);
      expect(braveResult.type, equals(AddressBarInputType.search));
      expect(braveResult.targetUri?.host, equals('search.brave.com'));

      final bingResult = AddressBarParser.parse(query, engine: SearchEngineRegistry.bing);
      expect(bingResult.type, equals(AddressBarInputType.search));
      expect(bingResult.targetUri?.host, equals('www.bing.com'));
    });
  });

  group('Search Engine Persistence & Tab Navigation Flow Tests', () {
    test('Settings persistence saves and restores selected search engine', () async {
      final repo = InMemoryPersistenceRepository();
      await repo.initialize();

      // Initially unset
      final initialSetting = await repo.getSetting('selected_search_engine');
      expect(initialSetting, isNull);

      // Save DuckDuckGo
      await repo.setSetting('selected_search_engine', SearchEngineRegistry.duckDuckGo.id);

      // Retrieve setting
      final savedSetting = await repo.getSetting('selected_search_engine');
      expect(savedSetting, equals('duckduckgo'));
      final restoredEngine = SearchEngineRegistry.getById(savedSetting);
      expect(restoredEngine, equals(SearchEngineRegistry.duckDuckGo));

      // Switch to Brave Search
      await repo.setSetting('selected_search_engine', SearchEngineRegistry.brave.id);
      final updatedSetting = await repo.getSetting('selected_search_engine');
      expect(updatedSetting, equals('brave'));
    });

    test('Back and forward navigation works after a search', () async {
      final engine = MockTestBrowserEngine();
      final tab = BrowserTab(
        id: 'tab-1',
        engine: engine,
      );

      // 1. Initial page load
      tab.loadUrl(Uri.parse('https://docs.flutter.dev'));
      expect(tab.currentUrl?.toString(), equals('https://docs.flutter.dev'));

      // 2. Perform search
      final searchResult = AddressBarParser.parse('flutter state management', engine: SearchEngineRegistry.google);
      expect(searchResult.type, equals(AddressBarInputType.search));
      tab.loadUrl(searchResult.targetUri!);

      expect(tab.currentUrl?.toString(), equals('https://www.google.com/search?q=flutter+state+management'));
      expect(tab.canGoBack, isTrue);

      // 3. Navigate back
      tab.goBack();
      expect(tab.currentUrl?.toString(), equals('https://docs.flutter.dev'));
      expect(tab.canGoForward, isTrue);

      // 4. Navigate forward
      tab.goForward();
      expect(tab.currentUrl?.toString(), equals('https://www.google.com/search?q=flutter+state+management'));

      tab.dispose();
    });

    test('Required test inputs are correctly classified and generate proper URIs', () {
      // 1. "best open source AI models" -> Search via Google
      final r1 = AddressBarParser.parse('best open source AI models', engine: SearchEngineRegistry.google);
      expect(r1.type, equals(AddressBarInputType.search));
      expect(r1.targetUri?.toString(), equals('https://www.google.com/search?q=best+open+source+AI+models'));

      // 2. "https://flutter.dev" -> Direct navigation
      final r2 = AddressBarParser.parse('https://flutter.dev');
      expect(r2.type, equals(AddressBarInputType.directNavigation));
      expect(r2.targetUri?.toString(), equals('https://flutter.dev'));

      // 3. "github.com" -> Direct navigation normalized to HTTPS
      final r3 = AddressBarParser.parse('github.com');
      expect(r3.type, equals(AddressBarInputType.directNavigation));
      expect(r3.targetUri?.toString(), equals('https://github.com'));

      // 4. "localhost:3000" -> Direct navigation normalized to HTTP
      final r4 = AddressBarParser.parse('localhost:3000');
      expect(r4.type, equals(AddressBarInputType.directNavigation));
      expect(r4.targetUri?.toString(), equals('http://localhost:3000'));

      // 5. "hello world" -> Search via selected provider (DuckDuckGo, Bing, Brave, Google)
      final r5Google = AddressBarParser.parse('hello world', engine: SearchEngineRegistry.google);
      expect(r5Google.targetUri?.toString(), equals('https://www.google.com/search?q=hello+world'));

      final r5DDG = AddressBarParser.parse('hello world', engine: SearchEngineRegistry.duckDuckGo);
      expect(r5DDG.targetUri?.toString(), equals('https://duckduckgo.com/?q=hello+world'));

      final r5Bing = AddressBarParser.parse('hello world', engine: SearchEngineRegistry.bing);
      expect(r5Bing.targetUri?.toString(), equals('https://www.bing.com/search?q=hello+world'));

      final r5Brave = AddressBarParser.parse('hello world', engine: SearchEngineRegistry.brave);
      expect(r5Brave.targetUri?.toString(), equals('https://search.brave.com/search?q=hello+world'));
    });

    test('Active tab engine navigation method is actually called with generated search URL', () async {
      final engine = MockTestBrowserEngine();
      final tab = BrowserTab(id: 'tab-verify', engine: engine);

      final searchResult = AddressBarParser.parse('best open source AI models', engine: SearchEngineRegistry.google);
      await tab.loadUrl(searchResult.targetUri!);

      expect(engine.loadedUrls, contains(Uri.parse('https://www.google.com/search?q=best+open+source+AI+models')));
      expect(tab.currentUrl, equals(Uri.parse('https://www.google.com/search?q=best+open+source+AI+models')));
      tab.dispose();
    });

    testWidgets('Address bar preserves user typed query and navigates on Enter submission', (tester) async {
      final repo = InMemoryPersistenceRepository();
      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      // Find address bar TextField
      final addressBarFinder = find.byType(TextField).first;
      expect(addressBarFinder, findsOneWidget);

      // Enter search query
      await tester.enterText(addressBarFinder, 'best open source AI models');
      await tester.pump();

      // Ensure text is preserved and not immediately wiped by rebuilds
      expect(find.text('best open source AI models'), findsOneWidget);

      // Submit via enter
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Address bar now displays the generated Google search URL
      final expectedUrl = 'https://www.google.com/search?q=best+open+source+AI+models';
      expect(find.text(expectedUrl), findsOneWidget);
    });
  });
}

/// Lightweight mock browser engine for navigation state testing
class MockTestBrowserEngine implements BrowserEngine {
  final List<Uri> _history = [];
  final List<Uri> loadedUrls = [];
  int _currentIndex = -1;

  final _urlController = StreamController<Uri?>.broadcast();
  final _titleController = StreamController<String>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _loadingController = StreamController<bool>.broadcast();
  final _canGoBackController = StreamController<bool>.broadcast();
  final _canGoForwardController = StreamController<bool>.broadcast();
  final _errorController = StreamController<BrowserNavigationError?>.broadcast();

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
  Stream<int> get blockedCountStream => const Stream.empty();

  @override
  HotTeaShieldConfig get shieldConfig => const HotTeaShieldConfig();

  @override
  void updateShieldConfig(HotTeaShieldConfig config) {}

  void _notifyState() {
    _urlController.add(currentUrl);
    _titleController.add(currentTitle);
    _canGoBackController.add(canGoBack);
    _canGoForwardController.add(canGoForward);
  }

  @override
  final capabilities = const BrowserPlatformCapabilities(
    platformName: 'Mock Test Engine',
    renderMode: BrowserRenderMode.inlineWidget,
    supportsDomExtraction: true,
    supportsScriptInjection: true,
    supportsCookieIsolation: true,
    supportsInlineDevTools: false,
    underlyingEngineName: 'Mock Engine',
    license: 'MIT',
    notes: 'Testing only',
  );

  @override
  Uri? get currentUrl => _currentIndex >= 0 && _currentIndex < _history.length ? _history[_currentIndex] : null;

  @override
  String get currentTitle => currentUrl?.host ?? '';

  @override
  bool get canGoBack => _currentIndex > 0;

  @override
  bool get canGoForward => _currentIndex >= 0 && _currentIndex < _history.length - 1;

  @override
  bool get isLoading => false;

  @override
  double get progress => 1.0;

  @override
  BrowserNavigationError? get currentError => null;

  @override
  Future<void> loadUrl(Uri url) async {
    loadedUrls.add(url);
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }
    _history.add(url);
    _currentIndex = _history.length - 1;
    _notifyState();
  }

  @override
  Future<void> goBack() async {
    if (canGoBack) {
      _currentIndex--;
      _notifyState();
    }
  }

  @override
  Future<void> goForward() async {
    if (canGoForward) {
      _currentIndex++;
      _notifyState();
    }
  }

  @override
  Future<void> reload() async {}

  @override
  Future<void> stopLoading() async {}

  @override
  Future<void> findInPage(String text, {bool forward = true}) async {}

  @override
  Future<void> clearFindInPage() async {}

  @override
  Future<void> zoomIn() async {}

  @override
  Future<void> zoomOut() async {}

  @override
  Future<void> resetZoom() async {}

  @override
  Future<void> clearCache() async {}

  @override
  final bool isPrivate = false;

  final double _zoomLevel = 1.0;

  @override
  double get zoomLevel => _zoomLevel;

  @override
  void clearError() {}

  @override
  Future<String?> extractPageContent() async => null;

  @override
  Future<dynamic> evaluateJavascript(String script) async => null;

  @override
  Future<void> initialize({Uri? initialUrl}) async {
    if (initialUrl != null) await loadUrl(initialUrl);
  }

  @override
  Widget buildWidget(BuildContext context) => const SizedBox.shrink();

  @override
  Future<void> dispose() async {
    await _urlController.close();
    await _titleController.close();
    await _progressController.close();
    await _loadingController.close();
    await _canGoBackController.close();
    await _canGoForwardController.close();
    await _errorController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
