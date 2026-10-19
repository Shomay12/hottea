import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/core/persistence/in_memory_persistence_repository.dart';
import 'package:hottea/features/ai/data/ai_gateway_impl.dart';
import 'package:hottea/features/research/domain/evidence_entity.dart';
import 'package:hottea/features/research/domain/source_entity.dart';
import 'package:hottea/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  InMemoryPersistenceRepository createRepoWithEvidence() {
    final repo = InMemoryPersistenceRepository();

    final src = SourceEntity(
      id: 1,
      url: Uri.parse('https://example.com/local-ai'),
      title: 'Local-First AI Research Paper',
      canonicalUrl: Uri.parse('https://example.com/local-ai'),
      author: 'Prof. Alice Turing',
      publishedDate: '2026-03-15',
      headings: ['Executive Summary', 'Privacy Guarantees'],
      extractedText: 'On-device computation guarantees complete cryptographic data sovereignty.',
    );
    repo.saveSource(src);

    repo.saveEvidence(
      EvidenceEntity(
        id: 10,
        sourceId: 1,
        sourceUrl: Uri.parse('https://example.com/local-ai'),
        sourceTitle: 'Local-First AI Research Paper',
        passage: 'On-device computation guarantees complete cryptographic data sovereignty.',
        contextHeading: 'Privacy Guarantees',
        annotation: 'Fundamental premise for local privacy architecture.',
        tags: ['cryptography', 'local-first'],
        topic: 'AI Sovereignty',
      ),
    );

    return repo;
  }

  void configureDesktop(WidgetTester tester) {
    tester.view.physicalSize = const Size(1440 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  void configureMobile(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('Research Workspace UI Tests', () {
    testWidgets('Desktop: Renders Research Workspace with Evidence, Sources, and Notes tabs', (tester) async {
      configureDesktop(tester);
      final repo = createRepoWithEvidence();

      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        aiGateway: AiGatewayImpl(),
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      // Click 'Notes' tab in desktop right pane
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      // Verify sub-tabs
      expect(find.text('Evidence (1)'), findsOneWidget);
      expect(find.text('Sources (1)'), findsOneWidget);
      expect(find.text('Notes (0)'), findsOneWidget);

      // Verify Evidence card rendered
      expect(find.text('Local-First AI Research Paper'), findsWidgets);
      expect(find.textContaining('On-device computation guarantees complete cryptographic data sovereignty.'), findsOneWidget);
      expect(find.text('Topic: AI Sovereignty'), findsOneWidget);
      expect(find.text('#cryptography'), findsOneWidget);
      expect(find.text('#local-first'), findsOneWidget);
      expect(find.textContaining('Fundamental premise for local privacy architecture.'), findsOneWidget);
    });

    testWidgets('Desktop: Switches to Webpage Sources sub-tab and views source details', (tester) async {
      configureDesktop(tester);
      final repo = createRepoWithEvidence();

      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        aiGateway: AiGatewayImpl(),
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      // Switch to Sources subtab
      await tester.tap(find.text('Sources (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Local-First AI Research Paper'), findsOneWidget);
      expect(find.textContaining('https://example.com/local-ai'), findsWidgets);
      expect(find.textContaining('Prof. Alice Turing'), findsOneWidget);

      // Tap on Details & Headings to open Source Details modal
      await tester.tap(find.text('Details & Headings'));
      await tester.pumpAndSettle();

      expect(find.text('Webpage Source Details'), findsOneWidget);
      expect(find.textContaining('Prof. Alice Turing'), findsWidgets);
      expect(find.textContaining('Executive Summary'), findsOneWidget);
      expect(find.textContaining('Privacy Guarantees'), findsWidgets);
      expect(find.textContaining('On-device computation guarantees complete cryptographic data sovereignty.'), findsWidgets);

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Webpage Source Details'), findsNothing);
    });

    testWidgets('Desktop: Search filter narrows displayed evidence clippings', (tester) async {
      configureDesktop(tester);
      final repo = createRepoWithEvidence();

      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        aiGateway: AiGatewayImpl(),
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.textContaining('On-device computation guarantees'), findsOneWidget);

      // Find search field
      final searchFinder = find.widgetWithText(TextField, 'Search passages, annotations, or sources...');
      expect(searchFinder, findsOneWidget);

      // Search for non-matching query
      await tester.enterText(searchFinder, 'quantum computers');
      await tester.pumpAndSettle();

      expect(find.textContaining('On-device computation guarantees'), findsNothing);

      // Clear search
      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('On-device computation guarantees'), findsOneWidget);
    });

    testWidgets('Mobile: Research Workspace accessible via bottom navigation', (tester) async {
      configureMobile(tester);
      final repo = createRepoWithEvidence();

      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        aiGateway: AiGatewayImpl(),
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      // On mobile, open more actions menu
      final moreActions = find.byTooltip('More Actions');
      expect(moreActions, findsOneWidget);
      await tester.tap(moreActions);
      await tester.pumpAndSettle();

      // Tap Research Notes action chip
      final notesChip = find.text('Research Notes');
      expect(notesChip, findsOneWidget);
      await tester.tap(notesChip);
      await tester.pumpAndSettle();

      // Mobile secondary screen renders Research Workspace
      expect(find.text('Research Notes'), findsOneWidget);
      expect(find.text('Evidence (1)'), findsOneWidget);
      expect(find.text('Sources (1)'), findsOneWidget);
      expect(find.textContaining('On-device computation guarantees'), findsOneWidget);
    });
  });
}
