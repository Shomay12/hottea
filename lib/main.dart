import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/config/app_privacy_policy.dart';
import 'core/persistence/local_persistence_repository.dart';
import 'core/persistence/sqlite_persistence_repository.dart';
import 'features/ai/data/ai_gateway_impl.dart';
import 'features/ai/domain/ai_gateway.dart';
import 'features/browser/data/browser_engine_factory.dart';
import 'features/browser/data/download_manager.dart';
import 'features/browser/domain/address_bar_parser.dart';
import 'features/browser/domain/browser_engine.dart';
import 'features/browser/domain/browser_tab.dart';
import 'features/browser/domain/download_item.dart';
import 'features/browser/domain/search_engine.dart';
import 'features/research/data/webpage_extraction_service.dart';
import 'core/utils/external_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HotTeaApp());
}

class HotTeaApp extends StatelessWidget {
  final LocalPersistenceRepository? persistenceRepository;
  final bool forceMockBrowser;
  final AiGateway? aiGateway;

  const HotTeaApp({
    super.key,
    this.persistenceRepository,
    this.forceMockBrowser = false,
    this.aiGateway,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: HotTeaPrivacyPolicy.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD48B47), // Warm amber tea tone
          brightness: Brightness.dark,
          surface: const Color(0xFF16181D),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1115),
      ),
      home: HotTeaWorkspaceScreen(
        persistenceRepository: persistenceRepository,
        forceMockBrowser: forceMockBrowser,
        aiGateway: aiGateway,
      ),
    );
  }
}

class HotTeaWorkspaceScreen extends StatefulWidget {
  final bool forceMockBrowser;
  final LocalPersistenceRepository? persistenceRepository;
  final AiGateway? aiGateway;

  const HotTeaWorkspaceScreen({
    super.key,
    this.forceMockBrowser = false,
    this.persistenceRepository,
    this.aiGateway,
  });

  @override
  State<HotTeaWorkspaceScreen> createState() => _HotTeaWorkspaceScreenState();
}

class _HotTeaWorkspaceScreenState extends State<HotTeaWorkspaceScreen> with WidgetsBindingObserver {
  late final LocalPersistenceRepository _persistenceRepo;
  bool _isRepoInitialized = false;

  final List<BrowserTab> _tabs = [];
  int _activeTabIndex = 0;

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();

  // Find in page state
  bool _isFindInPageVisible = false;
  final TextEditingController _findController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();

  // Mobile navigation & tab switcher state
  bool _isMobileTabSwitcherOpen = false;
  int _mobileBottomNavIndex = 0; // 0: Browser, 1: Bookmarks, 2: History, 3: Research Notes, 4: Settings

  // Workspace Navigation State (Desktop)
  bool _isRightPaneVisible = true;
  String _activeRightTab = 'notes'; // 'notes', 'bookmarks', 'history', 'downloads', 'settings', 'ai'

  // Search Engine State
  SearchEngine _selectedSearchEngine = SearchEngineRegistry.defaultEngine;

  // Bookmarks State & Filter
  List<BookmarkEntity> _bookmarks = [];
  bool _isCurrentUrlBookmarked = false;
  final TextEditingController _bookmarksFilterController = TextEditingController();
  String _bookmarksFilterQuery = '';

  // History State & Filter
  List<HistoryEntry> _history = [];
  final TextEditingController _historyFilterController = TextEditingController();
  String _historyFilterQuery = '';

  // Notes State
  List<ResearchNote> _notes = [];
  ResearchNote? _selectedNote;
  final TextEditingController _noteTitleController = TextEditingController();
  final TextEditingController _noteContentController = TextEditingController();

  // Research Workspace & Evidence Clipping State
  final WebpageExtractionService _extractionService = WebpageExtractionService();
  List<SourceEntity> _sources = [];
  List<EvidenceEntity> _evidenceList = [];
  String _activeResearchSubTab = 'evidence'; // 'evidence', 'sources', 'notes'
  final TextEditingController _evidenceFilterController = TextEditingController();
  String _evidenceFilterQuery = '';
  String? _selectedEvidenceTopic;
  final Set<int> _selectedEvidenceIdsForAi = {};
  bool _isExtractingPage = false;

  // Session Restoration State
  bool _restoreSessionEnabled = false;

  // AI Gateway State
  late final AiGateway _aiGateway;
  final TextEditingController _aiPromptController = TextEditingController();
  final TextEditingController _aiBaseUrlController = TextEditingController();
  final TextEditingController _aiModelController = TextEditingController();
  final TextEditingController _aiApiKeyController = TextEditingController();
  bool _isAiExecuting = false;
  AiResponse? _lastAiResponse;
  String? _aiError;
  final Set<int> _selectedNoteIdsForAi = {};
  bool _isAiApiKeyObscured = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _persistenceRepo = widget.persistenceRepository ?? SqlitePersistenceRepository();
    _aiGateway = widget.aiGateway ?? AiGatewayImpl();
    _initPersistenceAndLoad();
    _createNewTab(Uri.parse('https://docs.flutter.dev'));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Phase 4: Handle iOS App Lifecycle and Memory suspension
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _saveSession();
    }
  }

  Future<void> _initPersistenceAndLoad() async {
    try {
      await _persistenceRepo.initialize();
      if (!mounted) return;

      setState(() {
        _isRepoInitialized = true;
      });

      await _refreshBookmarks();
      await _refreshHistory();
      await _refreshNotes();
      await _refreshSources();
      await _refreshEvidence();
      await _loadSearchEngineSetting();
      await _loadSessionRestoreSetting();
      await _loadAiSettings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database initialization error: $e')),
        );
      }
    }
  }

  Future<void> _loadAiSettings() async {
    if (!_isRepoInitialized) return;
    try {
      final savedProvider = await _persistenceRepo.getSetting('ai_provider_id');
      final savedBaseUrl = await _persistenceRepo.getSetting('ai_base_url');
      final savedModel = await _persistenceRepo.getSetting('ai_model');
      final savedApiKey = await _persistenceRepo.getSetting('ai_api_key');

      if (savedProvider != null && savedProvider.isNotEmpty) {
        _aiGateway.setActiveProvider(savedProvider);
      }
      final current = _aiGateway.activeConfig;
      _aiGateway.updateProviderConfig(current.copyWith(
        baseUrl: (savedBaseUrl != null && savedBaseUrl.isNotEmpty) ? savedBaseUrl : current.baseUrl,
        model: (savedModel != null && savedModel.isNotEmpty) ? savedModel : current.model,
        apiKey: (savedApiKey != null && savedApiKey.isNotEmpty) ? savedApiKey : current.apiKey,
      ));

      if (mounted) {
        setState(() {
          _aiBaseUrlController.text = _aiGateway.activeConfig.baseUrl;
          _aiModelController.text = _aiGateway.activeConfig.model;
          _aiApiKeyController.text = _aiGateway.activeConfig.apiKey;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSessionRestoreSetting() async {
    if (!_isRepoInitialized) return;
    try {
      final restoreVal = await _persistenceRepo.getSetting('restore_session');
      final isEnabled = restoreVal == 'true';
      if (mounted) {
        setState(() {
          _restoreSessionEnabled = isEnabled;
        });
      }

      if (isEnabled) {
        final savedUrls = await _persistenceRepo.getSetting('saved_session_urls');
        if (savedUrls != null && savedUrls.isNotEmpty && mounted) {
          final urls = savedUrls
              .split('|')
              .map((s) => Uri.tryParse(s.trim()))
              .whereType<Uri>()
              .where((u) => u.scheme == 'http' || u.scheme == 'https')
              .toList();

          if (urls.isNotEmpty) {
            // Replace initial tab with restored session
            for (final t in _tabs) {
              t.dispose();
            }
            setState(() {
              _tabs.clear();
            });
            for (final u in urls) {
              _createNewTab(u);
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveSession() async {
    if (!_isRepoInitialized || !_restoreSessionEnabled) return;
    try {
      final validUrls = _tabs
          .where((t) => !t.isPrivate && t.currentUrl != null && t.currentUrl!.scheme != 'about')
          .map((t) => t.currentUrl!.toString())
          .toList();
      await _persistenceRepo.setSetting('saved_session_urls', validUrls.join('|'));
    } catch (_) {}
  }

  Future<void> _toggleRestoreSession(bool enabled) async {
    setState(() {
      _restoreSessionEnabled = enabled;
    });
    if (_isRepoInitialized) {
      await _persistenceRepo.setSetting('restore_session', enabled ? 'true' : 'false');
      if (enabled) {
        await _saveSession();
      } else {
        await _persistenceRepo.setSetting('saved_session_urls', '');
      }
    }
  }

  Future<void> _refreshBookmarks() async {
    if (!_isRepoInitialized) return;
    try {
      final items = await _persistenceRepo.getBookmarks();
      if (mounted) {
        setState(() {
          _bookmarks = items;
        });
        _checkCurrentUrlBookmarked();
      }
    } catch (_) {}
  }

  Future<void> _refreshHistory() async {
    if (!_isRepoInitialized) return;
    try {
      final items = await _persistenceRepo.getHistory();
      if (mounted) {
        setState(() {
          _history = items;
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshNotes() async {
    if (!_isRepoInitialized) return;
    try {
      final items = await _persistenceRepo.getNotes();
      if (mounted) {
        setState(() {
          _notes = items;
          if (_selectedNote == null && items.isNotEmpty) {
            _selectNote(items.first);
          } else if (items.isEmpty) {
            _selectedNote = null;
            _noteTitleController.clear();
            _noteContentController.clear();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshSources() async {
    if (!_isRepoInitialized) return;
    try {
      final items = await _persistenceRepo.getSources();
      if (mounted) {
        setState(() {
          _sources = items;
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshEvidence() async {
    if (!_isRepoInitialized) return;
    try {
      final items = await _persistenceRepo.getEvidence(
        topic: _selectedEvidenceTopic,
        query: _evidenceFilterQuery.isNotEmpty ? _evidenceFilterQuery : null,
      );
      if (mounted) {
        setState(() {
          _evidenceList = items;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSearchEngineSetting() async {
    if (!_isRepoInitialized) return;
    try {
      final savedId = await _persistenceRepo.getSetting('selected_search_engine');
      if (savedId != null && mounted) {
        setState(() {
          _selectedSearchEngine = SearchEngineRegistry.getById(savedId);
        });
      }
    } catch (_) {}
  }

  Future<void> _selectSearchEngine(SearchEngine engine) async {
    setState(() {
      _selectedSearchEngine = engine;
    });
    if (_isRepoInitialized) {
      await _persistenceRepo.setSetting('selected_search_engine', engine.id);
    }
  }

  void _selectNote(ResearchNote note) {
    setState(() {
      _selectedNote = note;
      _noteTitleController.text = note.title;
      _noteContentController.text = note.content;
    });
  }

  void _checkCurrentUrlBookmarked() {
    final current = _tabs.isNotEmpty ? _activeTab.currentUrl : null;
    if (current == null) {
      setState(() => _isCurrentUrlBookmarked = false);
      return;
    }
    final cleanCurrent = current.toString();
    final bookmarked = _bookmarks.any((b) => b.url.toString() == cleanCurrent);
    if (_isCurrentUrlBookmarked != bookmarked && mounted) {
      setState(() => _isCurrentUrlBookmarked = bookmarked);
    }
  }

  void _createNewTab([Uri? initialUrl, bool isPrivate = false]) {
    final newUrl = initialUrl ?? Uri.parse('about:blank');
    final engine = BrowserEngineFactory.createEngine(
      initialUrl: newUrl,
      forceMock: widget.forceMockBrowser,
      isPrivate: isPrivate,
    );

    final tab = BrowserTab(
      id: 'tab_${DateTime.now().millisecondsSinceEpoch}_${_tabs.length}',
      engine: engine,
      initialUrl: newUrl,
      onStateChanged: () {
        if (mounted) {
          setState(() {
            if (!_urlFocusNode.hasFocus && _tabs.isNotEmpty && _activeTab.currentUrl != null) {
              final urlStr = _activeTab.currentUrl.toString();
              _urlController.text = urlStr == 'about:blank' ? '' : urlStr;
            }
          });
          _checkCurrentUrlBookmarked();
          _recordHistoryIfCompleted();
          _saveSession();
        }
      },
    );

    setState(() {
      _tabs.add(tab);
      _activeTabIndex = _tabs.length - 1;
      _isMobileTabSwitcherOpen = false;
      _mobileBottomNavIndex = 0;
      _urlController.text = newUrl.toString() == 'about:blank' ? '' : newUrl.toString();
    });
    _checkCurrentUrlBookmarked();
    _saveSession();
  }

  void _recordHistoryIfCompleted() {
    if (!_isRepoInitialized || _tabs.isEmpty) return;
    final tab = _activeTab;
    // INVARIANT: Never record private tabs, failed navigations, or about:blank to history
    if (tab.isPrivate) return;
    if (tab.error != null) return;
    if (tab.isLoading) return;
    if (tab.currentUrl == null || tab.currentUrl!.scheme == 'about') return;

    _persistenceRepo
        .recordVisit(
          url: tab.currentUrl!,
          title: tab.currentTitle.isEmpty ? (tab.currentUrl!.host.isNotEmpty ? tab.currentUrl!.host : tab.currentUrl!.toString()) : tab.currentTitle,
        )
        .then((_) => _refreshHistory())
        .catchError((_) {});
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) {
      // Cleanly handle zero/one tab on mobile: reset to about:blank
      _tabs[0].loadUrl(Uri.parse('about:blank'));
      setState(() {
        _urlController.text = '';
      });
      return;
    }

    final tabToClose = _tabs[index];
    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
      final cur = _tabs[_activeTabIndex].currentUrl?.toString() ?? '';
      _urlController.text = cur == 'about:blank' ? '' : cur;
    });
    tabToClose.dispose();
    _checkCurrentUrlBookmarked();
    _saveSession();
  }

  BrowserTab get _activeTab => _tabs[_activeTabIndex];

  void _focusAddressBar() {
    _urlFocusNode.requestFocus();
    _urlController.selection = TextSelection(baseOffset: 0, extentOffset: _urlController.text.length);
  }

  void _copyCurrentUrl() {
    final url = _activeTab.currentUrl?.toString();
    if (url != null && url.isNotEmpty && url != 'about:blank') {
      Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('URL copied to clipboard.'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  void _toggleFindInPage() {
    setState(() {
      _isFindInPageVisible = !_isFindInPageVisible;
    });
    if (_isFindInPageVisible) {
      _findFocusNode.requestFocus();
      if (_findController.text.isNotEmpty) {
        _activeTab.findInPage(_findController.text, forward: true);
      }
    } else {
      _activeTab.clearFindInPage();
    }
  }

  void _closeFindInPage() {
    setState(() {
      _isFindInPageVisible = false;
    });
    _findController.clear();
    _activeTab.clearFindInPage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final tab in _tabs) {
      tab.dispose();
    }
    _urlFocusNode.dispose();
    _urlController.dispose();
    _findFocusNode.dispose();
    _findController.dispose();
    _bookmarksFilterController.dispose();
    _historyFilterController.dispose();
    _noteTitleController.dispose();
    _noteContentController.dispose();
    _aiPromptController.dispose();
    _aiBaseUrlController.dispose();
    _aiModelController.dispose();
    _aiApiKeyController.dispose();
    _persistenceRepo.close();
    super.dispose();
  }

  void _onNavigate([String? rawText]) {
    final text = (rawText ?? _urlController.text).trim();
    if (text.isEmpty) return;

    final parseResult = AddressBarParser.parse(text, engine: _selectedSearchEngine);

    switch (parseResult.type) {
      case AddressBarInputType.empty:
        return;

      case AddressBarInputType.unsupportedScheme:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(parseResult.errorMessage ?? 'Unsupported URL scheme.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
        return;

      case AddressBarInputType.directNavigation:
      case AddressBarInputType.search:
        final target = parseResult.targetUri;
        if (target != null) {
          setState(() {
            _urlController.text = target.toString();
            _isMobileTabSwitcherOpen = false;
            _mobileBottomNavIndex = 0;
          });
          _urlFocusNode.unfocus();
          _activeTab.loadUrl(target);
        }
        return;
    }
  }

  Future<void> _toggleBookmark() async {
    final currentUrl = _activeTab.currentUrl;
    if (currentUrl == null || !_isRepoInitialized || currentUrl.scheme == 'about') return;

    try {
      if (_isCurrentUrlBookmarked) {
        final existing = _bookmarks.firstWhere((b) => b.url.toString() == currentUrl.toString());
        if (existing.id != null) {
          await _persistenceRepo.deleteBookmark(existing.id!);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bookmark removed.'), duration: Duration(seconds: 1)),
          );
        }
      } else {
        await _persistenceRepo.addBookmark(
          url: currentUrl,
          title: _activeTab.currentTitle.isEmpty ? (currentUrl.host.isNotEmpty ? currentUrl.host : currentUrl.toString()) : _activeTab.currentTitle,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Page bookmarked.'), duration: Duration(seconds: 1)),
        );
      }
      await _refreshBookmarks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bookmark error: $e')),
      );
    }
  }

  Future<void> _clipActivePageToNotes() async {
    final url = _activeTab.currentUrl;
    final title = _activeTab.currentTitle.isEmpty ? (url?.host ?? 'Web Resource') : _activeTab.currentTitle;
    final snippet = '# $title\n\n- Source: ${url?.toString() ?? "unknown"}\n- Clipped: ${DateTime.now().toLocal()}\n\n## Notes\n';

    try {
      final newNote = await _persistenceRepo.createNote(
        title: title,
        content: snippet,
        sourceUrl: url,
      );
      await _refreshNotes();
      _selectNote(newNote);
      if (!mounted) return;
      setState(() {
        _isRightPaneVisible = true;
        _activeRightTab = 'notes';
        _mobileBottomNavIndex = 3;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipped page to research notes.'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clip note: $e')),
      );
    }
  }

  Future<void> _extractCurrentPageAndOpenClipModal() async {
    final currentUrl = _activeTab.currentUrl;
    if (currentUrl == null || (currentUrl.scheme == 'about' && currentUrl.path != 'blank')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please navigate to a webpage before clipping evidence.')),
      );
      return;
    }

    setState(() => _isExtractingPage = true);

    SourceEntity? sourceToUse;
    String? initialPassage;

    try {
      final result = await _extractionService.extractFromEngine(_activeTab.engine);
      if (result.isSuccess && result.source != null) {
        sourceToUse = await _persistenceRepo.saveSource(result.source!);
        await _refreshSources();
        initialPassage = result.activeSelection;
      } else {
        // Fallback: create base source from tab metadata
        final fallbackSource = SourceEntity(
          url: currentUrl,
          title: _activeTab.currentTitle.isNotEmpty ? _activeTab.currentTitle : currentUrl.toString(),
          capturedAt: DateTime.now(),
        );
        sourceToUse = await _persistenceRepo.saveSource(fallbackSource);
        await _refreshSources();

        if (mounted && result.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.errorMessage} You can still enter or paste a verbatim excerpt.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      final fallbackSource = SourceEntity(
        url: currentUrl,
        title: _activeTab.currentTitle.isNotEmpty ? _activeTab.currentTitle : currentUrl.toString(),
        capturedAt: DateTime.now(),
      );
      sourceToUse = await _persistenceRepo.saveSource(fallbackSource);
      await _refreshSources();
    } finally {
      if (mounted) {
        setState(() => _isExtractingPage = false);
      }
    }

    if (mounted) {
      _showCaptureEvidenceModal(
        initialSource: sourceToUse,
        initialPassage: initialPassage,
      );
    }
  }

  void _showCaptureEvidenceModal({
    required SourceEntity initialSource,
    String? initialPassage,
  }) {
    final passageController = TextEditingController(text: initialPassage ?? '');
    final headingController = TextEditingController();
    final annotationController = TextEditingController();
    final tagsController = TextEditingController();
    final topicController = TextEditingController(text: _selectedEvidenceTopic ?? '');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161922),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white12)),
              title: Row(
                children: [
                  const Icon(Icons.content_cut_outlined, size: 20, color: Color(0xFFD48B47)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Capture Evidence Passage',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540, maxHeight: 600),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Source citation banner
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101218),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              initialSource.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              (initialSource.canonicalUrl ?? initialSource.url).toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                            ),
                            if (initialSource.author != null || initialSource.publishedDate != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                '${initialSource.author != null ? 'Author: ${initialSource.author}  ' : ''}${initialSource.publishedDate != null ? 'Date: ${initialSource.publishedDate}' : ''}',
                                style: const TextStyle(fontSize: 10, color: Colors.white54),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Passage text field
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Verbatim Passage Text *',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD48B47).withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Preserved verbatim',
                              style: TextStyle(fontSize: 10, color: Color(0xFFD48B47), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: passageController,
                        maxLines: 5,
                        style: const TextStyle(fontSize: 12, height: 1.4, fontFamily: 'serif'),
                        decoration: InputDecoration(
                          hintText: 'Paste or enter exact excerpt from webpage...\nExample: "Zero default telemetry is guaranteed across all desktop and mobile targets."',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF101218),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD48B47))),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Context heading selector / textfield
                      if (initialSource.headings.isNotEmpty) ...[
                        const Text('Context Section / Heading', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: initialSource.headings.take(6).map((h) {
                              final isSelected = headingController.text == h;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(h, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: isSelected ? const Color(0xFFD48B47).withAlpha(60) : const Color(0xFF101218),
                                  side: BorderSide(color: isSelected ? const Color(0xFFD48B47) : Colors.white10),
                                  onPressed: () {
                                    setDialogState(() {
                                      headingController.text = h;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      TextField(
                        controller: headingController,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Section / Context Heading (optional)',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF101218),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // User Annotation field
                      const Text('User Annotation / Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: annotationController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Your thoughts, relevance, or analytical notes...',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF101218),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Tags and Topic in two columns
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tags (comma-separated)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: tagsController,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. privacy, security',
                                    hintStyle: const TextStyle(fontSize: 11, color: Colors.white30),
                                    filled: true,
                                    fillColor: const Color(0xFF101218),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Research Topic', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: topicController,
                                  style: const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Project HotTea',
                                    hintStyle: const TextStyle(fontSize: 11, color: Colors.white30),
                                    filled: true,
                                    fillColor: const Color(0xFF101218),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.bookmark_added, size: 16),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD48B47),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final passage = passageController.text.trim();
                    if (passage.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter or paste passage text to clip.')),
                      );
                      return;
                    }

                    final tags = tagsController.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    final evidence = EvidenceEntity(
                      sourceId: initialSource.id,
                      sourceUrl: initialSource.canonicalUrl ?? initialSource.url,
                      sourceTitle: initialSource.title,
                      passage: passage,
                      contextHeading: headingController.text.trim().isNotEmpty ? headingController.text.trim() : null,
                      annotation: annotationController.text.trim().isNotEmpty ? annotationController.text.trim() : null,
                      tags: tags,
                      topic: topicController.text.trim().isNotEmpty ? topicController.text.trim() : null,
                      capturedAt: DateTime.now(),
                    );

                    await _persistenceRepo.saveEvidence(evidence);
                    await _refreshEvidence();
                    if (!mounted || !ctx.mounted) return;
                    Navigator.pop(ctx);

                    setState(() {
                      _isRightPaneVisible = true;
                      _activeRightTab = 'notes';
                      _activeResearchSubTab = 'evidence';
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Evidence saved to Research Workspace.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  label: const Text('Save Evidence', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditEvidenceModal(EvidenceEntity evidence) {
    final annotationController = TextEditingController(text: evidence.annotation ?? '');
    final tagsController = TextEditingController(text: evidence.tags.join(', '));
    final topicController = TextEditingController(text: evidence.topic ?? '');
    final headingController = TextEditingController(text: evidence.contextHeading ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161922),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white12)),
          title: const Text('Edit Evidence Annotation & Tags', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101218),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      '"${evidence.passage}"',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Section / Heading', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: headingController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF101218),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Annotation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: annotationController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF101218),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Tags (comma-separated)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: tagsController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF101218),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Research Topic', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: topicController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF101218),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD48B47),
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final tags = tagsController.text
                    .split(',')
                    .map((t) => t.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();

                final updated = evidence.copyWith(
                  contextHeading: headingController.text.trim().isNotEmpty ? headingController.text.trim() : null,
                  annotation: annotationController.text.trim().isNotEmpty ? annotationController.text.trim() : null,
                  tags: tags,
                  topic: topicController.text.trim().isNotEmpty ? topicController.text.trim() : null,
                );

                await _persistenceRepo.updateEvidence(updated);
                await _refreshEvidence();
                if (!mounted || !ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSourceDetailsModal(SourceEntity source) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161922),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white12)),
          title: Row(
            children: [
              const Icon(Icons.source_outlined, color: Color(0xFFD48B47), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Webpage Source Details', style: TextStyle(fontSize: 11, color: Color(0xFFD48B47))),
                    Text(source.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _activeTab.loadUrl(source.url);
                    },
                    child: Text(
                      source.url.toString(),
                      style: const TextStyle(fontSize: 11, color: Colors.blueAccent, decoration: TextDecoration.underline),
                    ),
                  ),
                  if (source.canonicalUrl != null) ...[
                    const SizedBox(height: 4),
                    Text('Canonical URL: ${source.canonicalUrl}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                  ],
                  if (source.author != null || source.publishedDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${source.author != null ? 'Author: ${source.author} • ' : ''}${source.publishedDate != null ? 'Published: ${source.publishedDate}' : ''}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (source.headings.isNotEmpty) ...[
                    const Text('Page Headings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF101218), borderRadius: BorderRadius.circular(6)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: source.headings.map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text('• $h', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (source.extractedText != null && source.extractedText!.isNotEmpty) ...[
                    const Text('Extracted Body Text Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFF101218), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        source.extractedText!,
                        maxLines: 8,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, height: 1.4, color: Colors.white70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                if (source.id != null) {
                  await _persistenceRepo.deleteSource(source.id!);
                  await _refreshSources();
                  if (mounted && ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Delete Source', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD48B47), foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(ctx);
                _showCaptureEvidenceModal(initialSource: source);
              },
              child: const Text('Clip from this Source', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyDisclosureDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFD48B47)),
            SizedBox(width: 8),
            Text('HotTea Privacy Guarantees'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Zero Telemetry by default.'),
            SizedBox(height: 6),
            Text('2. Local persistence in offline SQLite database; zero cloud synchronization.'),
            SizedBox(height: 6),
            Text('3. Browsing history sanitizes credentials and tokens automatically.'),
            SizedBox(height: 6),
            Text('4. Private / Incognito tabs never write history or cookies to disk.'),
            SizedBox(height: 6),
            Text('5. Local inference never falls back to cloud without explicit prompt.'),
            SizedBox(height: 6),
            Text('6. Browser engine completely isolated from UI code.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  void _showMobileActionSheet(BuildContext context, BrowserTab activeTab) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF16181D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  activeTab.currentTitle.isEmpty ? (activeTab.currentUrl?.host ?? 'HotTea Browser') : activeTab.currentTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildActionChip(
                      icon: _isCurrentUrlBookmarked ? Icons.star : Icons.star_border,
                      label: _isCurrentUrlBookmarked ? 'Bookmarked' : 'Bookmark',
                      color: _isCurrentUrlBookmarked ? Colors.amber : Colors.white70,
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleBookmark();
                      },
                    ),
                    _buildActionChip(
                      icon: Icons.copy_rounded,
                      label: 'Copy URL',
                      onTap: () {
                        _copyCurrentUrl();
                        Navigator.pop(ctx);
                      },
                    ),
                    _buildActionChip(
                      icon: Icons.note_add_outlined,
                      label: 'Clip to Notes',
                      onTap: () {
                        Navigator.pop(ctx);
                        _clipActivePageToNotes();
                      },
                    ),
                    _buildActionChip(
                      icon: Icons.content_cut_outlined,
                      label: 'Clip Evidence',
                      color: const Color(0xFFD48B47),
                      onTap: () {
                        Navigator.pop(ctx);
                        _extractCurrentPageAndOpenClipModal();
                      },
                    ),
                    _buildActionChip(
                      icon: Icons.source_outlined,
                      label: 'Research Notes',
                      color: const Color(0xFFD48B47),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _mobileBottomNavIndex = 3);
                      },
                    ),
                    _buildActionChip(
                      icon: Icons.find_in_page_outlined,
                      label: 'Find in Page',
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleFindInPage();
                      },
                    ),
                    _buildActionChip(
                      icon: Icons.download_outlined,
                      label: 'Downloads',
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _mobileBottomNavIndex = 0;
                          _isRightPaneVisible = true;
                          _activeRightTab = 'downloads';
                        });
                      },
                    ),
                    _buildActionChip(
                      icon: Icons.shield_outlined,
                      label: 'Privacy Audit',
                      color: Colors.greenAccent,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showPrivacyDisclosureDialog();
                      },
                    ),
                    _buildActionChip(
                      icon: Icons.auto_awesome_outlined,
                      label: 'AI Workspace',
                      color: const Color(0xFFD48B47),
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _mobileBottomNavIndex = 5;
                        });
                      },
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white12),
                // Zoom & Cache controls row
                Row(
                  children: [
                    const Icon(Icons.zoom_in, size: 16, color: Colors.white54),
                    const SizedBox(width: 6),
                    const Text('Zoom', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(Icons.remove, size: 14),
                      onPressed: () => activeTab.zoomOut(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '${(activeTab.zoomLevel * 100).round()}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(Icons.add, size: 14),
                      onPressed: () => activeTab.zoomIn(),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      ),
                      onPressed: () => activeTab.resetZoom(),
                      child: const Text('Reset', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    Color color = Colors.white70,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1F232D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = _activeTab;
    final capabilities = activeTab.engine.capabilities;
    // Responsive mobile breakpoint: phones in both portrait and landscape
    final isMobile = MediaQuery.sizeOf(context).shortestSide < 600;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyT, meta: true): () => _createNewTab(),
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () => _createNewTab(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true): () => _createNewTab(null, true),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true): () => _createNewTab(null, true),
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true): () => _closeTab(_activeTabIndex),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () => _closeTab(_activeTabIndex),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () => _activeTab.reload(),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () => _activeTab.reload(),
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true): _focusAddressBar,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): _focusAddressBar,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): _toggleFindInPage,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _toggleFindInPage,
        const SingleActivator(LogicalKeyboardKey.keyD, meta: true): _toggleBookmark,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): _toggleBookmark,
        const SingleActivator(LogicalKeyboardKey.bracketLeft, meta: true): () {
          if (_activeTab.canGoBack) _activeTab.goBack();
        },
        const SingleActivator(LogicalKeyboardKey.bracketLeft, control: true): () {
          if (_activeTab.canGoBack) _activeTab.goBack();
        },
        const SingleActivator(LogicalKeyboardKey.bracketRight, meta: true): () {
          if (_activeTab.canGoForward) _activeTab.goForward();
        },
        const SingleActivator(LogicalKeyboardKey.bracketRight, control: true): () {
          if (_activeTab.canGoForward) _activeTab.goForward();
        },
        const SingleActivator(LogicalKeyboardKey.equal, meta: true): () => _activeTab.zoomIn(),
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () => _activeTab.zoomIn(),
        const SingleActivator(LogicalKeyboardKey.minus, meta: true): () => _activeTab.zoomOut(),
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () => _activeTab.zoomOut(),
        const SingleActivator(LogicalKeyboardKey.digit0, meta: true): () => _activeTab.resetZoom(),
        const SingleActivator(LogicalKeyboardKey.digit0, control: true): () => _activeTab.resetZoom(),
      },
      child: isMobile
          ? _buildMobileScaffold(context, activeTab, capabilities)
          : _buildDesktopScaffold(context, activeTab, capabilities),
    );
  }

  // --- MOBILE SCREEN ARCHITECTURE (iPhone & Mobile-First) ---
  Widget _buildMobileScaffold(BuildContext context, BrowserTab activeTab, BrowserPlatformCapabilities capabilities) {
    if (_mobileBottomNavIndex == 1) {
      return _buildMobileSecondaryScreen(
        title: 'Bookmarks',
        body: _buildBookmarksView(),
      );
    } else if (_mobileBottomNavIndex == 2) {
      return _buildMobileSecondaryScreen(
        title: 'Browsing History',
        body: _buildHistoryView(),
      );
    } else if (_mobileBottomNavIndex == 3) {
      return _buildMobileSecondaryScreen(
        title: 'Research Notes',
        body: _buildNotesView(),
      );
    } else if (_mobileBottomNavIndex == 4) {
      return _buildMobileSecondaryScreen(
        title: 'Settings',
        body: _buildSettingsView(),
      );
    } else if (_mobileBottomNavIndex == 5) {
      return _buildMobileSecondaryScreen(
        title: 'AI Workspace',
        body: _buildAiGatewayView(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        backgroundColor: const Color(0xFF16181D),
        elevation: 0,
        titleSpacing: 8,
        title: Row(
          children: [
            _buildSearchEngineMenuButton(compact: true),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1115),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: activeTab.isPrivate ? Colors.purpleAccent.withAlpha(120) : Colors.white12,
                    ),
                  ),
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    onSubmitted: (value) => _onNavigate(value),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      prefixIcon: activeTab.isPrivate
                          ? const Icon(Icons.shield, size: 14, color: Colors.purpleAccent)
                          : const Icon(Icons.lock_outline, size: 13, color: Colors.white38),
                      hintText: 'Search or enter URL',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isCurrentUrlBookmarked)
                            const Icon(Icons.star, size: 15, color: Colors.amber),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward, size: 15),
                            onPressed: () => _onNavigate(),
                          ),
                        ],
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: activeTab.isLoading
                    ? const Icon(Icons.close, size: 18, color: Colors.orangeAccent)
                    : const Icon(Icons.refresh, size: 18),
                tooltip: activeTab.isLoading ? 'Stop' : 'Reload',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  if (activeTab.isLoading) {
                    activeTab.stopLoading();
                  } else {
                    activeTab.reload();
                  }
                },
              ),
            ],
          ),
          bottom: activeTab.isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: activeTab.progress > 0 ? activeTab.progress : null,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      activeTab.isPrivate ? Colors.purpleAccent : const Color(0xFFD48B47),
                    ),
                  ),
                )
              : null,
        ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: _isMobileTabSwitcherOpen
            ? _buildMobileTabOverview()
            : Column(
                children: [
                  if (_isFindInPageVisible) _buildFindInPageBar(activeTab),
                  Expanded(
                    child: _buildViewportContent(activeTab),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _isMobileTabSwitcherOpen
          ? null
          : Container(
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFF13151A),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      tooltip: 'Back',
                      onPressed: activeTab.canGoBack ? () => activeTab.goBack() : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      tooltip: 'Forward',
                      onPressed: activeTab.canGoForward ? () => activeTab.goForward() : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 22, color: Color(0xFFD48B47)),
                      tooltip: 'New Tab',
                      onPressed: () => _createNewTab(),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isMobileTabSwitcherOpen = true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: activeTab.isPrivate ? Colors.purpleAccent : const Color(0xFFD48B47),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_tabs.length}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: activeTab.isPrivate ? Colors.purpleAccent : const Color(0xFFD48B47),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_horiz, size: 22),
                      tooltip: 'More Actions',
                      onPressed: () => _showMobileActionSheet(context, activeTab),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMobileSecondaryScreen({required String title, required Widget body}) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Return to Browser',
          onPressed: () => setState(() => _mobileBottomNavIndex = 0),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF13151A),
        selectedItemColor: const Color(0xFFD48B47),
        unselectedItemColor: Colors.white54,
        currentIndex: _mobileBottomNavIndex.clamp(0, 4),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: (index) => setState(() => _mobileBottomNavIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.language), label: 'Browser'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmarks_outlined), label: 'Bookmarks'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.note_alt_outlined), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  // --- MOBILE TAB OVERVIEW (Card Switcher) ---
  Widget _buildMobileTabOverview() {
    return Container(
      color: const Color(0xFF0F1115),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF16181D),
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                Text(
                  'Tabs (${_tabs.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _isMobileTabSwitcherOpen = false),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD48B47))),
                ),
              ],
            ),
          ),
          Expanded(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final crossAxisCount = orientation == Orientation.portrait ? 2 : 4;
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _tabs.length,
                  itemBuilder: (context, index) {
                    final tab = _tabs[index];
                    final isActive = index == _activeTabIndex;
                    final isPrivate = tab.isPrivate;
                    final borderColor = isPrivate
                        ? Colors.purpleAccent
                        : (isActive ? const Color(0xFFD48B47) : Colors.white12);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _activeTabIndex = index;
                          _isMobileTabSwitcherOpen = false;
                          final cur = tab.currentUrl?.toString() ?? '';
                          _urlController.text = cur == 'about:blank' ? '' : cur;
                        });
                        _checkCurrentUrlBookmarked();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF16181D),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor, width: isActive ? 2 : 1),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (isPrivate) ...[
                                  const Icon(Icons.shield, size: 14, color: Colors.purpleAccent),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    tab.currentTitle.isEmpty
                                        ? (isPrivate ? 'Private' : 'New Tab')
                                        : tab.currentTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                      color: isActive ? Colors.white : Colors.white70,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _closeTab(index),
                                  child: const Icon(Icons.close, size: 16, color: Colors.white54),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Center(
                              child: Icon(
                                isPrivate ? Icons.shield_outlined : Icons.language,
                                size: 36,
                                color: isPrivate ? Colors.purpleAccent.withAlpha(120) : Colors.white24,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              tab.currentUrl?.host.isNotEmpty == true
                                  ? tab.currentUrl!.host
                                  : 'about:blank',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF16181D),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.shield_outlined, color: Colors.purpleAccent),
                  tooltip: 'New Private Tab',
                  onPressed: () => _createNewTab(null, true),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD48B47),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Tab', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _createNewTab(),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _isMobileTabSwitcherOpen = false),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- MOBILE NEW TAB HUB ---
  Widget _buildMobileNewTabHub() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFD48B47).withAlpha(35),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD48B47).withAlpha(120), width: 1.5),
            ),
            child: const Icon(Icons.coffee, size: 26, color: Color(0xFFD48B47)),
          ),
          const SizedBox(height: 12),
          const Text(
            'HotTea Workspace',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Search with ${_selectedSearchEngine.name} • Zero Telemetry',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 20),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF16181D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD48B47).withAlpha(80)),
            ),
            child: TextField(
              style: const TextStyle(fontSize: 13),
              onSubmitted: (val) => _onNavigate(val),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFFD48B47)),
                hintText: 'Search or enter URL...',
                hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Quick Access', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMobileQuickCard('Flutter Docs', Icons.flutter_dash, 'https://docs.flutter.dev'),
              _buildMobileQuickCard('Dart Pub', Icons.extension_outlined, 'https://pub.dev'),
              _buildMobileQuickCard('GitHub', Icons.code, 'https://github.com'),
              _buildMobileQuickCard('Wikipedia', Icons.menu_book, 'https://en.wikipedia.org'),
              _buildMobileQuickCard('Hacker News', Icons.newspaper, 'https://news.ycombinator.com'),
              _buildMobileQuickCard('ArXiv', Icons.science_outlined, 'https://arxiv.org'),
            ],
          ),
          if (_bookmarks.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Bookmarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _bookmarks.take(4).map((b) {
                return ActionChip(
                  avatar: const Icon(Icons.bookmark, size: 12, color: Color(0xFFD48B47)),
                  label: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                  backgroundColor: const Color(0xFF16181D),
                  onPressed: () => _activeTab.loadUrl(b.url),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileQuickCard(String title, IconData icon, String url) {
    return InkWell(
      onTap: () => _activeTab.loadUrl(Uri.parse(url)),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF16181D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFD48B47)),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // --- DESKTOP SCREEN ARCHITECTURE (macOS, Linux, Windows, Web) ---
  Widget _buildDesktopScaffold(BuildContext context, BrowserTab activeTab, BrowserPlatformCapabilities capabilities) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181D),
        elevation: 0,
        titleSpacing: 8,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD48B47).withAlpha(40),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFD48B47).withAlpha(100)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.coffee, size: 16, color: Color(0xFFD48B47)),
                  SizedBox(width: 6),
                  Text(
                    'HotTea',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFD48B47),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              tooltip: 'Back',
              visualDensity: VisualDensity.compact,
              onPressed: activeTab.canGoBack ? () => activeTab.goBack() : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18),
              tooltip: 'Forward',
              visualDensity: VisualDensity.compact,
              onPressed: activeTab.canGoForward ? () => activeTab.goForward() : null,
            ),
            IconButton(
              icon: activeTab.isLoading
                  ? const Icon(Icons.close, size: 18, color: Colors.orangeAccent)
                  : const Icon(Icons.refresh, size: 18),
              tooltip: activeTab.isLoading ? 'Stop' : 'Reload',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                if (activeTab.isLoading) {
                  activeTab.stopLoading();
                } else {
                  activeTab.reload();
                }
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1115),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: activeTab.isPrivate ? Colors.purpleAccent.withAlpha(120) : Colors.white12,
                  ),
                ),
                child: TextField(
                  controller: _urlController,
                  focusNode: _urlFocusNode,
                  onSubmitted: (value) => _onNavigate(value),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (activeTab.isPrivate)
                          const Padding(
                            padding: EdgeInsets.only(left: 6, right: 2),
                            child: Tooltip(
                              message: 'Private / Incognito Tab',
                              child: Icon(Icons.shield, size: 14, color: Colors.purpleAccent),
                            ),
                          ),
                        _buildSearchEngineMenuButton(),
                        IconButton(
                          icon: Icon(
                            _isCurrentUrlBookmarked ? Icons.star : Icons.star_border,
                            size: 18,
                            color: _isCurrentUrlBookmarked ? Colors.amber : Colors.white54,
                          ),
                          tooltip: _isCurrentUrlBookmarked ? 'Remove Bookmark' : 'Bookmark Page',
                          visualDensity: VisualDensity.compact,
                          onPressed: _toggleBookmark,
                        ),
                        IconButton(
                          icon: _isExtractingPage
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD48B47)),
                                )
                              : const Icon(
                                  Icons.content_cut_outlined,
                                  size: 17,
                                  color: Color(0xFFD48B47),
                                ),
                          tooltip: 'Clip Evidence from Page',
                          visualDensity: VisualDensity.compact,
                          onPressed: _isExtractingPage ? null : _extractCurrentPageAndOpenClipModal,
                        ),
                      ],
                    ),
                    hintText: 'Search with ${_selectedSearchEngine.name} or enter URL',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14, color: Colors.white54),
                          tooltip: 'Copy URL',
                          visualDensity: VisualDensity.compact,
                          onPressed: _copyCurrentUrl,
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward, size: 15),
                          onPressed: _onNavigate,
                          tooltip: 'Navigate or Search',
                        ),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFindInPageVisible ? Icons.find_in_page : Icons.find_in_page_outlined,
              size: 20,
              color: _isFindInPageVisible ? const Color(0xFFD48B47) : null,
            ),
            tooltip: 'Find in Page (Cmd+F)',
            onPressed: _toggleFindInPage,
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined, size: 20),
            tooltip: 'Clip to Notes',
            onPressed: _clipActivePageToNotes,
          ),
          IconButton(
            icon: const Icon(Icons.security, color: Colors.greenAccent, size: 20),
            tooltip: 'Privacy Audit',
            onPressed: _showPrivacyDisclosureDialog,
          ),
          IconButton(
            icon: Icon(
              _isRightPaneVisible ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              size: 20,
            ),
            tooltip: 'Toggle Research Workspace',
            onPressed: () {
              setState(() {
                _isRightPaneVisible = !_isRightPaneVisible;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Column(
            children: [
              Container(
                height: 34,
                color: const Color(0xFF13151A),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tabs.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 4),
                        itemBuilder: (context, index) {
                          final tab = _tabs[index];
                          final isActive = index == _activeTabIndex;
                          final isPrivate = tab.isPrivate;
                          final accentColor = isPrivate ? Colors.purpleAccent : const Color(0xFFD48B47);

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _activeTabIndex = index;
                                final cur = tab.currentUrl?.toString() ?? '';
                                _urlController.text = cur == 'about:blank' ? '' : cur;
                              });
                              _checkCurrentUrlBookmarked();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              constraints: const BoxConstraints(maxWidth: 170),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF0B0D11) : Colors.transparent,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                border: Border(
                                  top: BorderSide(
                                    color: isActive ? accentColor : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isPrivate) ...[
                                    const Icon(Icons.shield, size: 12, color: Colors.purpleAccent),
                                    const SizedBox(width: 4),
                                  ],
                                  Flexible(
                                    child: Text(
                                      tab.currentTitle.isEmpty
                                          ? (isPrivate ? 'Private Tab' : 'New Tab')
                                          : tab.currentTitle,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                        color: isActive ? Colors.white : Colors.white60,
                                      ),
                                    ),
                                  ),
                                  if (_tabs.length > 1) ...[
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => _closeTab(index),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white54),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      tooltip: 'New Tab',
                      onPressed: () => _createNewTab(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.shield_outlined, size: 15, color: Colors.purpleAccent),
                      tooltip: 'New Private Tab (Cmd+Shift+N)',
                      onPressed: () => _createNewTab(null, true),
                    ),
                  ],
                ),
              ),
              if (activeTab.isLoading)
                LinearProgressIndicator(
                  value: activeTab.progress > 0 ? activeTab.progress : null,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    activeTab.isPrivate ? Colors.purpleAccent : const Color(0xFFD48B47),
                  ),
                )
              else
                const SizedBox(height: 2),
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          Expanded(
            flex: _isRightPaneVisible ? 6 : 10,
            child: Container(
              color: const Color(0xFF0B0D11),
              child: Column(
                children: [
                  if (_isFindInPageVisible) _buildFindInPageBar(activeTab),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: const Color(0xFF13161C),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: activeTab.isPrivate ? Colors.purpleAccent : Colors.greenAccent,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            activeTab.isPrivate
                                ? 'Private Session • Engine: ${capabilities.underlyingEngineName}'
                                : 'Engine: ${capabilities.underlyingEngineName}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Platform: ${capabilities.platformName}',
                            style: const TextStyle(fontSize: 10, color: Colors.white60),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.remove, size: 14, color: Colors.white60),
                          tooltip: 'Zoom Out (Cmd+-)',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => activeTab.zoomOut(),
                        ),
                        InkWell(
                          onTap: () => activeTab.resetZoom(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '${(activeTab.zoomLevel * 100).round()}%',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 14, color: Colors.white60),
                          tooltip: 'Zoom In (Cmd+=)',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => activeTab.zoomIn(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildViewportContent(activeTab),
                  ),
                ],
              ),
            ),
          ),
          if (_isRightPaneVisible) ...[
            const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
            Expanded(
              flex: 4,
              child: Container(
                color: const Color(0xFF14171E),
                child: Column(
                  children: [
                    Container(
                      color: const Color(0xFF1A1E26),
                      child: Row(
                        children: [
                          _buildRightTabHeader('notes', Icons.note_alt_outlined, 'Notes'),
                          _buildRightTabHeader('bookmarks', Icons.bookmarks_outlined, 'Bookmarks'),
                          _buildRightTabHeader('history', Icons.history, 'History'),
                          _buildRightTabHeader('downloads', Icons.download_outlined, 'Downloads'),
                          _buildRightTabHeader('settings', Icons.settings_outlined, 'Settings'),
                          _buildRightTabHeader('ai', Icons.auto_awesome_outlined, 'AI'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildRightTabContent(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFindInPageBar(BrowserTab tab) {
    return Container(
      height: 42,
      color: const Color(0xFF1B1E28),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.find_in_page_outlined, size: 18, color: Color(0xFFD48B47)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _findController,
              focusNode: _findFocusNode,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Find in page...',
                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                isDense: true,
                border: InputBorder.none,
              ),
              onChanged: (text) => tab.findInPage(text, forward: true),
              onSubmitted: (text) => tab.findInPage(text, forward: true),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 20),
            tooltip: 'Previous match',
            visualDensity: VisualDensity.compact,
            onPressed: () => tab.findInPage(_findController.text, forward: false),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 20),
            tooltip: 'Next match',
            visualDensity: VisualDensity.compact,
            onPressed: () => tab.findInPage(_findController.text, forward: true),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Close find bar (Esc)',
            visualDensity: VisualDensity.compact,
            onPressed: _closeFindInPage,
          ),
        ],
      ),
    );
  }

  Widget _buildViewportContent(BrowserTab activeTab) {
    if (activeTab.error != null) {
      return _buildErrorRecoveryView(activeTab.error!, activeTab.currentUrl);
    }

    final urlStr = activeTab.currentUrl?.toString();
    if (urlStr == null || urlStr == 'about:blank' || urlStr.isEmpty) {
      final isMobile = MediaQuery.sizeOf(context).shortestSide < 600;
      return isMobile ? _buildMobileNewTabHub() : _buildNewTabHub();
    }

    if (kIsWeb && _isSearchProviderHost(activeTab.currentUrl)) {
      return _buildWebSearchProviderFallback(activeTab.currentUrl!);
    }

    return activeTab.engine.buildWidget(context);
  }

  Widget _buildErrorRecoveryView(BrowserNavigationError error, Uri? failedUrl) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF16181D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withAlpha(100)),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unable to Load Page',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (failedUrl != null)
                          Text(
                            failedUrl.host.isNotEmpty ? failedUrl.host : failedUrl.toString(),
                            style: const TextStyle(fontSize: 12, color: Colors.white54),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                error.message,
                style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 12),
              if (failedUrl != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0D11),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    failedUrl.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.white54, fontFamily: 'monospace'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD48B47),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      _activeTab.clearError();
                      _activeTab.reload();
                    },
                  ),
                  if (failedUrl != null && failedUrl.host.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.search, size: 16),
                      label: Text('Search "${failedUrl.host}"'),
                      onPressed: () {
                        _activeTab.clearError();
                        _onNavigate(failedUrl.host);
                      },
                    ),
                  TextButton(
                    onPressed: () => _activeTab.clearError(),
                    child: const Text('Dismiss', style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewTabHub() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFD48B47).withAlpha(35),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD48B47).withAlpha(120), width: 2),
                ),
                child: const Icon(Icons.coffee, size: 32, color: Color(0xFFD48B47)),
              ),
              const SizedBox(height: 16),
              const Text(
                'HotTea Research Workspace',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Privacy-First • Local Storage • ${_selectedSearchEngine.name} Search',
                style: const TextStyle(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 28),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF16181D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD48B47).withAlpha(80)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: TextField(
                  style: const TextStyle(fontSize: 15),
                  onSubmitted: (val) => _onNavigate(val),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search, size: 20, color: Color(0xFFD48B47)),
                          const SizedBox(width: 8),
                          Text(
                            _selectedSearchEngine.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD48B47),
                            ),
                          ),
                        ],
                      ),
                    ),
                    hintText: 'Search the web or type a URL...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward, color: Color(0xFFD48B47)),
                      onPressed: () => _onNavigate(),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Quick Access',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildQuickAccessCard('Flutter Docs', 'docs.flutter.dev', Icons.flutter_dash, 'https://docs.flutter.dev'),
                  _buildQuickAccessCard('Dart Pub', 'pub.dev', Icons.extension_outlined, 'https://pub.dev'),
                  _buildQuickAccessCard('GitHub', 'github.com', Icons.code, 'https://github.com'),
                  _buildQuickAccessCard('Wikipedia', 'wikipedia.org', Icons.menu_book, 'https://en.wikipedia.org'),
                  _buildQuickAccessCard('Hacker News', 'news.ycombinator.com', Icons.newspaper, 'https://news.ycombinator.com'),
                  _buildQuickAccessCard('ArXiv', 'arxiv.org', Icons.science_outlined, 'https://arxiv.org'),
                ],
              ),
              const SizedBox(height: 28),
              if (_bookmarks.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent Bookmarks',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _bookmarks.take(6).map((b) {
                    return ActionChip(
                      avatar: const Icon(Icons.bookmark, size: 14, color: Color(0xFFD48B47)),
                      label: Text(b.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      backgroundColor: const Color(0xFF16181D),
                      side: const BorderSide(color: Colors.white12),
                      onPressed: () => _activeTab.loadUrl(b.url),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(String title, String subtitle, IconData icon, String targetUrl) {
    return InkWell(
      onTap: () => _activeTab.loadUrl(Uri.parse(targetUrl)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF16181D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD48B47).withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFFD48B47)),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white38),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightTabHeader(String tabKey, IconData icon, String label) {
    final isActive = _activeRightTab == tabKey;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeRightTab = tabKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? const Color(0xFFD48B47) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? const Color(0xFFD48B47) : Colors.white54,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.white : Colors.white60,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightTabContent() {
    switch (_activeRightTab) {
      case 'bookmarks':
        return _buildBookmarksView();
      case 'history':
        return _buildHistoryView();
      case 'downloads':
        return _buildDownloadsView();
      case 'settings':
        return _buildSettingsView();
      case 'ai':
        return _buildAiGatewayView();
      case 'notes':
      default:
        return _buildNotesView();
    }
  }

  bool _isSearchProviderHost(Uri? url) {
    if (url == null) return false;
    final host = url.host.toLowerCase();
    return host.contains('google.') ||
        host.contains('duckduckgo.') ||
        host.contains('bing.') ||
        host.contains('brave.');
  }

  Widget _buildWebSearchProviderFallback(Uri url) {
    return Container(
      color: const Color(0xFF0F1115),
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF16181D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD48B47).withAlpha(80)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD48B47).withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.shield_outlined, color: Color(0xFFD48B47), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Web Iframe Security Restriction',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            url.host,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFD48B47)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Major search providers (Google, DuckDuckGo, Bing, Brave) enforce X-Frame-Options: SAMEORIGIN and CSP frame-ancestors security headers. Web browsers reject embedding them inside cross-origin iframes to protect against clickjacking.',
                  style: TextStyle(fontSize: 13, color: Colors.white70, height: 1.5),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0D11),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    url.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.white60, fontFamily: 'monospace'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD48B47),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open in New Window / Tab', style: TextStyle(fontWeight: FontWeight.w600)),
                      onPressed: () => launchExternalWebUrl(url.toString()),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _activeTab.reload(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Note: On native iOS and macOS, HotTea uses Apple WebKit (WKWebView), rendering search results directly in this window without iframe restrictions.',
                  style: TextStyle(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchEngineMenuButton({bool compact = false}) {
    return PopupMenuButton<SearchEngine>(
      tooltip: 'Search Engine: ${_selectedSearchEngine.name} (Click to switch)',
      initialValue: _selectedSearchEngine,
      onSelected: (engine) {
        _selectSearchEngine(engine);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Default search engine set to ${engine.name}'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      itemBuilder: (context) {
        return SearchEngineRegistry.availableEngines.map((engine) {
          final isSelected = engine.id == _selectedSearchEngine.id;
          return PopupMenuItem<SearchEngine>(
            value: engine,
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 16,
                  color: isSelected ? const Color(0xFFD48B47) : Colors.white54,
                ),
                const SizedBox(width: 8),
                Text(
                  engine.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFFD48B47) : Colors.white,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 4, right: 2),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 5, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search, size: 13, color: Color(0xFFD48B47)),
              if (!compact) ...[
                const SizedBox(width: 3),
                Text(
                  _selectedSearchEngine.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD48B47),
                  ),
                ),
              ],
              const Icon(Icons.arrow_drop_down, size: 13, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  // --- Settings View ---
  Widget _buildSettingsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(
          children: [
            Icon(Icons.travel_explore, size: 18, color: Color(0xFFD48B47)),
            SizedBox(width: 8),
            Text(
              'Default Search Engine',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Queries typed into the address bar are searched using the selected provider. Requests connect directly to the provider without proxy intermediaries.',
          style: TextStyle(fontSize: 11, color: Colors.white60),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1E27),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: RadioGroup<String>(
            groupValue: _selectedSearchEngine.id,
            onChanged: (val) {
              if (val != null) {
                _selectSearchEngine(SearchEngineRegistry.getById(val));
              }
            },
            child: Column(
              children: SearchEngineRegistry.availableEngines.map((engine) {
                final isSelected = engine.id == _selectedSearchEngine.id;
                return RadioListTile<String>(
                  value: engine.id,
                  activeColor: const Color(0xFFD48B47),
                  title: Text(
                    engine.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  subtitle: Text(
                    engine.homeUrl,
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF171A22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD48B47).withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined, size: 14, color: Color(0xFFD48B47)),
                  const SizedBox(width: 6),
                  Text(
                    '${_selectedSearchEngine.name} Privacy Notice',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD48B47)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _selectedSearchEngine.privacyNotice,
                style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Session Restoration
        const Row(
          children: [
            Icon(Icons.restore_page_outlined, size: 18, color: Color(0xFFD48B47)),
            SizedBox(width: 8),
            Text(
              'Session Restoration',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1B1E27),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: SwitchListTile(
            activeThumbColor: const Color(0xFFD48B47),
            value: _restoreSessionEnabled,
            onChanged: _toggleRestoreSession,
            title: const Text('Restore Open Tabs on Launch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text(
              'Saves URLs of active non-private tabs to local SQLite database so they reopen on next start.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Browser Data Management
        const Row(
          children: [
            Icon(Icons.cleaning_services_outlined, size: 18, color: Color(0xFFD48B47)),
            SizedBox(width: 8),
            Text(
              'Data & Cache Management',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1E27),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cached, size: 20, color: Colors.white70),
                title: const Text('Clear Engine Cache', style: TextStyle(fontSize: 13)),
                subtitle: const Text('Removes cached network assets and cookies from the active session.', style: TextStyle(fontSize: 11, color: Colors.white38)),
                trailing: OutlinedButton(
                  onPressed: () async {
                    await _activeTab.clearCache();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Browser engine cache cleared.')),
                    );
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_sweep, size: 20, color: Colors.redAccent),
                title: const Text('Clear All Browsing History', style: TextStyle(fontSize: 13)),
                subtitle: const Text('Deletes all navigation visit records from local SQLite storage.', style: TextStyle(fontSize: 11, color: Colors.white38)),
                trailing: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                  onPressed: () async {
                    await _persistenceRepo.clearAllHistory();
                    await _refreshHistory();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All browsing history cleared.')),
                    );
                  },
                  child: const Text('Clear All', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // AI Provider Configuration (Phase 3)
        const Row(
          children: [
            Icon(Icons.auto_awesome, size: 18, color: Color(0xFFD48B47)),
            SizedBox(width: 8),
            Text(
              'AI Provider & Gateway Configuration',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'HotTea uses a provider-independent AI gateway. All API credentials and endpoints are persisted locally in SQLite. HotTea never operates telemetry or intermediary proxy servers.',
          style: TextStyle(fontSize: 11, color: Colors.white60),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1E27),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Active AI Provider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _aiGateway.availableProviders.map((p) {
                  final isSelected = p.id == _aiGateway.activeConfig.id;
                  final cap = _aiGateway.getCapability(p.id);
                  return ChoiceChip(
                    label: Text(
                      '${p.name}${cap.isLocal ? ' (Planned)' : ''}',
                      style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.white),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFFD48B47),
                    backgroundColor: const Color(0xFF16181D),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _aiGateway.setActiveProvider(p.id);
                          _aiBaseUrlController.text = _aiGateway.activeConfig.baseUrl;
                          _aiModelController.text = _aiGateway.activeConfig.model;
                          _aiApiKeyController.text = _aiGateway.activeConfig.apiKey;
                        });
                        _saveAiSettings();
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _aiBaseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Endpoint Base URL',
                  hintText: 'https://api.openai.com/v1',
                  prefixIcon: Icon(Icons.link, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aiModelController,
                decoration: const InputDecoration(
                  labelText: 'Model Identifier',
                  hintText: 'gpt-4o-mini',
                  prefixIcon: Icon(Icons.psychology_outlined, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _aiApiKeyController,
                obscureText: _isAiApiKeyObscured,
                decoration: InputDecoration(
                  labelText: 'API Key (Stored locally in SQLite)',
                  hintText: 'sk-...',
                  prefixIcon: const Icon(Icons.key, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(_isAiApiKeyObscured ? Icons.visibility : Icons.visibility_off, size: 18),
                    onPressed: () => setState(() => _isAiApiKeyObscured = !_isAiApiKeyObscured),
                  ),
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD48B47),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Save AI Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: _saveAiSettings,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveAiSettings() async {
    final activeId = _aiGateway.activeConfig.id;
    final updatedConfig = _aiGateway.activeConfig.copyWith(
      baseUrl: _aiBaseUrlController.text.trim().isEmpty ? _aiGateway.activeConfig.baseUrl : _aiBaseUrlController.text.trim(),
      model: _aiModelController.text.trim().isEmpty ? _aiGateway.activeConfig.model : _aiModelController.text.trim(),
      apiKey: _aiApiKeyController.text.trim(),
    );
    _aiGateway.updateProviderConfig(updatedConfig);

    await _persistenceRepo.setSetting('ai_provider_id', activeId);
    await _persistenceRepo.setSetting('ai_base_url', updatedConfig.baseUrl);
    await _persistenceRepo.setSetting('ai_model', updatedConfig.model);
    await _persistenceRepo.setSetting('ai_api_key', updatedConfig.apiKey);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Gateway configuration saved to local storage.')),
      );
    }
  }

  // --- Downloads View ---
  Widget _buildDownloadsView() {
    return ValueListenableBuilder<List<DownloadItem>>(
      valueListenable: DownloadManager.instance.downloadsNotifier,
      builder: (context, downloads, _) {
        if (downloads.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_done_outlined, size: 36, color: Colors.white38),
                  SizedBox(height: 12),
                  Text('No Downloads Yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  SizedBox(height: 6),
                  Text(
                    'Files downloaded while browsing will be listed here with status and progress.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: const Color(0xFF161922),
              child: Row(
                children: [
                  Text('Downloads (${downloads.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear Completed', style: TextStyle(fontSize: 11)),
                    onPressed: () => DownloadManager.instance.clearCompleted(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: downloads.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                itemBuilder: (context, index) {
                  final item = downloads[index];
                  final isDownloading = item.status == DownloadStatus.downloading;

                  return ListTile(
                    dense: true,
                    leading: Icon(
                      item.status == DownloadStatus.completed
                          ? Icons.check_circle_outline
                          : item.status == DownloadStatus.failed
                              ? Icons.error_outline
                              : item.status == DownloadStatus.cancelled
                                  ? Icons.cancel_outlined
                                  : Icons.downloading_outlined,
                      size: 20,
                      color: item.status == DownloadStatus.completed
                          ? Colors.greenAccent
                          : item.status == DownloadStatus.failed
                              ? Colors.redAccent
                              : item.status == DownloadStatus.cancelled
                                  ? Colors.white38
                                  : const Color(0xFFD48B47),
                    ),
                    title: Text(
                      item.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          '${item.status.name.toUpperCase()} • ${item.formattedSize}',
                          style: const TextStyle(fontSize: 10, color: Colors.white54),
                        ),
                        if (isDownloading) ...[
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: item.progress > 0 ? item.progress : null,
                            minHeight: 3,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD48B47)),
                          ),
                        ],
                      ],
                    ),
                    trailing: isDownloading
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                            tooltip: 'Cancel Download',
                            onPressed: () => DownloadManager.instance.cancelDownload(item.id),
                          )
                        : item.status == DownloadStatus.completed && item.localPath != null
                            ? const Icon(Icons.folder_open, size: 16, color: Colors.white54)
                            : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Research Workspace View (Evidence Clippings, Sources, and Notes) ---
  Widget _buildNotesView() => _buildResearchWorkspaceView();

  Widget _buildResearchWorkspaceView() {
    return Column(
      children: [
        // Sub-navigation header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: const Color(0xFF161922),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text('Evidence (${_evidenceList.length})', style: const TextStyle(fontSize: 11)),
                        selected: _activeResearchSubTab == 'evidence',
                        selectedColor: const Color(0xFFD48B47),
                        backgroundColor: const Color(0xFF1E222B),
                        labelStyle: TextStyle(
                          color: _activeResearchSubTab == 'evidence' ? Colors.black : Colors.white70,
                          fontWeight: _activeResearchSubTab == 'evidence' ? FontWeight.bold : FontWeight.normal,
                        ),
                        visualDensity: VisualDensity.compact,
                        onSelected: (val) {
                          if (val) setState(() => _activeResearchSubTab = 'evidence');
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('Sources (${_sources.length})', style: const TextStyle(fontSize: 11)),
                        selected: _activeResearchSubTab == 'sources',
                        selectedColor: const Color(0xFFD48B47),
                        backgroundColor: const Color(0xFF1E222B),
                        labelStyle: TextStyle(
                          color: _activeResearchSubTab == 'sources' ? Colors.black : Colors.white70,
                          fontWeight: _activeResearchSubTab == 'sources' ? FontWeight.bold : FontWeight.normal,
                        ),
                        visualDensity: VisualDensity.compact,
                        onSelected: (val) {
                          if (val) setState(() => _activeResearchSubTab = 'sources');
                        },
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: Text('Notes (${_notes.length})', style: const TextStyle(fontSize: 11)),
                        selected: _activeResearchSubTab == 'notes',
                        selectedColor: const Color(0xFFD48B47),
                        backgroundColor: const Color(0xFF1E222B),
                        labelStyle: TextStyle(
                          color: _activeResearchSubTab == 'notes' ? Colors.black : Colors.white70,
                          fontWeight: _activeResearchSubTab == 'notes' ? FontWeight.bold : FontWeight.normal,
                        ),
                        visualDensity: VisualDensity.compact,
                        onSelected: (val) {
                          if (val) setState(() => _activeResearchSubTab = 'notes');
                        },
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: _isExtractingPage
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD48B47)),
                      )
                    : const Icon(Icons.content_cut_outlined, size: 17, color: Color(0xFFD48B47)),
                tooltip: 'Clip Evidence from Active Webpage',
                visualDensity: VisualDensity.compact,
                onPressed: _isExtractingPage ? null : _extractCurrentPageAndOpenClipModal,
              ),
            ],
          ),
        ),

        // Sub-view Body
        Expanded(
          child: _activeResearchSubTab == 'evidence'
              ? _buildEvidenceClippingsSubView()
              : _activeResearchSubTab == 'sources'
                  ? _buildSourcesSubView()
                  : _buildNotesSubView(),
        ),
      ],
    );
  }

  // --- Sub-View 1: Evidence Clippings ---
  Widget _buildEvidenceClippingsSubView() {
    return Column(
      children: [
        // Search & Topic Filter Bar
        if (_evidenceList.isNotEmpty || _evidenceFilterQuery.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: TextField(
              controller: _evidenceFilterController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search passages, annotations, or sources...',
                hintStyle: const TextStyle(fontSize: 11, color: Colors.white38),
                prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white54),
                suffixIcon: _evidenceFilterQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 14),
                        onPressed: () {
                          _evidenceFilterController.clear();
                          setState(() => _evidenceFilterQuery = '');
                          _refreshEvidence();
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF16181D),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white12)),
              ),
              onChanged: (val) {
                setState(() => _evidenceFilterQuery = val.trim());
                _refreshEvidence();
              },
            ),
          ),

        // Evidence List
        Expanded(
          child: _evidenceList.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.content_cut_outlined, size: 36, color: Colors.white24),
                        const SizedBox(height: 10),
                        const Text(
                          'No evidence captured yet.',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Browse any webpage and click the Clip icon to preserve verbatim source passages with verified URLs.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.white38),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.content_cut_outlined, size: 15),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD48B47),
                            foregroundColor: Colors.black,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _extractCurrentPageAndOpenClipModal,
                          label: const Text('Clip from Active Page', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: _evidenceList.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final e = _evidenceList[index];
                    final dateStr = '${e.capturedAt.month}/${e.capturedAt.day} ${e.capturedAt.hour.toString().padLeft(2, '0')}:${e.capturedAt.minute.toString().padLeft(2, '0')}';

                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF16181F),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white10),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Source citation header
                          Row(
                            children: [
                              const Icon(Icons.source_outlined, size: 14, color: Color(0xFFD48B47)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  e.sourceTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.white38)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                tooltip: 'Delete Evidence',
                                onPressed: () async {
                                  if (e.id != null) {
                                    await _persistenceRepo.deleteEvidence(e.id!);
                                    await _refreshEvidence();
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Clickable Source URL
                          InkWell(
                            onTap: () => _activeTab.loadUrl(e.sourceUrl),
                            child: Text(
                              e.sourceUrl.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.blueAccent, decoration: TextDecoration.underline),
                            ),
                          ),

                          // Context heading badge
                          if (e.contextHeading != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bookmark_border, size: 11, color: Colors.white60),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Section: ${e.contextHeading!}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (e.topic != null && e.topic!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD48B47).withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFD48B47).withAlpha(80)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.folder_outlined, size: 11, color: Color(0xFFD48B47)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Topic: ${e.topic!}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD48B47)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),

                          // Verbatim passage block
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF101218),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD48B47),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.format_quote, size: 14, color: Color(0xFFD48B47)),
                                    const SizedBox(width: 4),
                                    const Text('Verbatim Evidence', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD48B47))),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  '"${e.passage}"',
                                  style: const TextStyle(fontSize: 12, height: 1.4, fontFamily: 'serif', color: Colors.white),
                                ),
                              ],
                            ),
                          ),

                          // User Annotation (if present)
                          if (e.annotation != null && e.annotation!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.edit_note, size: 14, color: Colors.white54),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Note: ${e.annotation!}',
                                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Tags
                          if (e.tags.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: e.tags.map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD48B47).withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFD48B47).withAlpha(60)),
                                ),
                                child: Text('#$t', style: const TextStyle(fontSize: 10, color: Color(0xFFD48B47))),
                              )).toList(),
                            ),
                          ],
                          const SizedBox(height: 8),

                          // Action bar
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.auto_awesome, size: 13, color: Color(0xFFD48B47)),
                                label: const Text('Send to AI', style: TextStyle(fontSize: 11, color: Color(0xFFD48B47))),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () {
                                  if (e.id != null) {
                                    setState(() {
                                      _selectedEvidenceIdsForAi.add(e.id!);
                                      _activeRightTab = 'ai';
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Evidence attached to AI prompt.'), duration: Duration(seconds: 2)),
                                    );
                                  }
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.note_add_outlined, size: 13, color: Colors.white70),
                                label: const Text('Append to Note', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () async {
                                  final citation = '\n\n> ${e.passage}\n-- [${e.sourceTitle}](${e.sourceUrl})\n';
                                  if (_selectedNote != null) {
                                    final updated = _selectedNote!.copyWith(
                                      content: _selectedNote!.content + citation,
                                    );
                                    await _persistenceRepo.updateNote(updated);
                                    await _refreshNotes();
                                  } else {
                                    final newNote = await _persistenceRepo.createNote(
                                      title: 'Research from ${e.sourceTitle}',
                                      content: citation,
                                      sourceUrl: e.sourceUrl,
                                    );
                                    await _refreshNotes();
                                    _selectNote(newNote);
                                  }
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Evidence appended to active Markdown note.')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.white60),
                                tooltip: 'Edit Annotation / Tags',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _showEditEvidenceModal(e),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // --- Sub-View 2: Webpage Sources ---
  Widget _buildSourcesSubView() {
    if (_sources.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.source_outlined, size: 36, color: Colors.white24),
              const SizedBox(height: 10),
              const Text('No webpage sources captured yet.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 4),
              const Text('Extract content from any open webpage to view its headings, metadata, and body text.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.white38)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                icon: const Icon(Icons.content_cut_outlined, size: 15),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD48B47),
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _extractCurrentPageAndOpenClipModal,
                label: const Text('Extract Active Page', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _sources.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = _sources[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16181F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.language, size: 16, color: Color(0xFFD48B47)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 15, color: Colors.redAccent),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      if (s.id != null) {
                        await _persistenceRepo.deleteSource(s.id!);
                        await _refreshSources();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 3),
              InkWell(
                onTap: () => _activeTab.loadUrl(s.url),
                child: Text(
                  s.url.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.blueAccent, decoration: TextDecoration.underline),
                ),
              ),
              if (s.author != null || s.publishedDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${s.author != null ? 'Author: ${s.author}  ' : ''}${s.publishedDate != null ? 'Date: ${s.publishedDate}' : ''}',
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                '${s.headings.length} headings extracted • ${s.extractedText != null ? '${(s.extractedText!.length / 1000).toStringAsFixed(1)}k chars' : 'No body text'}',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.menu_book, size: 13),
                    label: const Text('Details & Headings', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _showSourceDetailsModal(s),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.content_cut_outlined, size: 13, color: Color(0xFFD48B47)),
                    label: const Text('Clip', style: TextStyle(fontSize: 11, color: Color(0xFFD48B47))),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () => _showCaptureEvidenceModal(initialSource: s),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Sub-View 3: Markdown Notes ---
  Widget _buildNotesSubView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFF161922),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Notes (${_notes.length})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'Create New Note',
                onPressed: () async {
                  final created = await _persistenceRepo.createNote(
                    title: 'New Research Note',
                    content: '',
                    sourceUrl: _activeTab.currentUrl,
                  );
                  await _refreshNotes();
                  _selectNote(created);
                },
              ),
              if (_selectedNote != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  tooltip: 'Delete Selected Note',
                  onPressed: () async {
                    if (_selectedNote?.id != null) {
                      await _persistenceRepo.deleteNote(_selectedNote!.id!);
                      _selectedNote = null;
                      await _refreshNotes();
                    }
                  },
                ),
            ],
          ),
        ),
        if (_notes.isNotEmpty)
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _notes.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final note = _notes[index];
                final isSelected = _selectedNote?.id == note.id;
                return ChoiceChip(
                  label: Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.black : Colors.white70,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFFD48B47),
                  backgroundColor: const Color(0xFF1E222B),
                  onSelected: (val) {
                    if (val) _selectNote(note);
                  },
                );
              },
            ),
          ),
        Expanded(
          child: _selectedNote == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No research notes yet.\nClick + to create an offline Markdown note.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _noteTitleController,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Note Title',
                          isDense: true,
                          border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        ),
                        onChanged: (val) {
                          if (_selectedNote != null) {
                            final updated = _selectedNote!.copyWith(title: val);
                            _persistenceRepo.updateNote(updated);
                          }
                        },
                      ),
                      if (_selectedNote?.sourceUrl != null) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            if (_selectedNote?.sourceUrl != null) {
                              _activeTab.loadUrl(_selectedNote!.sourceUrl!);
                            }
                          },
                          child: Text(
                            'Source: ${_selectedNote!.sourceUrl}',
                            style: const TextStyle(fontSize: 11, color: Colors.blueAccent, decoration: TextDecoration.underline),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Expanded(
                        child: TextField(
                          controller: _noteContentController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          decoration: const InputDecoration(
                            hintText: 'Markdown content...',
                            border: InputBorder.none,
                          ),
                          onChanged: (val) {
                            if (_selectedNote != null) {
                              final updated = _selectedNote!.copyWith(content: val);
                              _persistenceRepo.updateNote(updated);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // --- Bookmarks View with Search Filter & Open in New Tab ---
  Widget _buildBookmarksView() {
    final filtered = _bookmarksFilterQuery.isEmpty
        ? _bookmarks
        : _bookmarks.where((b) {
            final q = _bookmarksFilterQuery.toLowerCase();
            return b.title.toLowerCase().contains(q) || b.url.toString().toLowerCase().contains(q);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _bookmarksFilterController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Filter bookmarks...',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
              prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white54),
              suffixIcon: _bookmarksFilterQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14),
                      onPressed: () {
                        setState(() {
                          _bookmarksFilterController.clear();
                          _bookmarksFilterQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1B1E27),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _bookmarksFilterQuery = val.trim()),
          ),
        ),
        Expanded(
          child: _bookmarks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bookmarks_outlined, size: 36, color: Colors.white38),
                        const SizedBox(height: 12),
                        const Text('No Bookmarks Saved', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        const Text(
                          'Star the address bar or click below to bookmark the active page.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _toggleBookmark,
                          icon: const Icon(Icons.star_outline, size: 16),
                          label: const Text('Bookmark Active Page'),
                        ),
                      ],
                    ),
                  ),
                )
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No bookmarks match your search.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, index) {
                        final b = filtered[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.bookmark, color: Color(0xFFD48B47), size: 18),
                          title: Text(
                            b.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            b.url.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: Colors.white54),
                          ),
                          onTap: () {
                            if (b.isValidUrl) {
                              setState(() {
                                _mobileBottomNavIndex = 0;
                              });
                              _activeTab.loadUrl(b.url);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invalid bookmark URL.')),
                              );
                            }
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 14, color: Colors.white54),
                                tooltip: 'Open in New Tab',
                                onPressed: () => _createNewTab(b.url),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white38),
                                tooltip: 'Delete Bookmark',
                                onPressed: () async {
                                  if (b.id != null) {
                                    await _persistenceRepo.deleteBookmark(b.id!);
                                    await _refreshBookmarks();
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // --- Browsing History View with Search Filter & Open in New Tab ---
  Widget _buildHistoryView() {
    final filtered = _historyFilterQuery.isEmpty
        ? _history
        : _history.where((h) {
            final q = _historyFilterQuery.toLowerCase();
            return h.title.toLowerCase().contains(q) || h.url.toString().toLowerCase().contains(q);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _historyFilterController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Filter browsing history...',
              hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
              prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white54),
              suffixIcon: _historyFilterQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 14),
                      onPressed: () {
                        setState(() {
                          _historyFilterController.clear();
                          _historyFilterQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1B1E27),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              isDense: true,
            ),
            onChanged: (val) => setState(() => _historyFilterQuery = val.trim()),
          ),
        ),
        if (_history.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            color: const Color(0xFF161922),
            child: Row(
              children: [
                Text(
                  'Entries: ${_history.length}',
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear All Browsing History?'),
                        content: const Text('This will delete all locally recorded browsing history.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear All', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _persistenceRepo.clearAllHistory();
                      await _refreshHistory();
                    }
                  },
                  icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.redAccent),
                  label: const Text('Clear All', style: TextStyle(fontSize: 11, color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        Expanded(
          child: _history.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'No browsing history recorded yet.\nSuccessful navigations are logged locally with stripped credentials.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                )
              : filtered.isEmpty
                  ? const Center(
                      child: Text('No history entries match your search.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, index) {
                        final h = filtered[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.public, size: 16, color: Colors.white54),
                          title: Text(
                            h.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          subtitle: Text(
                            '${h.url} • ${_formatTime(h.visitedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, color: Colors.white38),
                          ),
                          onTap: () {
                            setState(() {
                              _mobileBottomNavIndex = 0;
                            });
                            _activeTab.loadUrl(h.url);
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.open_in_new, size: 14, color: Colors.white54),
                                tooltip: 'Open in New Tab',
                                onPressed: () => _createNewTab(h.url),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 14, color: Colors.white38),
                                tooltip: 'Delete Entry',
                                onPressed: () async {
                                  if (h.id != null) {
                                    await _persistenceRepo.deleteHistoryEntry(h.id!);
                                    await _refreshHistory();
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, "0")}:${dt.minute.toString().padLeft(2, "0")}';
  }

  // --- AI Gateway View (Phase 3) ---

  Future<bool> _showCloudConsentDialog(ExternalTransmissionDisclosure disclosure) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16181D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFD48B47), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_outlined, color: Color(0xFFD48B47)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cloud Transmission Consent',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HotTea guarantees explicit consent before any data leaves your machine. Please review what will be transmitted to the remote provider:',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1E27),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.dns_outlined, size: 14, color: Colors.white54),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Provider: ${disclosure.providerName}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Endpoint: ${disclosure.endpoint}',
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Model: ${disclosure.model}',
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Prompt Length: ${disclosure.promptCharacterCount} characters',
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (disclosure.hasResearchContext) ...[
                  Row(
                    children: [
                      const Icon(Icons.attach_file, size: 14, color: Color(0xFFD48B47)),
                      const SizedBox(width: 6),
                      Text(
                        'Attached Research Context (${disclosure.attachedPassages.length} passages):',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD48B47)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B1E27),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD48B47).withAlpha(60)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < disclosure.attachedPassages.length; i++) ...[
                          if (i > 0) const Divider(height: 12, color: Colors.white10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                disclosure.attachedPassages[i].title,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              if (disclosure.attachedPassages[i].sourceUrl != null)
                                Text(
                                  disclosure.attachedPassages[i].sourceUrl.toString(),
                                  style: const TextStyle(fontSize: 10, color: Color(0xFFD48B47)),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                disclosure.attachedPassages[i].excerpt,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Colors.white60),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Notice: Selected research passages will leave your device and be processed according to the provider\'s privacy policy.',
                    style: TextStyle(fontSize: 10, color: Colors.amberAccent),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.greenAccent.withAlpha(80)),
                    ),
                    child: const Text(
                      'No local research notes, browsing history, or browser cookies are included in this request.',
                      style: TextStyle(fontSize: 11, color: Colors.greenAccent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel Request', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD48B47),
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Authorize & Transmit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _showResearchNoteSelector() {
    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: const Color(0xFF16181D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_outlined, color: Color(0xFFD48B47), size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Select Research Notes for Context',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedNoteIdsForAi.clear();
                            _selectedEvidenceIdsForAi.clear();
                          });
                          setSheetState(() {});
                        },
                        child: const Text('Clear All', style: TextStyle(fontSize: 12, color: Colors.white60)),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                const Text(
                  'Only explicitly checked notes and evidence clippings will be transmitted to the AI provider.',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
                const SizedBox(height: 12),
                if (_notes.isEmpty && _evidenceList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No research notes or evidence clippings found. Clip passages while browsing first.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 12)),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: [
                        if (_evidenceList.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text('Evidence Clippings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD48B47))),
                          ),
                          ..._evidenceList.map((e) {
                            final eId = e.id;
                            final isSelected = eId != null && _selectedEvidenceIdsForAi.contains(eId);
                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: const Color(0xFFD48B47),
                              secondary: const Icon(Icons.format_quote, size: 16, color: Color(0xFFD48B47)),
                              title: Text(e.sourceTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                '"${e.passage}"',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.white70, fontStyle: FontStyle.italic),
                              ),
                              onChanged: (val) {
                                if (eId == null) return;
                                setState(() {
                                  if (val == true) {
                                    _selectedEvidenceIdsForAi.add(eId);
                                  } else {
                                    _selectedEvidenceIdsForAi.remove(eId);
                                  }
                                });
                                setSheetState(() {});
                              },
                            );
                          }),
                          const Divider(height: 16, color: Colors.white12),
                        ],
                        if (_notes.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text('Research Notes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFD48B47))),
                          ),
                          ..._notes.map((note) {
                            final noteId = note.id;
                            final isSelected = noteId != null && _selectedNoteIdsForAi.contains(noteId);
                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: const Color(0xFFD48B47),
                              secondary: const Icon(Icons.note_alt_outlined, size: 16, color: Colors.white60),
                              title: Text(note.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                note.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                              onChanged: (val) {
                                if (noteId == null) return;
                                setState(() {
                                  if (val == true) {
                                    _selectedNoteIdsForAi.add(noteId);
                                  } else {
                                    _selectedNoteIdsForAi.remove(noteId);
                                  }
                                });
                                setSheetState(() {});
                              },
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD48B47),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Done (${_selectedNoteIdsForAi.length + _selectedEvidenceIdsForAi.length} selected)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

  Future<void> _sendAiRequest() async {
    final prompt = _aiPromptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a prompt before sending.')),
      );
      return;
    }

    final attachedPassages = [
      ..._notes
          .where((n) => n.id != null && _selectedNoteIdsForAi.contains(n.id))
          .map((n) => ResearchContextReference(
                title: n.title,
                contentSnippet: n.content,
                sourceUrl: n.sourceUrl,
              )),
      ..._evidenceList
          .where((e) => e.id != null && _selectedEvidenceIdsForAi.contains(e.id))
          .map((e) => ResearchContextReference(
                title: '${e.sourceTitle} [Evidence]',
                contentSnippet: e.passage,
                sourceUrl: e.sourceUrl,
              )),
    ];

    final activeConfig = _aiGateway.activeConfig;
    final request = AiRequest.prompt(
      prompt: prompt,
      providerId: activeConfig.id,
      model: activeConfig.model,
      researchContext: attachedPassages,
    );

    final policy = AiConsentPolicy();
    final disclosure = policy.createDisclosure(config: activeConfig, request: request);

    if (disclosure.target == AiExecutionTarget.externalProvider) {
      final consentGiven = await _showCloudConsentDialog(disclosure);
      if (!consentGiven) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request cancelled. No data transmitted.')),
          );
        }
        return;
      }
    }

    setState(() {
      _isAiExecuting = true;
      _aiError = null;
      _lastAiResponse = null;
    });

    try {
      final response = await _aiGateway.complete(request, userConsentGiven: true);
      if (mounted) {
        setState(() {
          _lastAiResponse = response;
        });
      }
    } on AiProviderException catch (e) {
      if (mounted) {
        setState(() {
          _aiError = e.userMessage;
        });
      }
    } on LocalInferenceFailureException catch (e) {
      if (mounted) {
        setState(() {
          _aiError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiExecuting = false;
        });
      }
    }
  }

  void _cancelAiRequest() {
    _aiGateway.cancelCurrentRequest();
    setState(() {
      _isAiExecuting = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request cancelled.')),
    );
  }

  Future<void> _saveAiResponseAsNote(AiResponse response) async {
    final title = 'AI Research: ${_aiPromptController.text.trim()}';
    final content = response.text;
    final sourceUri = Uri.tryParse(_aiGateway.activeConfig.baseUrl);

    final created = await _persistenceRepo.createNote(
      title: title.length > 60 ? '${title.substring(0, 57)}...' : title,
      content: content,
      sourceUrl: sourceUri,
    );
    await _refreshNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI response saved to research notes (ID #${created.id}).')),
      );
    }
  }

  Widget _buildAiGatewayView() {
    final activeConfig = _aiGateway.activeConfig;
    final capability = _aiGateway.getCapability(activeConfig.id);
    final isLocal = activeConfig.isLocal;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Privacy & Target Status Banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLocal ? Colors.greenAccent.withAlpha(20) : const Color(0xFF1B1E27),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isLocal ? Colors.greenAccent.withAlpha(80) : const Color(0xFFD48B47).withAlpha(120),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isLocal ? Icons.security : Icons.cloud_outlined,
                    size: 16,
                    color: isLocal ? Colors.greenAccent : const Color(0xFFD48B47),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isLocal ? 'Local On-Device Execution Target' : 'Hosted Cloud Execution Target',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isLocal ? Colors.greenAccent : const Color(0xFFD48B47),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: capability.isAvailable ? Colors.green.withAlpha(40) : Colors.orange.withAlpha(40),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      capability.isAvailable ? 'Available' : 'Planned',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: capability.isAvailable ? Colors.greenAccent : Colors.orangeAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isLocal
                    ? 'Local inference engine is modelled and planned. It runs offline without internet access and will never silently redirect requests to cloud.'
                    : 'Requests connect directly to ${activeConfig.baseUrl} (${activeConfig.model}). Explicit consent is required before any data leaves your machine.',
                style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Provider Choice Chips
        const Text('Inference Provider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: _aiGateway.availableProviders.map((p) {
            final isSelected = p.id == activeConfig.id;
            final cap = _aiGateway.getCapability(p.id);
            return ChoiceChip(
              label: Text(
                '${p.name}${cap.isLocal ? ' (Planned)' : ''}',
                style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.white),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFFD48B47),
              backgroundColor: const Color(0xFF1B1E27),
              onSelected: (val) {
                if (val) {
                  setState(() {
                    _aiGateway.setActiveProvider(p.id);
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Research Context Attachment Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1E27),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.note_alt_outlined, size: 14, color: Color(0xFFD48B47)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Research Evidence (${_selectedNoteIdsForAi.length} attached)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _showResearchNoteSelector,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Select Notes', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Attach saved research passages as verified context. Source URLs are preserved for attribution.',
                style: TextStyle(fontSize: 10, color: Colors.white54),
              ),
              if (_selectedNoteIdsForAi.isNotEmpty || _selectedEvidenceIdsForAi.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ..._notes.where((n) => n.id != null && _selectedNoteIdsForAi.contains(n.id)).map((n) {
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.note_alt_outlined, size: 12),
                        label: Text(n.title, style: const TextStyle(fontSize: 11)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() {
                            _selectedNoteIdsForAi.remove(n.id);
                          });
                        },
                      );
                    }),
                    ..._evidenceList.where((e) => e.id != null && _selectedEvidenceIdsForAi.contains(e.id)).map((e) {
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.format_quote, size: 12, color: Color(0xFFD48B47)),
                        label: Text('${e.sourceTitle} (Evidence)', style: const TextStyle(fontSize: 11)),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() {
                            _selectedEvidenceIdsForAi.remove(e.id);
                          });
                        },
                      );
                    }),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Prompt Input
        const Text('AI Prompt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70)),
        const SizedBox(height: 6),
        TextField(
          controller: _aiPromptController,
          maxLines: 5,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter your research query or prompt...\nExample: "Synthesize the key points from the attached research passages regarding browser privacy."',
            hintStyle: const TextStyle(fontSize: 12, color: Colors.white38),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            filled: true,
            fillColor: const Color(0xFF1B1E27),
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),

        // Action Buttons Row
        Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD48B47),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _isAiExecuting ? null : _sendAiRequest,
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Send to AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            if (_isAiExecuting) ...[
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                onPressed: _cancelAiRequest,
                icon: const Icon(Icons.stop_circle_outlined, size: 16),
                label: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 12),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD48B47))),
              ),
            ] else ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _aiPromptController.clear();
                    _aiError = null;
                  });
                },
                child: const Text('Clear', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 18, color: Colors.white60),
              tooltip: 'Configure AI Settings',
              onPressed: () {
                setState(() {
                  _activeRightTab = 'settings';
                  _mobileBottomNavIndex = 4;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Error display
        if (_aiError != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.redAccent.withAlpha(120)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Request Failed',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _aiError!,
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14, color: Colors.white54),
                  onPressed: () => setState(() => _aiError = null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Response Card
        if (_lastAiResponse != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1E27),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD48B47).withAlpha(120)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 16, color: Color(0xFFD48B47)),
                        const SizedBox(width: 6),
                        Text(
                          'Response (${_lastAiResponse!.model})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Text(
                      '${_lastAiResponse!.duration.inMilliseconds}ms',
                      style: const TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                ),
                if (_lastAiResponse!.usage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Tokens: prompt ${_lastAiResponse!.usage!.promptTokens}, completion ${_lastAiResponse!.usage!.completionTokens}, total ${_lastAiResponse!.usage!.totalTokens}',
                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
                const Divider(height: 16, color: Colors.white12),
                SelectableText(
                  _lastAiResponse!.text,
                  style: const TextStyle(fontSize: 13, height: 1.5, color: Colors.white),
                ),
                if (_lastAiResponse!.sourceReferences.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Supplied Evidence Context (Not model-invented):',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD48B47)),
                  ),
                  const SizedBox(height: 4),
                  ..._lastAiResponse!.sourceReferences.map((ref) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• ${ref.title}${ref.sourceUrl != null ? ' (${ref.sourceUrl})' : ''}',
                          style: const TextStyle(fontSize: 10, color: Colors.white60),
                        ),
                      )),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _lastAiResponse!.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Response copied to clipboard.')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 14),
                      label: const Text('Copy', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD48B47),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _saveAiResponseAsNote(_lastAiResponse!),
                      icon: const Icon(Icons.bookmark_add_outlined, size: 14),
                      label: const Text('Clip to Notes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Privacy Policy Review Button
        Center(
          child: TextButton.icon(
            onPressed: _showPrivacyDisclosureDialog,
            icon: const Icon(Icons.shield_outlined, size: 14, color: Colors.white54),
            label: const Text('Review HotTea Privacy Guarantees', style: TextStyle(fontSize: 11, color: Colors.white54)),
          ),
        ),
      ],
    );
  }
}
