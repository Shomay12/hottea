import 'package:flutter/material.dart';
import 'core/config/app_privacy_policy.dart';
import 'core/persistence/local_persistence_repository.dart';
import 'core/persistence/sqlite_persistence_repository.dart';
import 'features/browser/data/browser_engine_factory.dart';
import 'features/browser/domain/browser_tab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HotTeaApp());
}

class HotTeaApp extends StatelessWidget {
  final LocalPersistenceRepository? persistenceRepository;
  final bool forceMockBrowser;

  const HotTeaApp({
    super.key,
    this.persistenceRepository,
    this.forceMockBrowser = false,
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
      ),
    );
  }
}

class HotTeaWorkspaceScreen extends StatefulWidget {
  final bool forceMockBrowser;
  final LocalPersistenceRepository? persistenceRepository;

  const HotTeaWorkspaceScreen({
    super.key,
    this.forceMockBrowser = false,
    this.persistenceRepository,
  });

  @override
  State<HotTeaWorkspaceScreen> createState() => _HotTeaWorkspaceScreenState();
}

class _HotTeaWorkspaceScreenState extends State<HotTeaWorkspaceScreen> {
  late final LocalPersistenceRepository _persistenceRepo;
  bool _isRepoInitialized = false;

  final List<BrowserTab> _tabs = [];
  int _activeTabIndex = 0;

  final TextEditingController _urlController = TextEditingController();

  // Workspace Navigation State
  bool _isRightPaneVisible = true;
  String _activeRightTab = 'notes'; // 'notes', 'bookmarks', 'history', 'ai'

  // Bookmarks State
  List<BookmarkEntity> _bookmarks = [];
  bool _isCurrentUrlBookmarked = false;

  // History State
  List<HistoryEntry> _history = [];

  // Notes State
  List<ResearchNote> _notes = [];
  ResearchNote? _selectedNote;
  final TextEditingController _noteTitleController = TextEditingController();
  final TextEditingController _noteContentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _persistenceRepo = widget.persistenceRepository ?? SqlitePersistenceRepository();
    _initPersistenceAndLoad();
    _createNewTab(Uri.parse('https://docs.flutter.dev'));
  }

  Future<void> _initPersistenceAndLoad() async {
    try {
      await _persistenceRepo.initialize();
      if (mounted) {
        setState(() {
          _isRepoInitialized = true;
        });
        await _refreshBookmarks();
        await _refreshHistory();
        await _refreshNotes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database initialization error: $e')),
        );
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

  void _createNewTab([Uri? initialUrl]) {
    final newUrl = initialUrl ?? Uri.parse('https://docs.flutter.dev');
    final engine = BrowserEngineFactory.createEngine(
      initialUrl: newUrl,
      forceMock: widget.forceMockBrowser,
    );

    final tab = BrowserTab(
      id: 'tab_${DateTime.now().millisecondsSinceEpoch}_${_tabs.length}',
      engine: engine,
      initialUrl: newUrl,
      onStateChanged: () {
        if (mounted) {
          setState(() {});
          _checkCurrentUrlBookmarked();
          _recordHistoryIfCompleted();
        }
      },
    );

    setState(() {
      _tabs.add(tab);
      _activeTabIndex = _tabs.length - 1;
      _urlController.text = newUrl.toString();
    });
  }

  void _recordHistoryIfCompleted() {
    if (!_isRepoInitialized || _tabs.isEmpty) return;
    final tab = _activeTab;
    if (!tab.isLoading && tab.currentUrl != null && tab.currentUrl!.scheme != 'about') {
      _persistenceRepo.recordVisit(
        url: tab.currentUrl!,
        title: tab.currentTitle,
      ).then((_) => _refreshHistory()).catchError((_) {});
    }
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) return; // Keep at least one tab open

    final tabToClose = _tabs[index];
    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
      _urlController.text = _tabs[_activeTabIndex].currentUrl?.toString() ?? '';
    });
    tabToClose.dispose();
    _checkCurrentUrlBookmarked();
  }

  BrowserTab get _activeTab => _tabs[_activeTabIndex];

  @override
  void dispose() {
    for (final tab in _tabs) {
      tab.dispose();
    }
    _urlController.dispose();
    _noteTitleController.dispose();
    _noteContentController.dispose();
    _persistenceRepo.close();
    super.dispose();
  }

  void _onNavigate() {
    final text = _urlController.text.trim();
    if (text.isNotEmpty) {
      final uri = Uri.tryParse(text.startsWith('http://') || text.startsWith('https://') || text.startsWith('about:')
          ? text
          : 'https://$text');
      if (uri != null) {
        _activeTab.loadUrl(uri);
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final currentUrl = _activeTab.currentUrl;
    if (currentUrl == null || !_isRepoInitialized) return;

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
          title: _activeTab.currentTitle.isEmpty ? currentUrl.host : _activeTab.currentTitle,
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
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipped page to a new research note.'), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clip note: $e')),
      );
    }
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
            Text('4. Local inference never falls back to cloud without explicit prompt.'),
            SizedBox(height: 6),
            Text('5. Browser engine completely isolated from UI code.'),
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

  @override
  Widget build(BuildContext context) {
    final activeTab = _activeTab;
    final capabilities = activeTab.engine.capabilities;

    if (activeTab.currentUrl != null && _urlController.text != activeTab.currentUrl.toString()) {
      _urlController.text = activeTab.currentUrl.toString();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181D),
        elevation: 0,
        titleSpacing: 8,
        title: Row(
          children: [
            // Brand Chip
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

            // Navigation Controls: Back, Forward, Reload
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 18),
              tooltip: 'Back',
              onPressed: activeTab.canGoBack ? () => activeTab.goBack() : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 18),
              tooltip: 'Forward',
              onPressed: activeTab.canGoForward ? () => activeTab.goForward() : null,
            ),
            IconButton(
              icon: activeTab.isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD48B47)),
                    )
                  : const Icon(Icons.refresh, size: 18),
              tooltip: 'Reload',
              onPressed: () => activeTab.reload(),
            ),
            const SizedBox(width: 4),

            // Address Bar with Bookmark Star
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1115),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _urlController,
                  onSubmitted: (_) => _onNavigate(),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    prefixIcon: IconButton(
                      icon: Icon(
                        _isCurrentUrlBookmarked ? Icons.star : Icons.star_border,
                        size: 18,
                        color: _isCurrentUrlBookmarked ? Colors.amber : Colors.white54,
                      ),
                      tooltip: _isCurrentUrlBookmarked ? 'Remove Bookmark' : 'Bookmark Page',
                      onPressed: _toggleBookmark,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 15),
                      onPressed: _onNavigate,
                      tooltip: 'Navigate',
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
              // Tab strip
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
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _activeTabIndex = index;
                                _urlController.text = tab.currentUrl?.toString() ?? '';
                              });
                              _checkCurrentUrlBookmarked();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              constraints: const BoxConstraints(maxWidth: 160),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFF0B0D11) : Colors.transparent,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                border: Border(
                                  top: BorderSide(
                                    color: isActive ? const Color(0xFFD48B47) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      tab.currentTitle.isEmpty ? 'New Tab' : tab.currentTitle,
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
                  ],
                ),
              ),
              // Linear loading progress indicator
              if (activeTab.isLoading)
                LinearProgressIndicator(
                  value: activeTab.progress > 0 ? activeTab.progress : null,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD48B47)),
                )
              else
                const SizedBox(height: 2),
            ],
          ),
        ),
      ),
      body: Row(
        children: [
          // Left Pane: Browser Viewport & Navigation Error Banner
          Expanded(
            flex: _isRightPaneVisible ? 6 : 10,
            child: Container(
              color: const Color(0xFF0B0D11),
              child: Column(
                children: [
                  // Navigation error notification banner
                  if (activeTab.error != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      color: Colors.red.shade900.withAlpha(200),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Navigation Error: ${activeTab.error!.message}',
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            ),
                          ),
                          TextButton(
                            onPressed: () => activeTab.reload(),
                            child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 14, color: Colors.white),
                            onPressed: () => activeTab.clearError(),
                          ),
                        ],
                      ),
                    ),

                  // Engine capability info strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: const Color(0xFF13161C),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Engine: ${capabilities.underlyingEngineName}',
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
                      ],
                    ),
                  ),

                  // Actual Webpage Rendering Viewport
                  Expanded(
                    child: activeTab.engine.buildWidget(context),
                  ),
                ],
              ),
            ),
          ),

          if (_isRightPaneVisible) ...[
            const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
            // Right Pane: Local Research Workspace (Notes, Bookmarks, History, AI)
            Expanded(
              flex: 4,
              child: Container(
                color: const Color(0xFF14171E),
                child: Column(
                  children: [
                    // Pane Tabs Header
                    Container(
                      color: const Color(0xFF1A1E26),
                      child: Row(
                        children: [
                          _buildRightTabHeader('notes', Icons.note_alt_outlined, 'Notes'),
                          _buildRightTabHeader('bookmarks', Icons.bookmarks_outlined, 'Bookmarks'),
                          _buildRightTabHeader('history', Icons.history, 'History'),
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
      case 'ai':
        return _buildAiGatewayView();
      case 'notes':
      default:
        return _buildNotesView();
    }
  }

  // --- Research Notes View ---
  Widget _buildNotesView() {
    return Column(
      children: [
        // Notes Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0xFF161922),
          child: Row(
            children: [
              Text(
                'Notes (${_notes.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
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
        // Note list selector dropdown / pills
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
        // Active Note Editor
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

  // --- Bookmarks View ---
  Widget _buildBookmarksView() {
    if (_bookmarks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bookmarks_outlined, size: 36, color: Colors.white38),
              const SizedBox(height: 12),
              const Text(
                'No Bookmarks Saved',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
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
      );
    }

    return ListView.separated(
      itemCount: _bookmarks.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, index) {
        final b = _bookmarks[index];
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
              _activeTab.loadUrl(b.url);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid bookmark URL.')),
              );
            }
          },
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white38),
            onPressed: () async {
              if (b.id != null) {
                await _persistenceRepo.deleteBookmark(b.id!);
                await _refreshBookmarks();
              }
            },
          ),
        );
      },
    );
  }

  // --- Browsing History View ---
  Widget _buildHistoryView() {
    return Column(
      children: [
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
              : ListView.separated(
                  itemCount: _history.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final h = _history[index];
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
                      onTap: () => _activeTab.loadUrl(h.url),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 14, color: Colors.white38),
                        onPressed: () async {
                          if (h.id != null) {
                            await _persistenceRepo.deleteHistoryEntry(h.id!);
                            await _refreshHistory();
                          }
                        },
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

  // --- AI Gateway View ---
  Widget _buildAiGatewayView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield, size: 16, color: Colors.greenAccent),
              const SizedBox(width: 6),
              Text(
                'Privacy Boundary Active',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.greenAccent.shade200,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orangeAccent.withAlpha(80)),
            ),
            child: const Text(
              'Requirement: Local inference must never silently fall back to cloud. No external provider configured.',
              style: TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Local Storage Guarantees:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text('• Bookmarks and notes stored in local SQLite database.'),
          const Text('• History query parameters automatically sanitized.'),
          const Text('• Zero cloud sync or telemetry.'),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _showPrivacyDisclosureDialog,
            icon: const Icon(Icons.info_outline, size: 16),
            label: const Text('Review Privacy Disclosure'),
          ),
        ],
      ),
    );
  }
}
