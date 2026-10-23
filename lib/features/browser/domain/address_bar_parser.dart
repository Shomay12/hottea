import 'search_engine.dart';
import 'url_cleaner.dart';

/// The result classification for user input entered into the browser's address bar.
enum AddressBarInputType {
  /// Direct navigation to a valid web URL (e.g. https://flutter.dev or youtube.com).
  directNavigation,

  /// Web search query to be routed through the selected search engine.
  search,

  /// Explicit input using an unsupported or potentially dangerous scheme (e.g. javascript:, file:).
  unsupportedScheme,

  /// Input is empty or contains only whitespace.
  empty,
}

/// Structured outcome of parsing address bar input.
class AddressBarParseResult {
  final AddressBarInputType type;

  /// Target URL if [type] is [AddressBarInputType.directNavigation] or [AddressBarInputType.search].
  final Uri? targetUri;

  /// Original query string if [type] is [AddressBarInputType.search].
  final String? searchQuery;

  /// Error explanation if [type] is [AddressBarInputType.unsupportedScheme].
  final String? errorMessage;

  const AddressBarParseResult._({
    required this.type,
    this.targetUri,
    this.searchQuery,
    this.errorMessage,
  });

  factory AddressBarParseResult.directNavigation(Uri uri) {
    return AddressBarParseResult._(
      type: AddressBarInputType.directNavigation,
      targetUri: uri,
    );
  }

  factory AddressBarParseResult.search({
    required String query,
    required Uri searchUri,
  }) {
    return AddressBarParseResult._(
      type: AddressBarInputType.search,
      targetUri: searchUri,
      searchQuery: query,
    );
  }

  factory AddressBarParseResult.unsupportedScheme(String message) {
    return AddressBarParseResult._(
      type: AddressBarInputType.unsupportedScheme,
      errorMessage: message,
    );
  }

  factory AddressBarParseResult.empty() {
    return const AddressBarParseResult._(
      type: AddressBarInputType.empty,
    );
  }
}

/// Robust classifier that distinguishes web URLs, bare domains, unsupported schemes,
/// and natural-language search queries.
class AddressBarParser {
  AddressBarParser._();

  static final RegExp _hierarchicalSchemeRegex = RegExp(
    r'^([a-zA-Z][a-zA-Z0-9+.-]*):\/\/(.*)$',
  );

  static final RegExp _nonHierarchicalSchemeRegex = RegExp(
    r'^(javascript|about|data|blob|mailto|tel|file|chrome|edge|view-source):(.*)$',
    caseSensitive: false,
  );

  static final RegExp _ipv4Regex = RegExp(
    r'^(\d{1,3}\.){3}\d{1,3}(:\d+)?(\/.*)?$',
  );

  static final RegExp _localhostRegex = RegExp(
    r'^localhost(:\d+)?(\/.*)?$',
    caseSensitive: false,
  );

  // Valid domain label: alphanumeric, may contain interior hyphens.
  static final RegExp _domainLabelRegex = RegExp(
    r'^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$',
  );

  // Valid TLD: at least 2 alphabetical characters.
  static final RegExp _tldRegex = RegExp(
    r'^[a-zA-Z]{2,}$',
  );

  /// Classifies user [rawInput] and converts it to an [AddressBarParseResult].
  ///
  /// If the input is a search query, [engine] is used to construct the search URI.
  /// When [cleanUrls] is true, tracking parameters and AMP wrappers are removed.
  static AddressBarParseResult parse(
    String rawInput, {
    SearchEngine engine = SearchEngineRegistry.defaultEngine,
    bool cleanUrls = true,
  }) {
    final trimmed = rawInput.trim();

    // 1. Empty Check
    if (trimmed.isEmpty) {
      return AddressBarParseResult.empty();
    }

    // 2. Explicit Scheme Check
    // 2a. Hierarchical scheme (e.g. https://..., http://..., ftp://..., file://...)
    final hierarchicalMatch = _hierarchicalSchemeRegex.firstMatch(trimmed);
    if (hierarchicalMatch != null) {
      final scheme = hierarchicalMatch.group(1)!.toLowerCase();

      // Supported Web Schemes
      if (scheme == 'http' || scheme == 'https') {
        final parsed = Uri.tryParse(trimmed);
        if (parsed != null && parsed.hasAuthority && parsed.host.isNotEmpty) {
          final target = cleanUrls ? UrlCleaner.clean(parsed) : parsed;
          return AddressBarParseResult.directNavigation(target);
        } else {
          // Explicit http/https URL with malformed authority must NOT silently fall back to search.
          return AddressBarParseResult.unsupportedScheme(
            'Malformed URL "$trimmed". Please enter a valid web address.',
          );
        }
      }

      // Explicit about:blank if formatted with slashes
      if (scheme == 'about' && (trimmed == 'about://blank' || trimmed == 'about:///blank')) {
        return AddressBarParseResult.directNavigation(Uri.parse('about:blank'));
      }

      // Unsupported or dangerous schemes
      return AddressBarParseResult.unsupportedScheme(
        'Blocked unsupported scheme "$scheme:". HotTea only permits direct navigation to http:// and https:// URLs.',
      );
    }

    // 2b. Known non-hierarchical or special schemes (e.g. javascript:, about:, data:, mailto:, file:)
    final nonHierarchicalMatch = _nonHierarchicalSchemeRegex.firstMatch(trimmed);

    if (nonHierarchicalMatch != null) {
      final scheme = nonHierarchicalMatch.group(1)!.toLowerCase();
      if (scheme == 'about' && (trimmed == 'about:blank' || trimmed == 'about:')) {
        return AddressBarParseResult.directNavigation(Uri.parse('about:blank'));
      }

      return AddressBarParseResult.unsupportedScheme(
        'Blocked unsupported scheme "$scheme:". HotTea only permits direct navigation to http:// and https:// URLs.',
      );
    }

    // 3. Check for Whitespace: Valid hostnames cannot contain spaces
    if (trimmed.contains(RegExp(r'\s'))) {
      // Natural language questions or multiple words (e.g. "what is flutter.dev?", "Dr. Smith")
      return AddressBarParseResult.search(
        query: trimmed,
        searchUri: engine.buildSearchUri(trimmed),
      );
    }

    // 4. Check for Localhost (e.g. localhost, localhost:3000, localhost:8080/api)
    if (_localhostRegex.hasMatch(trimmed)) {
      final uri = Uri.tryParse('http://$trimmed');
      if (uri != null) {
        return AddressBarParseResult.directNavigation(uri);
      }
    }

    // 5. Check for IPv4 Address (e.g. 127.0.0.1, 192.168.1.1:8080)
    if (_ipv4Regex.hasMatch(trimmed)) {
      final uri = Uri.tryParse('http://$trimmed');
      if (uri != null) {
        return AddressBarParseResult.directNavigation(uri);
      }
    }

    // 6. Check for Valid Bare Domain (e.g. youtube.com, example.org/docs, sub.domain.co.uk)
    if (_isValidBareDomain(trimmed)) {
      final uri = Uri.tryParse('https://$trimmed');
      if (uri != null && uri.host.isNotEmpty) {
        return AddressBarParseResult.directNavigation(uri);
      }
    }

    // 7. Fallback to Search Engine
    return AddressBarParseResult.search(
      query: trimmed,
      searchUri: engine.buildSearchUri(trimmed),
    );
  }

  /// Evaluates whether [input] represents a valid bare domain or hostname with optional port and path.
  static bool _isValidBareDomain(String input) {
    // If the input ends with a question mark (e.g. "who.is?"), treat as question query unless has query params
    if (input.endsWith('?') && !input.contains('/')) {
      return false;
    }

    // Separate host:port from path/query/fragment
    String hostPort = input;
    final slashIndex = hostPort.indexOf('/');
    if (slashIndex != -1) {
      hostPort = hostPort.substring(0, slashIndex);
    }
    final questionIndex = hostPort.indexOf('?');
    if (questionIndex != -1) {
      hostPort = hostPort.substring(0, questionIndex);
    }

    // Strip optional port
    String host = hostPort;
    final colonIndex = host.lastIndexOf(':');
    if (colonIndex != -1) {
      final portStr = host.substring(colonIndex + 1);
      final port = int.tryParse(portStr);
      if (port == null || port <= 0 || port > 65535) {
        return false;
      }
      host = host.substring(0, colonIndex);
    }

    // Host must have at least one dot
    final labels = host.split('.');
    if (labels.length < 2) {
      return false;
    }

    // Check each label
    for (int i = 0; i < labels.length; i++) {
      final label = labels[i];
      if (label.isEmpty) {
        return false;
      }

      if (!_domainLabelRegex.hasMatch(label)) {
        return false;
      }
    }

    // TLD must be purely alphabetical and >= 2 characters
    final tld = labels.last;
    if (!_tldRegex.hasMatch(tld)) {
      return false;
    }

    return true;
  }
}
