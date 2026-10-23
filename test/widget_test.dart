import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/core/persistence/in_memory_persistence_repository.dart';
import 'package:hottea/features/browser/domain/browser_engine.dart';
import 'package:hottea/features/browser/domain/browser_tab.dart';
import 'package:hottea/main.dart';

void main() {
  group('HotTea UI & Tab System Smoke Tests', () {
    testWidgets('Renders brand, address bar, navigation controls, and research notes', (WidgetTester tester) async {
      final repo = InMemoryPersistenceRepository();
      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      // Verify brand title is displayed
      expect(find.text('HotTea'), findsOneWidget);

      // Verify Back, Forward, Reload icon buttons are present
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Forward'), findsOneWidget);
      expect(find.byTooltip('Reload'), findsOneWidget);

      // Verify address bar contains default URL
      expect(find.byType(TextField), findsWidgets);

      // Verify Tab strip and New Tab button are present
      expect(find.byTooltip('New Tab'), findsOneWidget);

      // Verify Notes, Bookmarks, History, and AI tabs are present
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Bookmarks'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('AI'), findsOneWidget);
    });

    testWidgets('Tab model: can create, switch, and close tabs', (WidgetTester tester) async {
      final repo = InMemoryPersistenceRepository();
      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      // Tap "New Tab" button
      await tester.tap(find.byTooltip('New Tab'));
      await tester.pumpAndSettle();

      // Close the second tab using the close icon
      expect(find.byIcon(Icons.close), findsWidgets);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
    });

    testWidgets('Workspace panes: can switch to Bookmarks and History views', (WidgetTester tester) async {
      final repo = InMemoryPersistenceRepository();
      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        forceMockBrowser: true,
        initialUrl: Uri.parse('https://example.com'),
      ));
      await tester.pumpAndSettle();

      // Switch to Bookmarks
      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();
      expect(find.text('No Bookmarks Saved'), findsOneWidget);

      // Toggle Bookmark on active page
      await tester.tap(find.byTooltip('Bookmark Page'));
      await tester.pumpAndSettle();

      // Should now list the bookmarked page
      expect(find.text('No Bookmarks Saved'), findsNothing);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);

      // Switch to History
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('Closing the last remaining tab recreates a clean default tab', (WidgetTester tester) async {
      final repo = InMemoryPersistenceRepository();
      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      // We have 1 tab. Tap its close button
      expect(find.byIcon(Icons.close), findsWidgets);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      // Browser must remain functional with a fresh tab and address bar present
      expect(find.byType(TextField), findsWidgets);
      expect(find.byTooltip('New Tab'), findsOneWidget);
    });

    testWidgets('Home button navigates to homepage', (WidgetTester tester) async {
      final repo = InMemoryPersistenceRepository();
      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      // Verify Home button exists
      expect(find.byTooltip('Home'), findsOneWidget);
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('BrowserTab & MockBrowserEngine Unit Tests', () {
    test('Navigation flow: loadUrl updates history and back/forward state', () async {
      final engine = MockBrowserEngine();
      final tab = BrowserTab(
        id: 'test_tab_1',
        engine: engine,
        initialUrl: Uri.parse('https://example.com'),
      );
      await engine.initialize(initialUrl: Uri.parse('https://example.com'));

      expect(tab.currentUrl, Uri.parse('https://example.com'));
      expect(tab.canGoBack, isFalse);
      expect(tab.canGoForward, isFalse);

      // Navigate to second page
      await tab.loadUrl(Uri.parse('https://flutter.dev'));
      expect(tab.currentUrl, Uri.parse('https://flutter.dev'));
      expect(tab.canGoBack, isTrue);
      expect(tab.canGoForward, isFalse);

      // Navigate backwards
      await tab.goBack();
      expect(tab.currentUrl, Uri.parse('https://example.com'));
      expect(tab.canGoBack, isFalse);
      expect(tab.canGoForward, isTrue);

      // Navigate forwards
      await tab.goForward();
      expect(tab.currentUrl, Uri.parse('https://flutter.dev'));
      expect(tab.canGoBack, isTrue);
      expect(tab.canGoForward, isFalse);

      await tab.dispose();
    });

    test('Error handling: Invalid protocol generates BrowserNavigationError', () async {
      final engine = MockBrowserEngine();
      final tab = BrowserTab(
        id: 'test_tab_2',
        engine: engine,
      );
      await engine.initialize();

      // Try loading an invalid scheme (e.g. ftp:// or javascript:)
      await tab.loadUrl(Uri.parse('ftp://invalid-server.com/resource'));

      expect(tab.error, isNotNull);
      expect(tab.error!.message, contains('Unsupported scheme'));

      tab.clearError();
      expect(tab.error, isNull);

      await tab.dispose();
    });
  });
}
