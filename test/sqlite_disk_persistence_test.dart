import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hottea/core/persistence/sqlite_persistence_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hottea_disk_test_');
    dbPath = '${tempDir.path}/test_workspace.db';
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Verify SQLite persistence across simulated app restart and history clearing', () async {
    // 1. First app run: create bookmark, research note, and history visit
    final repo1 = SqlitePersistenceRepository(customDbPath: dbPath);
    await repo1.initialize();

    final bookmark = await repo1.addBookmark(
      url: Uri.parse('https://flutter.dev'),
      title: 'Flutter Dev Portal',
    );
    expect(bookmark.id, isNotNull);

    final note = await repo1.createNote(
      title: 'Offline Architecture Notes',
      content: 'Testing persistence across app restart',
      sourceUrl: Uri.parse('https://flutter.dev'),
    );
    expect(note.id, isNotNull);

    final historyEntry = await repo1.recordVisit(
      url: Uri.parse('https://flutter.dev/docs'),
      title: 'Flutter Documentation',
    );
    expect(historyEntry.id, isNotNull);

    // Close application completely
    await repo1.close();

    // 2. Second app run (simulating application restart): open new repository on the same disk database
    final repo2 = SqlitePersistenceRepository(customDbPath: dbPath);
    await repo2.initialize();

    // Verify bookmark persisted across restart
    final bookmarks = await repo2.getBookmarks();
    expect(bookmarks.length, equals(1));
    expect(bookmarks.first.url.toString(), equals('https://flutter.dev'));
    expect(bookmarks.first.title, equals('Flutter Dev Portal'));

    // Verify note persisted across restart
    final notes = await repo2.getNotes();
    expect(notes.length, equals(1));
    expect(notes.first.title, equals('Offline Architecture Notes'));
    expect(notes.first.content, equals('Testing persistence across app restart'));

    // Verify history persisted across restart
    final historyBefore = await repo2.getHistory();
    expect(historyBefore.length, equals(1));
    expect(historyBefore.first.url.toString(), equals('https://flutter.dev/docs'));

    // Verify history clearing
    await repo2.clearAllHistory();
    final historyAfter = await repo2.getHistory();
    expect(historyAfter, isEmpty);

    // Confirm bookmarks and notes remain intact after history is cleared
    final bookmarksAfter = await repo2.getBookmarks();
    expect(bookmarksAfter.length, equals(1));

    final notesAfter = await repo2.getNotes();
    expect(notesAfter.length, equals(1));

    await repo2.close();
  });
}
