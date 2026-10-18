import 'package:flutter_test/flutter_test.dart';
import 'package:hottea/main.dart';

void main() {
  testWidgets('HotTea smoke test: renders brand, address bar, and research notes', (WidgetTester tester) async {
    await tester.pumpWidget(const HotTeaApp());

    // Verify brand title is displayed
    expect(find.text('HotTea'), findsOneWidget);

    // Verify default URL in address bar is present
    expect(find.text('https://docs.flutter.dev'), findsWidgets);

    // Verify Notes tab is present
    expect(find.text('Notes'), findsOneWidget);
  });
}
