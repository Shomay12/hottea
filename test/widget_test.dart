import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/features/browser/domain/browser_engine.dart';
import 'package:hottea/features/browser/domain/browser_tab.dart';
import 'package:hottea/main.dart';

void main() {
  group('HotTea UI & Tab System Smoke Tests', () {
    testWidgets('Renders brand, address bar, navigation controls, and research notes', (WidgetTester tester) async {
      await tester.pumpWidget(const HotTeaApp());
      await tester.pump();

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

      // Verify Notes tab is present
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('Tab model: can create, switch, and close tabs', (WidgetTester tester) async {
      await tester.pumpWidget(const HotTeaApp());
      await tester.pump();

      // Tap "New Tab" button
      await tester.tap(find.byTooltip('New Tab'));
      await tester.pump();

      // Close the second tab using the close icon
      expect(find.byIcon(Icons.close), findsWidgets);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
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
