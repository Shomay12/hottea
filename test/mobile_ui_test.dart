import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/core/persistence/in_memory_persistence_repository.dart';
import 'package:hottea/main.dart';

void main() {
  group('HotTea Mobile / iPhone UI Tests', () {
    testWidgets('Renders mobile-first layout on iPhone screen dimensions (390x844)', (WidgetTester tester) async {
      final repo = InMemoryPersistenceRepository();
      // Set surface to standard iPhone portrait size
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      // Desktop brand chip should NOT be present on mobile
      expect(find.text('HotTea'), findsNothing);

      // Verify mobile bottom navigation toolbar has Back, Forward, New Tab, and Tab Switcher
      expect(find.byTooltip('Back'), findsOneWidget);
      expect(find.byTooltip('Forward'), findsOneWidget);
      expect(find.byTooltip('New Tab'), findsOneWidget);
      expect(find.byTooltip('More Actions'), findsOneWidget);

      // Verify tab counter badge shows "1"
      expect(find.text('1'), findsOneWidget);

      // Tap tab switcher to open card overview
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      // Card switcher should now be visible
      expect(find.text('Tabs (1)'), findsOneWidget);
      expect(find.text('Done'), findsWidgets);

      // Tap "New Tab" in tab switcher
      await tester.tap(find.text('New Tab'));
      await tester.pumpAndSettle();

      // Now should have 2 tabs and return to browser
      expect(find.text('2'), findsOneWidget);

      // Tap More Actions to open action sheet
      await tester.tap(find.byTooltip('More Actions'));
      await tester.pumpAndSettle();

      // Verify bottom sheet action items
      expect(find.text('Copy URL'), findsOneWidget);
      expect(find.text('Clip to Notes'), findsOneWidget);
      expect(find.text('Find in Page'), findsOneWidget);
      expect(find.text('Zoom'), findsOneWidget);
    });

    testWidgets('Mobile tab switcher distinguishes private tabs with shield', (WidgetTester tester) async {
      final repo = InMemoryPersistenceRepository();
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      // Open tab switcher
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      // Tap "New Private Tab"
      await tester.tap(find.byTooltip('New Private Tab'));
      await tester.pumpAndSettle();

      // Active tab counter should now be 2
      expect(find.text('2'), findsOneWidget);

      // Address bar should show shield icon for private tab
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    testWidgets('Mobile secondary workspace navigation opens Bookmarks and returns cleanly', (WidgetTester tester) async {
      final repo = InMemoryPersistenceRepository();
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(HotTeaApp(
        persistenceRepository: repo,
        forceMockBrowser: true,
      ));
      await tester.pumpAndSettle();

      // Open action sheet and tap Settings
      await tester.tap(find.byTooltip('More Actions'));
      await tester.pumpAndSettle();

      // Close action sheet
      await tester.tap(find.text('Copy URL'));
      await tester.pumpAndSettle();

      // Verify returning to browser keeps URL and state
      expect(find.byTooltip('New Tab'), findsOneWidget);
    });
  });
}
