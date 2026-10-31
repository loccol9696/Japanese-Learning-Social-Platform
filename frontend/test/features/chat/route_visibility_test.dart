import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/chat/presentation/route_visibility.dart';

void main() {
  late BuildContext inner;

  Future<void> pumpNested(WidgetTester tester) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (context) {
                inner = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('màn đang ở trên cùng của mọi Navigator là hiện tại', (
    tester,
  ) async {
    await pumpNested(tester);

    expect(isRouteChainCurrent(inner), isTrue);
  });

  testWidgets('bị đè ở Navigator trong thì không còn hiện tại', (tester) async {
    await pumpNested(tester);

    Navigator.of(inner)
        .push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
    await tester.pumpAndSettle();

    expect(isRouteChainCurrent(inner), isFalse);
  });

  testWidgets(
    'bị đè ở Navigator gốc thì không còn hiện tại, đóng thì trở lại',
    (tester) async {
      await pumpNested(tester);
      final root = Navigator.of(inner, rootNavigator: true);

      root.push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
      await tester.pumpAndSettle();
      expect(isRouteChainCurrent(inner), isFalse);

      root.pop();
      await tester.pumpAndSettle();
      expect(isRouteChainCurrent(inner), isTrue);
    },
  );
}
