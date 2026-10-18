import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/core/persistence/local_persistence_repository.dart';
import 'package:hottea/core/persistence/sqlite_persistence_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Bookmarks CRUD & Validation Tests', () {
    late LocalPersistenceRepository repo;
    late String testDbPath;

    setUp(() async {
      testDbPath = '${Directory.systemTemp.path}/test_bookmarks_${DateTime.now().microsecondsSinceEpoch}.db';
      repo = SqlitePersistenceRepository(customDbPath: testDbPath);
      await repo.initialize();
    });

    tearDown(() async {
      await repo.close();
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('Add, list, update, and delete bookmarks', () async {
      // 1. Add Bookmark
      final b1 = await repo.addBookmark(
        url: Uri.parse('https://flutter.dev'),
        title: 'Flutter Official Site',
      );
      expect(b1.id, isNotNull);
      expect(b1.url, Uri.parse('https://flutter.dev'));

      // 2. Check isBookmarked
      expect(await repo.isBookmarked(Uri.parse('https://flutter.dev')), isTrue);
      expect(await repo.isBookmarked(Uri.parse('https://dart.dev')), isFalse);

      // 3. List Bookmarks
      final list1 = await repo.getBookmarks();
      expect(list1.length, 1);
      expect(list1.first.title, 'Flutter Official Site');

      // 4. Update Bookmark
      final updatedB1 = b1.copyWith(title: 'Flutter Developer Portal');
      await repo.updateBookmark(updatedB1);

      final list2 = await repo.getBookmarks();
      expect(list2.first.title, 'Flutter Developer Portal');

      // 5. Delete Bookmark
      await repo.deleteBookmark(b1.id!);
      expect(await repo.isBookmarked(Uri.parse('https://flutter.dev')), isFalse);
      expect((await repo.getBookmarks()).isEmpty, isTrue);
    });

    test('Reject invalid bookmark URLs', () async {
      expect(
        () => repo.addBookmark(
          url: Uri.parse('javascript:alert(1)'),
          title: 'Exploit script',
        ),
        throwsArgumentError,
      );
    });

    test('Prevent duplicate URLs by updating existing entry', () async {
      await repo.addBookmark(
        url: Uri.parse('https://news.ycombinator.com'),
        title: 'Hacker News',
      );

      // Re-adding same URL with updated title
      final second = await repo.addBookmark(
        url: Uri.parse('https://news.ycombinator.com'),
        title: 'HN Frontpage',
      );

      final all = await repo.getBookmarks();
      expect(all.length, 1);
      expect(all.first.id, second.id);
      expect(all.first.title, 'HN Frontpage');
    });
  });

  group('Browsing History & Privacy Sanitization Tests', () {
    late LocalPersistenceRepository repo;
    late String testDbPath;

    setUp(() async {
      testDbPath = '${Directory.systemTemp.path}/test_history_${DateTime.now().microsecondsSinceEpoch}.db';
      repo = SqlitePersistenceRepository(customDbPath: testDbPath);
      await repo.initialize();
    });

    tearDown(() async {
      await repo.close();
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('Record visit and sanitize passwords/tokens', () async {
      // URL with user:password and access_token query param
      final dirtyUri = Uri.parse('https://admin:secretPass123@example.com/dashboard?token=xyz_jwt_token_999&page=1&auth=bearer_abc');
      
      final entry = await repo.recordVisit(url: dirtyUri, title: 'Dashboard');

      // Verify that userinfo and sensitive token query params were stripped
      expect(entry.url.userInfo, isEmpty);
      expect(entry.url.queryParameters.containsKey('token'), isFalse);
      expect(entry.url.queryParameters.containsKey('auth'), isFalse);
      expect(entry.url.queryParameters['page'], '1'); // Non-sensitive query parameters preserved

      final history = await repo.getHistory();
      expect(history.length, 1);
      expect(history.first.url.toString(), 'https://example.com/dashboard?page=1');
    });

    test('Deduplicate rapid intermediate loading events to same URL', () async {
      final testUrl = Uri.parse('https://dart.dev/guides');

      // Rapidly record 3 visits within 1 second
      await repo.recordVisit(url: testUrl, title: 'Dart Guides');
      await repo.recordVisit(url: testUrl, title: 'Dart Guides - Loading');
      await repo.recordVisit(url: testUrl, title: 'Dart Guides - Completed');

      final history = await repo.getHistory();
      // Should coalesce into 1 record with latest title
      expect(history.length, 1);
      expect(history.first.title, 'Dart Guides - Completed');
    });

    test('Clear all history', () async {
      await repo.recordVisit(url: Uri.parse('https://site1.org'), title: 'Site 1');
      await repo.recordVisit(url: Uri.parse('https://site2.org'), title: 'Site 2');

      expect((await repo.getHistory()).length, 2);

      await repo.clearAllHistory();
      expect((await repo.getHistory()).isEmpty, isTrue);
    });
  });

  group('Research Notes CRUD & Reinitialization Persistence Tests', () {
    late String testDbPath;

    setUp(() {
      testDbPath = '${Directory.systemTemp.path}/test_notes_${DateTime.now().microsecondsSinceEpoch}.db';
    });

    tearDown(() async {
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('Create, edit, delete notes and persist across repo reinitialization', () async {
      // 1. First session
      var repo1 = SqlitePersistenceRepository(customDbPath: testDbPath);
      await repo1.initialize();

      final note = await repo1.createNote(
        title: 'Quantum Computing Notes',
        content: 'Exploration of Shor\'s algorithm.',
        sourceUrl: Uri.parse('https://arxiv.org/abs/quant-ph/00000'),
      );
      expect(note.id, isNotNull);
      expect(note.sourceUrl, isNotNull);

      await repo1.close();

      // 2. Second session (simulating app restart)
      var repo2 = SqlitePersistenceRepository(customDbPath: testDbPath);
      await repo2.initialize();

      final notes = await repo2.getNotes();
      expect(notes.length, 1);
      expect(notes.first.title, 'Quantum Computing Notes');
      expect(notes.first.content, 'Exploration of Shor\'s algorithm.');

      // 3. Update note
      final updated = notes.first.copyWith(content: 'Updated with NISQ details.');
      await repo2.updateNote(updated);

      final reloaded = await repo2.getNotes();
      expect(reloaded.first.content, 'Updated with NISQ details.');

      // 4. Delete note
      await repo2.deleteNote(notes.first.id!);
      expect((await repo2.getNotes()).isEmpty, isTrue);

      await repo2.close();
    });
  });
}
