import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/app.dart';

void main() {
  testWidgets('App smoke test - verifies App widget renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const App());

    // Verify that App renders properly without errors.
    expect(find.byType(App), findsOneWidget);
  });
}
