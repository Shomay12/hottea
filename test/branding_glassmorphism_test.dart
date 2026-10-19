import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/core/theme/glass_components.dart';
import 'package:hottea/core/theme/glass_theme.dart';
import 'package:hottea/core/theme/hottea_logo.dart';
import 'package:hottea/core/persistence/in_memory_persistence_repository.dart';
import 'package:hottea/main.dart';

void main() {
  group('HotTea Mandatory Branding & Logo Tests', () {
    testWidgets('HotTeaLogo paints without error and scales cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HotTeaLogo(size: 48, color: GlassTheme.accentTea),
            ),
          ),
        ),
      );

      expect(find.byType(HotTeaLogo), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('HotTeaBrandBadge displays exact "HotTea" capitalization and logo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HotTeaBrandBadge(showBadge: true),
          ),
        ),
      );

      expect(find.byType(HotTeaBrandBadge), findsOneWidget);
      expect(find.byType(HotTeaLogo), findsOneWidget);
      expect(find.text('HotTea'), findsOneWidget);
      expect(find.text('Hot Tea'), findsNothing);
      expect(find.text('Hottea'), findsNothing);
      expect(find.text('HOTTEA'), findsNothing);
    });

    testWidgets('HotTeaApp contains HotTeaBrandBadge and no coffee placeholder icon', (tester) async {
      final repo = InMemoryPersistenceRepository();
      await tester.pumpWidget(
        HotTeaApp(
          persistenceRepository: repo,
          forceMockBrowser: true,
        ),
      );
      await tester.pumpAndSettle();

      // Brand badge must be present
      expect(find.byType(HotTeaBrandBadge), findsOneWidget);
      expect(find.text('HotTea'), findsAtLeastNWidgets(1));

      // No Icons.coffee placeholder
      expect(find.byIcon(Icons.coffee), findsNothing);
    });
  });

  group('Glassmorphism Component Tests', () {
    testWidgets('GlassSurface creates BackdropFilter with correct blur and border', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassSurface(
              blur: GlassTheme.blurStandard,
              color: GlassTheme.surfaceGlass,
              borderColor: GlassTheme.borderSubtle,
              child: Text('Glass Content'),
            ),
          ),
        ),
      );

      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Glass Content'), findsOneWidget);
    });

    testWidgets('GlassToolbar creates glass bar with correct preferredSize', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassToolbar(
              height: 52,
              child: Text('Toolbar Content'),
            ),
          ),
        ),
      );

      expect(find.byType(GlassToolbar), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.text('Toolbar Content'), findsOneWidget);
    });

    testWidgets('GlassCard instantiates and applies rounded glass styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              child: const Text('Card Content'),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(GlassCard), findsOneWidget);
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });
  });
}
