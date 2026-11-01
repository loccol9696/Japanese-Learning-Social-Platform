import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/flashcard/presentation/widgets/carousel_card_frame.dart';

void main() {
  late PageController controller;

  Future<void> pumpCarousel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    controller = PageController(viewportFraction: kCarouselViewportFraction);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 240,
          child: PageView.builder(
            controller: controller,
            itemCount: 5,
            itemBuilder: (_, index) => CarouselCardFrame(
              controller: controller,
              index: index,
              child: Container(key: ValueKey('card-$index'), color: Colors.blue),
            ),
          ),
        ),
      ),
    ));
  }

  Rect rect(WidgetTester tester, int index) => tester.getRect(find.byKey(ValueKey('card-$index')));

  testWidgets('hai thẻ liền kề luôn có khe, không dính nhau', (tester) async {
    await pumpCarousel(tester);

    final gap = rect(tester, 1).left - rect(tester, 0).right;
    expect(gap, greaterThan(8));
  });

  testWidgets('thẻ đang xem nằm giữa màn hình, chừa lề đối xứng hai bên', (tester) async {
    await pumpCarousel(tester);

    final current = rect(tester, 0);
    expect(current.left, closeTo(400 - current.right, 0.5));
    expect(current.width, lessThan(400));
  });

  testWidgets('thẻ ở tâm đủ cỡ, thẻ kế bên nhỏ hơn một chút', (tester) async {
    await pumpCarousel(tester);

    final current = rect(tester, 0);
    final side = rect(tester, 1);
    expect(side.height, closeTo(current.height * kCarouselSideScale, 0.5));
  });

  testWidgets('đang vuốt giữa hai thẻ thì cả hai thu nhỏ vừa phải, chuyển xong thẻ mới về cỡ đầy đủ', (tester) async {
    await pumpCarousel(tester);
    final fullHeight = rect(tester, 0).height;

    final gesture = await tester.startGesture(const Offset(200, 100));
    await gesture.moveBy(const Offset(-80, 0));
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();
    final midCurrent = rect(tester, 0).height;
    final midNext = rect(tester, 1).height;
    expect(midCurrent, lessThan(fullHeight));
    expect(midNext, lessThan(fullHeight));

    // Kéo thêm quá nửa trang rồi thả: thẻ kế bên trở thành thẻ đang xem.
    await gesture.moveBy(const Offset(-120, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.page, 1.0);
    expect(rect(tester, 1).height, closeTo(fullHeight, 0.5));
  });
}
