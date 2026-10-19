import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/core/persistence/in_memory_persistence_repository.dart';
import 'package:hottea/core/persistence/sqlite_persistence_repository.dart';
import 'package:hottea/features/research/data/webpage_extraction_service.dart';
import 'package:hottea/features/research/domain/evidence_entity.dart';
import 'package:hottea/features/research/domain/source_entity.dart';
import 'package:hottea/features/research/domain/webpage_extraction.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WebpageExtractionService & Parsing Tests', () {
    final service = WebpageExtractionService();

    test('Parses full extraction JSON payload with complete metadata', () {
      final jsonStr = '''
      {
        "status": "success",
        "title": "Local-First Software: You own your data",
        "url": "https://www.inkandswitch.com/local-first/",
        "canonicalUrl": "https://www.inkandswitch.com/local-first/",
        "author": "Martin Kleppmann et al.",
        "publishedDate": "2019-04-01",
        "headings": ["Introduction", "Seven ideals for local-first software", "Conclusion"],
        "readableText": "Cloud apps like Google Docs take ownership away from users. Local-first software restores user agency.",
        "selection": "Local-first software restores user agency."
      }
      ''';

      final result = service.parseExtractionPayload(
        jsonStr,
        currentUrl: Uri.parse('https://www.inkandswitch.com/local-first/'),
        fallbackTitle: 'Fallback',
      );
      expect(result.status, equals(WebpageExtractionStatus.success));
      expect(result.source?.title, equals('Local-First Software: You own your data'));
      expect(result.source?.url.toString(), equals('https://www.inkandswitch.com/local-first/'));
      expect(result.source?.canonicalUrl?.toString(), equals('https://www.inkandswitch.com/local-first/'));
      expect(result.source?.author, equals('Martin Kleppmann et al.'));
      expect(result.source?.publishedDate, equals('2019-04-01'));
      expect(result.source?.headings, hasLength(3));
      expect(result.source?.headings.first, equals('Introduction'));
      expect(result.source?.extractedText, contains('Cloud apps like Google Docs'));
      expect(result.activeSelection, equals('Local-first software restores user agency.'));
    });

    test('Parses extraction with missing optional metadata cleanly without crashing', () {
      final jsonStr = '''
      {
        "status": "success",
        "title": "Minimal Page",
        "url": "https://minimal.example.com",
        "readableText": "Just simple body text without meta tags."
      }
      ''';

      final result = service.parseExtractionPayload(
        jsonStr,
        currentUrl: Uri.parse('https://minimal.example.com'),
        fallbackTitle: 'Minimal Fallback',
      );
      expect(result.status, equals(WebpageExtractionStatus.success));
      expect(result.source?.title, equals('Minimal Page'));
      expect(result.source?.canonicalUrl, isNull);
      expect(result.source?.author, isNull);
      expect(result.source?.publishedDate, isNull);
      expect(result.source?.headings, isEmpty);
      expect(result.source?.extractedText, equals('Just simple body text without meta tags.'));
      expect(result.activeSelection, isNull);
    });

    test('Handles empty page and empty string extraction gracefully', () {
      final jsonStr = '''
      {
        "status": "success",
        "title": "",
        "readableText": ""
      }
      ''';

      final result = service.parseExtractionPayload(
        jsonStr,
        currentUrl: Uri.parse('https://empty.example.com'),
        fallbackTitle: 'Empty Fallback',
      );
      expect(result.status, equals(WebpageExtractionStatus.emptyContent));
      expect(result.errorMessage, contains('contained no readable text'));
    });

    test('Handles malformed JSON or script injection error gracefully', () {
      final malformed = '{ invalid json payload';
      final result = service.parseExtractionPayload(
        malformed,
        currentUrl: Uri.parse('https://error.example.com'),
        fallbackTitle: 'Error Fallback',
      );
      expect(result.status, equals(WebpageExtractionStatus.failed));
      expect(result.errorMessage, contains('Extraction result parsing failed'));

      final errorPayload = '{"error": "Blocked by CSP or iframe security policy"}';
      final errorResult = service.parseExtractionPayload(
        errorPayload,
        currentUrl: Uri.parse('https://csp.example.com'),
        fallbackTitle: 'CSP Fallback',
      );
      expect(errorResult.status, equals(WebpageExtractionStatus.failed));
      expect(errorResult.errorMessage, contains('Blocked by CSP or iframe security policy'));
    });

    test('Extraction script is valid JavaScript containing fallback meta tags and text cleaning', () {
      final script = WebpageExtractionService.domExtractorScript;
      expect(script, contains('window.getSelection()'));
      expect(script, contains('canonical'));
      expect(script, contains('author'));
      expect(script, contains('article:published_time'));
      expect(script, contains('h1, h2, h3'));
    });
  });

  group('SourceEntity and EvidenceEntity Domain Serialization Tests', () {
    test('SourceEntity converts to and from Map accurately', () {
      final source = SourceEntity(
        id: 42,
        url: Uri.parse('https://arxiv.org/abs/2301.00001'),
        title: 'Advances in Local Inference',
        canonicalUrl: Uri.parse('https://arxiv.org/abs/2301.00001'),
        author: 'Jane Doe',
        publishedDate: '2023-01-01',
        headings: ['Abstract', 'Architecture', 'Empirical Benchmarks'],
        extractedText: 'We present an on-device inference pipeline...',
        capturedAt: DateTime.utc(2026, 1, 15, 12, 0),
      );

      final map = source.toMap();
      expect(map['id'], equals(42));
      expect(map['url'], equals('https://arxiv.org/abs/2301.00001'));
      expect(map['headings'], equals('Abstract\nArchitecture\nEmpirical Benchmarks'));

      final restored = SourceEntity.fromMap(map);
      expect(restored.id, equals(42));
      expect(restored.url.toString(), equals('https://arxiv.org/abs/2301.00001'));
      expect(restored.title, equals('Advances in Local Inference'));
      expect(restored.author, equals('Jane Doe'));
      expect(restored.headings, equals(['Abstract', 'Architecture', 'Empirical Benchmarks']));
      expect(restored.extractedText, contains('on-device inference'));
    });

    test('EvidenceEntity converts to and from Map preserving verbatim passage and tags', () {
      final evidence = EvidenceEntity(
        id: 101,
        sourceId: 42,
        sourceUrl: Uri.parse('https://arxiv.org/abs/2301.00001'),
        sourceTitle: 'Advances in Local Inference',
        passage: 'Privacy is guaranteed by executing all weights locally.',
        contextHeading: 'Architecture',
        annotation: 'Key citation for chapter 2.',
        tags: ['privacy', 'local-first', 'benchmarks'],
        topic: 'AI Architecture',
        capturedAt: DateTime.utc(2026, 1, 15, 12, 30),
      );

      final map = evidence.toMap();
      expect(map['id'], equals(101));
      expect(map['source_id'], equals(42));
      expect(map['passage'], equals('Privacy is guaranteed by executing all weights locally.'));
      expect(map['context_heading'], equals('Architecture'));
      expect(map['tags'], equals('privacy,local-first,benchmarks'));

      final restored = EvidenceEntity.fromMap(map);
      expect(restored.id, equals(101));
      expect(restored.sourceId, equals(42));
      expect(restored.passage, equals('Privacy is guaranteed by executing all weights locally.'));
      expect(restored.contextHeading, equals('Architecture'));
      expect(restored.annotation, equals('Key citation for chapter 2.'));
      expect(restored.tags, equals(['privacy', 'local-first', 'benchmarks']));
      expect(restored.topic, equals('AI Architecture'));
    });

    test('EvidenceEntity tag parsing handles commas, whitespace, and nulls safely', () {
      final e1 = EvidenceEntity(
        sourceUrl: Uri.parse('https://example.com'),
        sourceTitle: 'Test',
        passage: 'Sample passage',
        tags: ['  tag1  ', 'tag2', ''],
      );
      expect(e1.tagsFormatted, equals('tag1, tag2'));

      final restoredFromRaw = EvidenceEntity.fromMap({
        'source_url': 'https://example.com',
        'source_title': 'Test',
        'passage': 'Sample passage',
        'tags': '  alpha ,  beta  , , gamma ',
        'captured_at': DateTime.now().millisecondsSinceEpoch,
      });
      expect(restoredFromRaw.tags, equals(['alpha', 'beta', 'gamma']));
    });
  });

  group('Persistence Repository Source & Evidence CRUD (In-Memory & SQLite)', () {
    test('In-memory repository source & evidence operations', () async {
      final repo = InMemoryPersistenceRepository();

      // Save source
      final src = await repo.saveSource(
        SourceEntity(
          url: Uri.parse('https://example.com/research'),
          title: 'Example Research',
          canonicalUrl: Uri.parse('https://example.com/canonical'),
          author: 'Dr. Smith',
          publishedDate: '2025-10-10',
          headings: ['Heading 1', 'Heading 2'],
          extractedText: 'Full extracted text of article...',
        ),
      );
      expect(src.id, isNotNull);

      // Duplicate URL lookup
      final existing = await repo.getSourceByUrl(Uri.parse('https://example.com/research'));
      expect(existing?.id, equals(src.id));
      expect(existing?.author, equals('Dr. Smith'));

      // Save evidence linked to source
      final ev = await repo.saveEvidence(
        EvidenceEntity(
          sourceId: src.id,
          sourceUrl: src.url,
          sourceTitle: src.title,
          passage: 'Verbatim captured quote.',
          contextHeading: 'Heading 1',
          annotation: 'User notes here',
          tags: ['security', 'offline'],
          topic: 'Cryptography',
        ),
      );
      expect(ev.id, isNotNull);
      expect(ev.passage, equals('Verbatim captured quote.'));

      // Retrieve all evidence
      var allEvidence = await repo.getEvidence();
      expect(allEvidence, hasLength(1));

      // Filter by topic
      final filteredTopic = await repo.getEvidence(topic: 'Cryptography');
      expect(filteredTopic, hasLength(1));
      final emptyTopic = await repo.getEvidence(topic: 'NonExistent');
      expect(emptyTopic, isEmpty);

      // Filter by query
      final filteredQuery = await repo.getEvidence(query: 'Verbatim');
      expect(filteredQuery, hasLength(1));
      final queryByTag = await repo.getEvidence(query: 'security');
      expect(queryByTag, hasLength(1));

      // Update annotation & tags
      final updated = ev.copyWith(
        annotation: 'Updated note text',
        tags: ['security', 'verified'],
      );
      await repo.updateEvidence(updated);
      final retrievedUpdated = await repo.getEvidence();
      expect(retrievedUpdated.first.annotation, equals('Updated note text'));
      expect(retrievedUpdated.first.tags, equals(['security', 'verified']));

      // Delete evidence
      await repo.deleteEvidence(ev.id!);
      expect(await repo.getEvidence(), isEmpty);

      // Delete source
      await repo.deleteSource(src.id!);
      expect(await repo.getSources(), isEmpty);
    });

    test('SQLite persistence repository schema v3 migration, sources and evidence CRUD', () async {
      final dbPath = inMemoryDatabasePath;
      final sqliteRepo = SqlitePersistenceRepository(customDbPath: dbPath);
      await sqliteRepo.initialize();

      // Save source in SQLite
      final src = await sqliteRepo.saveSource(
        SourceEntity(
          url: Uri.parse('https://sqlite.org/local-first'),
          title: 'Local First Storage in SQLite',
          canonicalUrl: Uri.parse('https://sqlite.org/local-first'),
          author: 'D. Richard Hipp',
          publishedDate: '2024-05-01',
          headings: ['ACID Properties', 'WAL Mode'],
          extractedText: 'SQLite is the most widely deployed database engine...',
        ),
      );
      expect(src.id, isNotNull);

      // Find source by URL
      final foundSrc = await sqliteRepo.getSourceByUrl(Uri.parse('https://sqlite.org/local-first'));
      expect(foundSrc, isNotNull);
      expect(foundSrc!.title, equals('Local First Storage in SQLite'));
      expect(foundSrc.headings, contains('ACID Properties'));

      // Save evidence in SQLite
      final ev = await sqliteRepo.saveEvidence(
        EvidenceEntity(
          sourceId: src.id,
          sourceUrl: src.url,
          sourceTitle: src.title,
          passage: 'SQLite is the most widely deployed database engine in the world.',
          contextHeading: 'WAL Mode',
          annotation: 'Crucial quote for persistence report.',
          tags: ['database', 'sqlite', 'local-first'],
          topic: 'Storage Architecture',
        ),
      );
      expect(ev.id, isNotNull);

      // Retrieve evidence list
      final list = await sqliteRepo.getEvidence();
      expect(list.any((e) => e.id == ev.id), isTrue);

      // Filter by query in SQLite
      final queryResults = await sqliteRepo.getEvidence(query: 'widely deployed');
      expect(queryResults.any((e) => e.id == ev.id), isTrue);

      // Update evidence
      final modEvidence = ev.copyWith(annotation: 'Verified against source documentation.');
      await sqliteRepo.updateEvidence(modEvidence);
      final updatedList = await sqliteRepo.getEvidence();
      final reloaded = updatedList.firstWhere((e) => e.id == ev.id);
      expect(reloaded.annotation, equals('Verified against source documentation.'));

      // Delete evidence & source
      await sqliteRepo.deleteEvidence(ev.id!);
      final afterDeleteEv = await sqliteRepo.getEvidence();
      expect(afterDeleteEv.any((e) => e.id == ev.id), isFalse);

      await sqliteRepo.deleteSource(src.id!);
      final afterDeleteSrc = await sqliteRepo.getSources();
      expect(afterDeleteSrc.any((s) => s.id == src.id), isFalse);
    });
  });
}
