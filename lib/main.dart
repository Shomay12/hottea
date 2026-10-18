import 'package:flutter/material.dart';
import 'core/config/app_privacy_policy.dart';
import 'features/browser/data/browser_engine_factory.dart';
import 'features/browser/domain/browser_tab.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HotTeaApp());
}

class HotTeaApp extends StatelessWidget {
  const HotTeaApp({super.key});

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
      home: const HotTeaWorkspaceScreen(),
    );
  }
}

class HotTeaWorkspaceScreen extends StatefulWidget {
  final bool forceMockBrowser;

  const HotTeaWorkspaceScreen({
    super.key,
    this.forceMockBrowser = false,
  });

  @override
  State<HotTeaWorkspaceScreen> createState() => _HotTeaWorkspaceScreenState();
}

class _HotTeaWorkspaceScreenState extends State<HotTeaWorkspaceScreen> {
  final List<BrowserTab> _tabs = [];
  int _activeTabIndex = 0;

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _noteController = TextEditingController(
    text: '# Research Notes\n\n- HotTea local-first session initialized.\n- Zero external telemetry reported.\n- All research stored locally.',
  );

  bool _isRightPaneVisible = true;
  String _activeRightTab = 'notes'; // 'notes' or 'ai'

  @override
  void initState() {
    super.initState();
    _createNewTab(Uri.parse('https://docs.flutter.dev'));
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
        if (mounted) setState(() {});
      },
    );

    setState(() {
      _tabs.add(tab);
      _activeTabIndex = _tabs.length - 1;
      _urlController.text = newUrl.toString();
    });
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
  }

  BrowserTab get _activeTab => _tabs[_activeTabIndex];

  @override
  void dispose() {
    for (final tab in _tabs) {
      tab.dispose();
    }
    _urlController.dispose();
    _noteController.dispose();
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

  void _clipActivePageToNotes() {
    final url = _activeTab.currentUrl?.toString() ?? 'unknown';
    final title = _activeTab.currentTitle.isEmpty ? url : _activeTab.currentTitle;
    final citation = '\n\n### Clipped: $title\n- URL: $url\n- Timestamp: ${DateTime.now().toIso8601String()}\n';
    setState(() {
      _noteController.text += citation;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Clipped page reference to local research notes.'),
        duration: Duration(seconds: 2),
      ),
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
            Text('2. Local inference never falls back to cloud without explicit prompt.'),
            SizedBox(height: 6),
            Text('3. Clear consent before any prompt or page context leaves this device.'),
            SizedBox(height: 6),
            Text('4. No hardcoded dependency on any single AI provider.'),
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

    // Keep urlController text synchronized if not actively editing
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

            // Address Bar
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
                    prefixIcon: const Icon(Icons.lock_outline, size: 15, color: Colors.greenAccent),
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
            // Right Pane: Local Research Workspace & AI Gateway Panel
            Expanded(
              flex: 4,
              child: Container(
                color: const Color(0xFF14171E),
                child: Column(
                  children: [
                    // Pane Tabs
                    Container(
                      color: const Color(0xFF1A1E26),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _activeRightTab = 'notes'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _activeRightTab == 'notes'
                                          ? const Color(0xFFD48B47)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.note_alt_outlined,
                                      size: 15,
                                      color: _activeRightTab == 'notes'
                                          ? const Color(0xFFD48B47)
                                          : Colors.white54,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Notes',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _activeRightTab == 'notes'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _activeRightTab == 'notes'
                                            ? Colors.white
                                            : Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _activeRightTab = 'ai'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _activeRightTab == 'ai'
                                          ? const Color(0xFFD48B47)
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_outlined,
                                      size: 15,
                                      color: _activeRightTab == 'ai'
                                          ? const Color(0xFFD48B47)
                                          : Colors.white54,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AI Gateway',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _activeRightTab == 'ai'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _activeRightTab == 'ai'
                                            ? Colors.white
                                            : Colors.white60,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _activeRightTab == 'notes'
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: TextField(
                                controller: _noteController,
                                maxLines: null,
                                expands: true,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Enter local research notes...',
                                  border: InputBorder.none,
                                ),
                              ),
                            )
                          : Padding(
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
                                  const Spacer(),
                                  OutlinedButton.icon(
                                    onPressed: _showPrivacyDisclosureDialog,
                                    icon: const Icon(Icons.info_outline, size: 16),
                                    label: const Text('Review Privacy Disclosure'),
                                  ),
                                ],
                              ),
                            ),
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
}
