import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/config/app_privacy_policy.dart';
import 'features/browser/domain/browser_engine.dart';

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
  const HotTeaWorkspaceScreen({super.key});

  @override
  State<HotTeaWorkspaceScreen> createState() => _HotTeaWorkspaceScreenState();
}

class _HotTeaWorkspaceScreenState extends State<HotTeaWorkspaceScreen> {
  late final BrowserEngine _browserEngine;
  final TextEditingController _urlController = TextEditingController(
    text: 'https://docs.flutter.dev',
  );
  final TextEditingController _noteController = TextEditingController(
    text: '# Research Notes\n\n- HotTea local-first session initialized.\n- Zero external telemetry reported.\n- All research stored locally.',
  );

  bool _isRightPaneVisible = true;
  String _activeTab = 'notes'; // 'notes' or 'ai'

  @override
  void initState() {
    super.initState();
    _browserEngine = MockBrowserEngine(
      capabilities: _detectPlatformCapabilities(),
    );
    _browserEngine.initialize();
  }

  BrowserPlatformCapabilities _detectPlatformCapabilities() {
    final String platformName;
    if (kIsWeb) {
      platformName = 'Web Preview';
    } else {
      platformName = defaultTargetPlatform.name;
    }

    return BrowserPlatformCapabilities(
      platformName: platformName,
      renderMode: BrowserRenderMode.inlineWidget,
      supportsDomExtraction: true,
      supportsScriptInjection: true,
      supportsCookieIsolation: true,
      supportsInlineDevTools: false,
      underlyingEngineName: 'HotTea Modular Engine Adapter',
      license: 'Apache-2.0',
      notes: 'Initial abstraction layer decoupling UI from platform engine.',
    );
  }

  @override
  void dispose() {
    _browserEngine.dispose();
    _urlController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onNavigate() {
    final text = _urlController.text.trim();
    if (text.isNotEmpty) {
      final uri = Uri.tryParse(text.startsWith('http') ? text : 'https://$text');
      if (uri != null) {
        _browserEngine.loadUrl(uri);
      }
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
    final capabilities = _browserEngine.capabilities;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF16181D),
        elevation: 0,
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD48B47).withAlpha(40),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFD48B47).withAlpha(100)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.coffee, size: 18, color: Color(0xFFD48B47)),
                  SizedBox(width: 6),
                  Text(
                    'HotTea',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFFD48B47),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Address Bar
            Expanded(
              child: Container(
                height: 38,
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
                    prefixIcon: const Icon(Icons.lock_outline, size: 16, color: Colors.greenAccent),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward, size: 16),
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
            icon: const Icon(Icons.security, color: Colors.greenAccent),
            tooltip: 'Privacy Audit',
            onPressed: _showPrivacyDisclosureDialog,
          ),
          IconButton(
            icon: Icon(
              _isRightPaneVisible ? Icons.view_sidebar : Icons.view_sidebar_outlined,
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
      ),
      body: Row(
        children: [
          // Left Pane: Browser View & Capability Diagnostics
          Expanded(
            flex: _isRightPaneVisible ? 6 : 10,
            child: Container(
              color: const Color(0xFF0B0D11),
              child: Column(
                children: [
                  // Browser state bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF13161C),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 10, color: Colors.greenAccent),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Engine: ${capabilities.underlyingEngineName}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Platform: ${capabilities.platformName}',
                            style: const TextStyle(fontSize: 11, color: Colors.white60),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Browser content display area
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.public,
                              size: 48,
                              color: Color(0xFFD48B47),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Target URL: ${_urlController.text}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Browser engine integration is decoupled via BrowserEngine contract.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            Card(
                              color: const Color(0xFF1A1D24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Colors.white12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Active Integration Diagnostics:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('• Mode: ${capabilities.renderMode.name}'),
                                    Text('• DOM Extraction: ${capabilities.supportsDomExtraction ? "Supported" : "Unsupported"}'),
                                    Text('• Script Injection: ${capabilities.supportsScriptInjection ? "Supported" : "Unsupported"}'),
                                    Text('• License: ${capabilities.license}'),
                                    Text('• Telemetry: Disabled (Zero-telemetry policy)'),
                                  ],
                                ),
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
                              onTap: () => setState(() => _activeTab = 'notes'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _activeTab == 'notes'
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
                                      size: 16,
                                      color: _activeTab == 'notes'
                                          ? const Color(0xFFD48B47)
                                          : Colors.white54,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Notes',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _activeTab == 'notes'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _activeTab == 'notes'
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
                              onTap: () => setState(() => _activeTab = 'ai'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _activeTab == 'ai'
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
                                      size: 16,
                                      color: _activeTab == 'ai'
                                          ? const Color(0xFFD48B47)
                                          : Colors.white54,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AI Gateway',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _activeTab == 'ai'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _activeTab == 'ai'
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
                      child: _activeTab == 'notes'
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
