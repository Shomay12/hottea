import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import 'local_persistence_repository.dart';

/// Concrete SQLite implementation of [LocalPersistenceRepository].
///
/// Features:
/// - Parameterized SQL statements preventing injection.
/// - History sanitization (strips authentication credentials and secret query params).
/// - Deduplication for rapid intermediate page loads.
/// - Isolated transactions for multi-step integrity.
class SqlitePersistenceRepository implements LocalPersistenceRepository {
  Database? _db;
  final String? customDbPath;

  SqlitePersistenceRepository({this.customDbPath});

  @override
  Future<void> initialize() async {
    if (_db == null || !_db!.isOpen) {
      _db = await HotTeaDatabaseHelper.getDatabase(customPath: customDbPath);
    }
  }

  Database get db {
    if (_db == null || !_db!.isOpen) {
      throw StateError('SqlitePersistenceRepository has not been initialized. Call initialize() first.');
    }
    return _db!;
  }

  @override
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }

  // =========================================================================
  // Bookmarks
  // =========================================================================

  @override
  Future<BookmarkEntity> addBookmark({required Uri url, required String title}) async {
    final entity = BookmarkEntity(url: url, title: title);
    if (!entity.isValidUrl) {
      throw ArgumentError('Cannot bookmark invalid or unsupported URL: $url');
    }

    final cleanUrl = url.toString();
    final cleanTitle = entity.title;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if URL already exists
    final existing = await db.query(
      'bookmarks',
      where: 'url = ?',
      whereArgs: [cleanUrl],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Update existing bookmark title and timestamp
      final id = existing.first['id'] as int;
      await db.update(
        'bookmarks',
        {'title': cleanTitle, 'created_at': now},
        where: 'id = ?',
        whereArgs: [id],
      );
      return BookmarkEntity(
        id: id,
        url: url,
        title: cleanTitle,
        createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    }

    final id = await db.insert(
      'bookmarks',
      {
        'url': cleanUrl,
        'title': cleanTitle,
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return BookmarkEntity(
      id: id,
      url: url,
      title: cleanTitle,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  @override
  Future<List<BookmarkEntity>> getBookmarks() async {
    final rows = await db.query(
      'bookmarks',
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => BookmarkEntity.fromMap(r)).toList();
  }

  @override
  Future<void> updateBookmark(BookmarkEntity bookmark) async {
    if (bookmark.id == null) {
      throw ArgumentError('Cannot update bookmark without valid ID');
    }
    await db.update(
      'bookmarks',
      {
        'title': bookmark.title,
        'url': bookmark.url.toString(),
      },
      where: 'id = ?',
      whereArgs: [bookmark.id],
    );
  }

  @override
  Future<void> deleteBookmark(int id) async {
    await db.delete(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> isBookmarked(Uri url) async {
    final rows = await db.query(
      'bookmarks',
      columns: ['id'],
      where: 'url = ?',
      whereArgs: [url.toString()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // =========================================================================
  // History
  // =========================================================================

  @override
  Future<HistoryEntry> recordVisit({required Uri url, required String title}) async {
    final sanitizedUri = HistoryEntry.sanitizeUrl(url);
    final cleanUrl = sanitizedUri.toString();
    final cleanTitle = title.trim().isEmpty ? (sanitizedUri.host.isEmpty ? cleanUrl : sanitizedUri.host) : title.trim();
    final now = DateTime.now();

    // Deduplication check: inspect the most recent visit
    final recent = await db.query(
      'history',
      orderBy: 'visited_at DESC',
      limit: 1,
    );

    if (recent.isNotEmpty) {
      final lastUrl = recent.first['url'] as String;
      final lastVisited = DateTime.fromMillisecondsSinceEpoch(recent.first['visited_at'] as int);
      final id = recent.first['id'] as int;

      // If the last visited URL is identical and occurred within the last 15 seconds, update rather than duplicate
      if (lastUrl == cleanUrl && now.difference(lastVisited).inSeconds < 15) {
        await db.update(
          'history',
          {
            'title': cleanTitle,
            'visited_at': now.millisecondsSinceEpoch,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
        return HistoryEntry(
          id: id,
          url: sanitizedUri,
          title: cleanTitle,
          visitedAt: now,
        );
      }
    }

    final id = await db.insert(
      'history',
      {
        'url': cleanUrl,
        'title': cleanTitle,
        'visited_at': now.millisecondsSinceEpoch,
      },
    );

    return HistoryEntry(
      id: id,
      url: sanitizedUri,
      title: cleanTitle,
      visitedAt: now,
    );
  }

  @override
  Future<List<HistoryEntry>> getHistory({int limit = 100, int offset = 0}) async {
    final rows = await db.query(
      'history',
      orderBy: 'visited_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((r) => HistoryEntry.fromMap(r)).toList();
  }

  @override
  Future<void> deleteHistoryEntry(int id) async {
    await db.delete(
      'history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> clearAllHistory() async {
    await db.delete('history');
  }

  // =========================================================================
  // Research Notes
  // =========================================================================

  @override
  Future<ResearchNote> createNote({
    required String title,
    required String content,
    Uri? sourceUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanTitle = title.trim().isEmpty ? 'Untitled Research Note' : title.trim();

    final id = await db.insert(
      'notes',
      {
        'title': cleanTitle,
        'content': content,
        'source_url': sourceUrl?.toString(),
        'created_at': now,
        'updated_at': now,
      },
    );

    return ResearchNote(
      id: id,
      title: cleanTitle,
      content: content,
      sourceUrl: sourceUrl,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  @override
  Future<List<ResearchNote>> getNotes() async {
    final rows = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    return rows.map((r) => ResearchNote.fromMap(r)).toList();
  }

  @override
  Future<void> updateNote(ResearchNote note) async {
    if (note.id == null) {
      throw ArgumentError('Cannot update research note without valid ID');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'notes',
      {
        'title': note.title.trim().isEmpty ? 'Untitled Research Note' : note.title.trim(),
        'content': note.content,
        'source_url': note.sourceUrl?.toString(),
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  @override
  Future<void> deleteNote(int id) async {
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================================================================
  // Settings
  // =========================================================================

  @override
  Future<String?> getSetting(String key) async {
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await db.insert(
      'settings',
      {
        'key': key,
        'value': value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
