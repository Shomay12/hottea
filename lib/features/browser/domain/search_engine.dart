import 'package:flutter/foundation.dart';

/// Representation of a web search engine supported by HotTea.
///
/// All search URLs are constructed safely using Dart's [Uri] APIs
/// with proper percent-encoding of parameters to prevent injection or malformed requests.
@immutable
class SearchEngine {
  /// Unique identifier for settings persistence (e.g. 'google', 'duckduckgo').
  final String id;

  /// Display name shown in UI settings and address-bar badges.
  final String name;

  /// Provider homepage URL.
  final String homeUrl;

  /// Search endpoint template host and path.
  final String searchHost;
  final String searchPath;

  /// Query parameter key (e.g. 'q').
  final String queryParamKey;

  /// Additional fixed query parameters if required by the provider.
  final Map<String, String> additionalParams;

  /// Plain-language privacy disclosure explaining what data the external provider receives.
  final String privacyNotice;

  const SearchEngine({
    required this.id,
    required this.name,
    required this.homeUrl,
    required this.searchHost,
    required this.searchPath,
    this.queryParamKey = 'q',
    this.additionalParams = const {},
    required this.privacyNotice,
  });

  /// Returns [homeUrl] as a [Uri].
  Uri get homeUri => Uri.parse(homeUrl);

  /// Constructs a search [Uri] for [query] safely using standard query-parameter encoding.
  ///
  /// Examples:
  /// - Google: https://www.google.com/search?q=QUERY
  /// - DuckDuckGo: https://duckduckgo.com/?q=QUERY
  /// - Bing: https://www.bing.com/search?q=QUERY
  /// - Brave Search: https://search.brave.com/search?q=QUERY
  Uri buildSearchUri(String query) {
    final Map<String, String> params = {
      ...additionalParams,
      queryParamKey: query.trim(),
    };

    return Uri(
      scheme: 'https',
      host: searchHost,
      path: searchPath,
      queryParameters: params,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchEngine &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SearchEngine($name, id: $id)';
}

/// Provider-independent registry of available search engines.
///
/// Additional search engines can be registered at runtime without modifying UI code.
class SearchEngineRegistry {
  SearchEngineRegistry._();

  static const SearchEngine google = SearchEngine(
    id: 'google',
    name: 'Google',
    homeUrl: 'https://www.google.com',
    searchHost: 'www.google.com',
    searchPath: '/search',
    queryParamKey: 'q',
    privacyNotice:
        'Search requests connect directly to Google (google.com). Google receives your query and standard connection metadata (IP address, user-agent). HotTea does not route or log queries.',
  );

  static const SearchEngine duckDuckGo = SearchEngine(
    id: 'duckduckgo',
    name: 'DuckDuckGo',
    homeUrl: 'https://duckduckgo.com',
    searchHost: 'duckduckgo.com',
    searchPath: '/',
    queryParamKey: 'q',
    privacyNotice:
        'Search requests connect directly to DuckDuckGo (duckduckgo.com), which does not store personal search history or track users across the web.',
  );

  static const SearchEngine bing = SearchEngine(
    id: 'bing',
    name: 'Bing',
    homeUrl: 'https://www.bing.com',
    searchHost: 'www.bing.com',
    searchPath: '/search',
    queryParamKey: 'q',
    privacyNotice:
        'Search requests connect directly to Microsoft Bing (bing.com). Microsoft receives your search query and standard connection metadata.',
  );

  static const SearchEngine brave = SearchEngine(
    id: 'brave',
    name: 'Brave Search',
    homeUrl: 'https://search.brave.com',
    searchHost: 'search.brave.com',
    searchPath: '/search',
    queryParamKey: 'q',
    privacyNotice:
        'Search requests connect directly to Brave Search (search.brave.com), an independent, privacy-focused search index that does not track search queries.',
  );

  /// Standard list of search engines supported by default.
  static const List<SearchEngine> defaultEngines = [
    google,
    duckDuckGo,
    bing,
    brave,
  ];

  /// Default search engine for new installations.
  static const SearchEngine defaultEngine = google;

  static final Map<String, SearchEngine> _registeredEngines = {
    for (final engine in defaultEngines) engine.id: engine,
  };

  /// Registers an additional search engine.
  static void registerEngine(SearchEngine engine) {
    _registeredEngines[engine.id] = engine;
  }

  /// Returns all currently registered search engines.
  static List<SearchEngine> get availableEngines =>
      List.unmodifiable(_registeredEngines.values);

  /// Retrieves a search engine by its unique [id], falling back to [defaultEngine] if not found.
  static SearchEngine getById(String? id) {
    if (id == null) return defaultEngine;
    return _registeredEngines[id] ?? defaultEngine;
  }
}
