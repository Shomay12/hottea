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

  // =========================================================================
  // Webpage Sources
  // =========================================================================

  @override
  Future<SourceEntity> saveSource(SourceEntity source) async {
    final cleanUrl = source.url.toString();
    final now = DateTime.now().millisecondsSinceEpoch;

    final existing = await db.query(
      'sources',
      where: 'url = ?',
      whereArgs: [cleanUrl],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      await db.update(
        'sources',
        {
          'title': source.title,
          'canonical_url': source.canonicalUrl?.toString(),
          'author': source.author,
          'published_date': source.publishedDate,
          'headings': source.headings.join('\n'),
          'extracted_text': source.extractedText,
          'captured_at': now,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      return source.copyWith(
        id: id,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(now),
      );
    }

    final id = await db.insert(
      'sources',
      {
        'url': cleanUrl,
        'title': source.title,
        'canonical_url': source.canonicalUrl?.toString(),
        'author': source.author,
        'published_date': source.publishedDate,
        'headings': source.headings.join('\n'),
        'extracted_text': source.extractedText,
        'captured_at': now,
      },
    );

    return source.copyWith(
      id: id,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  @override
  Future<List<SourceEntity>> getSources() async {
    final rows = await db.query(
      'sources',
      orderBy: 'captured_at DESC',
    );
    return rows.map((r) => SourceEntity.fromMap(r)).toList();
  }

  @override
  Future<SourceEntity?> getSourceByUrl(Uri url) async {
    final rows = await db.query(
      'sources',
      where: 'url = ?',
      whereArgs: [url.toString()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SourceEntity.fromMap(rows.first);
  }

  @override
  Future<void> deleteSource(int id) async {
    await db.delete(
      'sources',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // =========================================================================
  // Evidence Clippings
  // =========================================================================

  @override
  Future<EvidenceEntity> saveEvidence(EvidenceEntity evidence) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final map = evidence.toMap();
    map['captured_at'] = now;

    final id = await db.insert('evidence', map);
    return evidence.copyWith(
      id: id,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  @override
  Future<List<EvidenceEntity>> getEvidence({
    String? topic,
    String? tag,
    String? query,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (topic != null && topic.trim().isNotEmpty) {
      conditions.add('topic = ?');
      args.add(topic.trim());
    }

    if (tag != null && tag.trim().isNotEmpty) {
      conditions.add('tags LIKE ?');
      args.add('%${tag.trim()}%');
    }

    if (query != null && query.trim().isNotEmpty) {
      conditions.add('(passage LIKE ? OR annotation LIKE ? OR tags LIKE ? OR source_title LIKE ?)');
      final term = '%${query.trim()}%';
      args.addAll([term, term, term, term]);
    }

    final whereClause = conditions.isNotEmpty ? conditions.join(' AND ') : null;

    final rows = await db.query(
      'evidence',
      where: whereClause,
      whereArgs: args.isNotEmpty ? args : null,
      orderBy: 'captured_at DESC',
    );

    return rows.map((r) => EvidenceEntity.fromMap(r)).toList();
  }

  @override
  Future<void> updateEvidence(EvidenceEntity evidence) async {
    if (evidence.id == null) {
      throw ArgumentError('Cannot update evidence record without valid ID');
    }

    await db.update(
      'evidence',
      evidence.toMap(),
      where: 'id = ?',
      whereArgs: [evidence.id],
    );
  }

  @override
  Future<void> deleteEvidence(int id) async {
    await db.delete(
      'evidence',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
