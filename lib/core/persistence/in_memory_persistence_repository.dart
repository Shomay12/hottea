import 'local_persistence_repository.dart';

/// In-memory implementation of [LocalPersistenceRepository].
/// Ideal for widget tests, ephemeral headless test runs, and fallback environments.
class InMemoryPersistenceRepository implements LocalPersistenceRepository {
  final Map<int, BookmarkEntity> _bookmarks = {};
  final List<HistoryEntry> _history = [];
  final Map<int, ResearchNote> _notes = {};

  int _nextBookmarkId = 1;
  int _nextHistoryId = 1;
  int _nextNoteId = 1;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<BookmarkEntity> addBookmark({required Uri url, required String title}) async {
    final entity = BookmarkEntity(url: url, title: title);
    if (!entity.isValidUrl) {
      throw ArgumentError('Cannot bookmark invalid or unsupported URL: $url');
    }

    final cleanUrl = url.toString();
    final existingId = _bookmarks.keys.cast<int?>().firstWhere(
          (k) => _bookmarks[k]?.url.toString() == cleanUrl,
          orElse: () => null,
        );

    if (existingId != null) {
      final updated = _bookmarks[existingId]!.copyWith(title: title);
      _bookmarks[existingId] = updated;
      return updated;
    }

    final id = _nextBookmarkId++;
    final created = BookmarkEntity(
      id: id,
      url: url,
      title: title.isEmpty ? (url.host.isEmpty ? cleanUrl : url.host) : title,
      createdAt: DateTime.now(),
    );
    _bookmarks[id] = created;
    return created;
  }

  @override
  Future<List<BookmarkEntity>> getBookmarks() async {
    final list = _bookmarks.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<void> updateBookmark(BookmarkEntity bookmark) async {
    if (bookmark.id == null || !_bookmarks.containsKey(bookmark.id)) {
      throw ArgumentError('Cannot update bookmark without existing ID');
    }
    _bookmarks[bookmark.id!] = bookmark;
  }

  @override
  Future<void> deleteBookmark(int id) async {
    _bookmarks.remove(id);
  }

  @override
  Future<bool> isBookmarked(Uri url) async {
    final cleanUrl = url.toString();
    return _bookmarks.values.any((b) => b.url.toString() == cleanUrl);
  }

  @override
  Future<HistoryEntry> recordVisit({required Uri url, required String title}) async {
    final sanitized = HistoryEntry.sanitizeUrl(url);
    final now = DateTime.now();
    final cleanTitle = title.isEmpty ? (sanitized.host.isEmpty ? sanitized.toString() : sanitized.host) : title;

    if (_history.isNotEmpty) {
      final last = _history.first;
      if (last.url.toString() == sanitized.toString() && now.difference(last.visitedAt).inSeconds < 15) {
        final updated = HistoryEntry(
          id: last.id,
          url: sanitized,
          title: cleanTitle,
          visitedAt: now,
        );
        _history[0] = updated;
        return updated;
      }
    }

    final entry = HistoryEntry(
      id: _nextHistoryId++,
      url: sanitized,
      title: cleanTitle,
      visitedAt: now,
    );
    _history.insert(0, entry);
    return entry;
  }

  @override
  Future<List<HistoryEntry>> getHistory({int limit = 100, int offset = 0}) async {
    if (offset >= _history.length) return [];
    final end = (offset + limit) > _history.length ? _history.length : offset + limit;
    return _history.sublist(offset, end);
  }

  @override
  Future<void> deleteHistoryEntry(int id) async {
    _history.removeWhere((h) => h.id == id);
  }

  @override
  Future<void> clearAllHistory() async {
    _history.clear();
  }

  @override
  Future<ResearchNote> createNote({
    required String title,
    required String content,
    Uri? sourceUrl,
  }) async {
    final id = _nextNoteId++;
    final note = ResearchNote(
      id: id,
      title: title.isEmpty ? 'Untitled Research Note' : title,
      content: content,
      sourceUrl: sourceUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _notes[id] = note;
    return note;
  }

  @override
  Future<List<ResearchNote>> getNotes() async {
    final list = _notes.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<void> updateNote(ResearchNote note) async {
    if (note.id == null || !_notes.containsKey(note.id)) {
      throw ArgumentError('Cannot update note without existing ID');
    }
    _notes[note.id!] = note;
  }

  @override
  Future<void> deleteNote(int id) async {
    _notes.remove(id);
  }
}
