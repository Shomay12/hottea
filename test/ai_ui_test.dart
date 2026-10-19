import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/core/persistence/in_memory_persistence_repository.dart';
import 'package:hottea/features/ai/data/ai_gateway_impl.dart';
import 'package:hottea/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  InMemoryPersistenceRepository createRepoWithNote() {
    final repo = InMemoryPersistenceRepository();
    repo.createNote(
      title: 'Local First AI Architecture',
      content: 'Local inference ensures total offline privacy without remote leakage.',
      sourceUrl: Uri.parse('https://example.com/local-first'),
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

  group('AI Gateway UI & Privacy Consent Integration Tests', () {
    testWidgets('AI Workspace renders with provider, capability, and input fields on desktop', (tester) async {
      configureDesktop(tester);
      final mockPersistence = createRepoWithNote();
      final mockGateway = AiGatewayImpl();

      await tester.pumpWidget(
        HotTeaApp(
          persistenceRepository: mockPersistence,
          aiGateway: mockGateway,
          forceMockBrowser: true,
        ),
      );
      await tester.pumpAndSettle();

      // Click 'AI' tab in right desktop pane
      final aiTab = find.text('AI');
      expect(aiTab, findsOneWidget);
      await tester.tap(aiTab);
      await tester.pumpAndSettle();

      // Verify AI workspace elements
      expect(find.text('Hosted Cloud Execution Target'), findsOneWidget);
      expect(find.text('Inference Provider'), findsOneWidget);
      expect(find.text('AI Prompt'), findsOneWidget);
      expect(find.text('Send to AI'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('Local inference target shows Planned / Unavailable and throws without cloud fallback', (tester) async {
      configureDesktop(tester);
      final mockPersistence = createRepoWithNote();
      final mockGateway = AiGatewayImpl();

      await tester.pumpWidget(
        HotTeaApp(
          persistenceRepository: mockPersistence,
          aiGateway: mockGateway,
          forceMockBrowser: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI'));
      await tester.pumpAndSettle();

      // Select Local Runtime chip
      final localChip = find.text('Local Runtime Engine (Planned)');
      expect(localChip, findsOneWidget);
      await tester.tap(localChip);
      await tester.pumpAndSettle();

      expect(find.text('Local On-Device Execution Target'), findsOneWidget);

      // Enter prompt
      final promptField = find.widgetWithText(TextField, 'Enter your research query or prompt...\nExample: "Synthesize the key points from the attached research passages regarding browser privacy."');
      await tester.enterText(promptField, 'Test local privacy');
      await tester.pumpAndSettle();

      // Tap Send to AI
      await tester.tap(find.text('Send to AI'));
      await tester.pumpAndSettle();

      // Local runtime must fail explicitly without cloud fallback
      expect(find.text('AI Request Failed'), findsOneWidget);
      expect(find.textContaining('Local hardware inference runtime is not available'), findsOneWidget);
    });

    testWidgets('Cloud request triggers Explicit Cloud Consent dialog and cancels without network call', (tester) async {
      configureDesktop(tester);
      final mockPersistence = createRepoWithNote();
      bool networkCalled = false;

      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('{"choices":[{"message":{"content":"AI response text"}}]}', 200);
      });

      final mockGateway = AiGatewayImpl(client: mockClient);

      await tester.pumpWidget(
        HotTeaApp(
          persistenceRepository: mockPersistence,
          aiGateway: mockGateway,
          forceMockBrowser: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI'));
      await tester.pumpAndSettle();

      // Enter prompt
      final promptField = find.widgetWithText(TextField, 'Enter your research query or prompt...\nExample: "Synthesize the key points from the attached research passages regarding browser privacy."');
      await tester.enterText(promptField, 'Query about privacy');
      await tester.pumpAndSettle();

      // Tap Send to AI
      await tester.tap(find.text('Send to AI'));
      await tester.pumpAndSettle();

      // Consent dialog should be displayed
      expect(find.text('Cloud Transmission Consent'), findsOneWidget);
      expect(find.textContaining('HotTea guarantees explicit consent'), findsOneWidget);
      expect(find.text('Authorize & Transmit'), findsOneWidget);

      // Tap Cancel Request
      await tester.tap(find.text('Cancel Request'));
      await tester.pumpAndSettle();

      // Ensure no HTTP request was sent
      expect(networkCalled, isFalse);
      expect(find.text('Request cancelled. No data transmitted.'), findsOneWidget);
    });

    testWidgets('Authorized cloud request sends context and displays formatted response with attribution', (tester) async {
      configureDesktop(tester);
      final mockPersistence = createRepoWithNote();

      final mockClient = MockClient((request) async {
        return http.Response(
          '{"choices":[{"message":{"content":"Synthesized local-first architecture details."}}],"usage":{"prompt_tokens":42,"completion_tokens":18,"total_tokens":60}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final mockGateway = AiGatewayImpl(client: mockClient);
      mockGateway.updateProviderConfig(
        mockGateway.activeConfig.copyWith(apiKey: 'sk-test-key-12345'),
      );

      await tester.pumpWidget(
        HotTeaApp(
          persistenceRepository: mockPersistence,
          aiGateway: mockGateway,
          forceMockBrowser: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('AI'));
      await tester.pumpAndSettle();

      // Attach research note
      await tester.tap(find.text('Select Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Select Research Notes for Context'), findsOneWidget);
      final checkbox = find.byType(CheckboxListTile).first;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Done (1 selected)'));
      await tester.pumpAndSettle();

      expect(find.text('Local First AI Architecture'), findsWidgets);

      // Enter prompt
      final promptField = find.widgetWithText(TextField, 'Enter your research query or prompt...\nExample: "Synthesize the key points from the attached research passages regarding browser privacy."');
      await tester.enterText(promptField, 'Analyze the attached research note.');
      await tester.pumpAndSettle();

      // Tap Send to AI
      await tester.tap(find.text('Send to AI'));
      await tester.pumpAndSettle();

      // Consent dialog lists attached passages
      expect(find.text('Cloud Transmission Consent'), findsOneWidget);
      expect(find.textContaining('Attached Research Context (1 passages)'), findsOneWidget);

      // Authorize
      await tester.tap(find.text('Authorize & Transmit'));
      await tester.pumpAndSettle();

      // Response displayed
      expect(find.text('Synthesized local-first architecture details.'), findsOneWidget);
      expect(find.text('Tokens: prompt 42, completion 18, total 60'), findsOneWidget);
      expect(find.text('Supplied Evidence Context (Not model-invented):'), findsOneWidget);
      expect(find.text('Clip to Notes'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
    });

    testWidgets('Mobile action sheet opens AI Workspace navigation', (tester) async {
      configureMobile(tester);
      final mockPersistence = createRepoWithNote();
      final mockGateway = AiGatewayImpl();

      await tester.pumpWidget(
        HotTeaApp(
          persistenceRepository: mockPersistence,
          aiGateway: mockGateway,
          forceMockBrowser: true,
        ),
      );
      await tester.pumpAndSettle();

      // Open action sheet
      final menuButton = find.byTooltip('More Actions');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Tap AI Workspace chip
      final aiChip = find.text('AI Workspace');
      expect(aiChip, findsOneWidget);
      await tester.tap(aiChip);
      await tester.pumpAndSettle();

      // Verifies secondary mobile screen
      expect(find.text('AI Workspace'), findsWidgets);
      expect(find.text('Hosted Cloud Execution Target'), findsOneWidget);
    });
  });
}
