/// Domain entity representing a user-saved bookmark.
class BookmarkEntity {
  final int? id;
  final Uri url;
  final String title;
  final DateTime createdAt;

  BookmarkEntity({
    this.id,
    required this.url,
    required this.title,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Validates whether the bookmark URL is safe and navigable.
  bool get isValidUrl {
    return (url.scheme == 'http' || url.scheme == 'https' || url.scheme == 'about') &&
        (url.host.isNotEmpty || url.scheme == 'about');
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'url': url.toString(),
      'title': title.trim().isEmpty ? (url.host.isEmpty ? url.toString() : url.host) : title.trim(),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory BookmarkEntity.fromMap(Map<String, dynamic> map) {
    return BookmarkEntity(
      id: map['id'] as int?,
      url: Uri.parse(map['url'] as String),
      title: map['title'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  BookmarkEntity copyWith({
    int? id,
    Uri? url,
    String? title,
    DateTime? createdAt,
  }) {
    return BookmarkEntity(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Domain entity representing a single recorded browsing visit.
class HistoryEntry {
  final int? id;
  final Uri url;
  final String title;
  final DateTime visitedAt;

  HistoryEntry({
    this.id,
    required this.url,
    required this.title,
    DateTime? visitedAt,
  }) : visitedAt = visitedAt ?? DateTime.now();

  /// Removes sensitive authentication credentials and secret query parameters from the URL
  /// before it is committed to local history storage.
  static Uri sanitizeUrl(Uri raw) {
    // 1. Strip userinfo (username:password)
    final cleanUserInfo = '';

    // 2. Filter sensitive query parameters
    final sensitiveKeys = {
      'token',
      'access_token',
      'id_token',
      'auth',
      'authorization',
      'key',
      'apikey',
      'api_key',
      'secret',
      'password',
      'pwd',
      'code',
      'jwt',
      'session',
      'session_id',
    };

    final filteredParams = Map<String, String>.from(raw.queryParameters)
      ..removeWhere((key, _) => sensitiveKeys.contains(key.toLowerCase()));

    return raw.replace(
      userInfo: cleanUserInfo,
      queryParameters: filteredParams.isEmpty ? null : filteredParams,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'url': sanitizeUrl(url).toString(),
      'title': title.trim().isEmpty ? (url.host.isEmpty ? url.toString() : url.host) : title.trim(),
      'visited_at': visitedAt.millisecondsSinceEpoch,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map['id'] as int?,
      url: Uri.parse(map['url'] as String),
      title: map['title'] as String,
      visitedAt: DateTime.fromMillisecondsSinceEpoch(map['visited_at'] as int),
    );
  }
}

/// Domain entity representing an offline research note created by the user.
class ResearchNote {
  final int? id;
  final String title;
  final String content;
  final Uri? sourceUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  ResearchNote({
    this.id,
    required this.title,
    required this.content,
    this.sourceUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title.trim().isEmpty ? 'Untitled Research Note' : title.trim(),
      'content': content,
      'source_url': sourceUrl?.toString(),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory ResearchNote.fromMap(Map<String, dynamic> map) {
    return ResearchNote(
      id: map['id'] as int?,
      title: map['title'] as String,
      content: map['content'] as String,
      sourceUrl: map['source_url'] != null ? Uri.tryParse(map['source_url'] as String) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  ResearchNote copyWith({
    int? id,
    String? title,
    String? content,
    Uri? sourceUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ResearchNote(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Contract defining local storage operations for Bookmarks, History, and Research Notes.
abstract class LocalPersistenceRepository {
  /// Initializes the local database connection.
  Future<void> initialize();

  /// Closes database connection.
  Future<void> close();

  // --- Bookmarks Operations ---
  /// Adds a bookmark. If the URL already exists, returns the existing or updated record.
  Future<BookmarkEntity> addBookmark({required Uri url, required String title});

  /// Retrieves all bookmarks sorted by creation time (most recent first).
  Future<List<BookmarkEntity>> getBookmarks();

  /// Updates an existing bookmark.
  Future<void> updateBookmark(BookmarkEntity bookmark);

  /// Deletes a bookmark by ID.
  Future<void> deleteBookmark(int id);

  /// Checks if a given URL is currently bookmarked.
  Future<bool> isBookmarked(Uri url);

  // --- History Operations ---
  /// Records a successful navigation visit.
  /// Deduplicates immediate rapid loads to the exact same URL within a short window.
  Future<HistoryEntry> recordVisit({required Uri url, required String title});

  /// Retrieves browsing history with pagination.
  Future<List<HistoryEntry>> getHistory({int limit = 100, int offset = 0});

  /// Deletes a specific history record by ID.
  Future<void> deleteHistoryEntry(int id);

  /// Clears the entire browsing history.
  Future<void> clearAllHistory();

  // --- Research Notes Operations ---
  /// Creates a new research note.
  Future<ResearchNote> createNote({
    required String title,
    required String content,
    Uri? sourceUrl,
  });

  /// Retrieves all research notes sorted by update timestamp.
  Future<List<ResearchNote>> getNotes();

  /// Updates an existing research note.
  Future<void> updateNote(ResearchNote note);

  /// Deletes a research note by ID.
  Future<void> deleteNote(int id);
}
