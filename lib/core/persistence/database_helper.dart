import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Central database helper providing SQLite initialization, schema versioning,
/// and safe parameterized transactions across Web, Desktop, and Mobile.
class HotTeaDatabaseHelper {
  static const String databaseName = 'hottea_local_workspace.db';
  static const int databaseVersion = 3;

  static Database? _database;
  static bool _initializedPlatform = false;

  /// Initializes the appropriate SQLite database factory based on the platform.
  static void initPlatformDatabaseFactory() {
    if (_initializedPlatform) return;
    _initializedPlatform = true;

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// Opens or retrieves the shared application database.
  /// If [customPath] is provided (e.g. [inMemoryDatabasePath] in tests), opens a dedicated instance.
  static Future<Database> getDatabase({String? customPath}) async {
    initPlatformDatabaseFactory();

    if (customPath != null) {
      return await _openDb(customPath);
    }

    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final fullPath = '$dbPath/$databaseName';
    _database = await _openDb(fullPath);
    return _database!;
  }

  static Future<Database> _openDb(String path) async {
    return await openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  static Future<void> _onConfigure(Database db) async {
    // Enable foreign keys
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // 1. Bookmarks Table
    batch.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_bookmarks_created ON bookmarks (created_at DESC)');

    // 2. Browsing History Table
    batch.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        visited_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_history_visited ON history (visited_at DESC)');
    batch.execute('CREATE INDEX idx_history_url ON history (url)');

    // 3. Research Notes Table
    batch.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        source_url TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_notes_updated ON notes (updated_at DESC)');

    // 4. Settings Table
    batch.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 5. Webpage Sources Table
    batch.execute('''
      CREATE TABLE sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        canonical_url TEXT,
        author TEXT,
        published_date TEXT,
        headings TEXT,
        extracted_text TEXT,
        captured_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_sources_captured ON sources (captured_at DESC)');
    batch.execute('CREATE INDEX idx_sources_url ON sources (url)');

    // 6. Evidence Clippings Table
    batch.execute('''
      CREATE TABLE evidence (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_id INTEGER REFERENCES sources(id) ON DELETE SET NULL,
        source_url TEXT NOT NULL,
        source_title TEXT NOT NULL,
        passage TEXT NOT NULL,
        context_heading TEXT,
        annotation TEXT,
        tags TEXT,
        topic TEXT,
        captured_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_evidence_captured ON evidence (captured_at DESC)');
    batch.execute('CREATE INDEX idx_evidence_source_url ON evidence (source_url)');
    batch.execute('CREATE INDEX idx_evidence_topic ON evidence (topic)');

    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sources (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          url TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          canonical_url TEXT,
          author TEXT,
          published_date TEXT,
          headings TEXT,
          extracted_text TEXT,
          captured_at INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sources_captured ON sources (captured_at DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_sources_url ON sources (url)');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS evidence (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source_id INTEGER REFERENCES sources(id) ON DELETE SET NULL,
          source_url TEXT NOT NULL,
          source_title TEXT NOT NULL,
          passage TEXT NOT NULL,
          context_heading TEXT,
          annotation TEXT,
          tags TEXT,
          topic TEXT,
          captured_at INTEGER NOT NULL
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_evidence_captured ON evidence (captured_at DESC)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_evidence_source_url ON evidence (source_url)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_evidence_topic ON evidence (topic)');
    }
  }

  /// Closes the shared database connection safely.
  static Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
