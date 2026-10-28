import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/flame_icon.dart';

void main() {
  test('đường viền ngọn lửa nằm gọn trong ô, ngọn chạm đỉnh và đáy chạm đáy', () {
    final bounds = FlamePainter.buildPath(const Size(100, 100)).getBounds();

    expect(bounds.top, closeTo(0, 0.5));
    expect(bounds.bottom, closeTo(100, 0.5));
    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(100));
    // Ngọn lửa cao hơn rộng, và nằm giữa ô theo chiều ngang.
    expect(bounds.width, lessThan(bounds.height));
    expect(bounds.center.dx, closeTo(50, 2));
  });

  test('ngọn nhọn ở giữa, thân tròn bên dưới: điểm trên đỉnh hẹp, điểm ở thân rộng', () {
    final path = FlamePainter.buildPath(const Size(100, 100));

    expect(path.contains(const Offset(50, 3)), isTrue); // ngay dưới ngọn
    expect(path.contains(const Offset(20, 3)), isFalse); // hai bên ngọn là trống
    expect(path.contains(const Offset(80, 3)), isFalse);
    expect(path.contains(const Offset(50, 80)), isTrue); // thân
    expect(path.contains(const Offset(20, 80)), isTrue);
    expect(path.contains(const Offset(80, 80)), isTrue);
    // Ngọn lửa đặc, không có lỗ ở giữa thân.
    expect(path.contains(const Offset(50, 60)), isTrue);
  });

  testWidgets('FlameIcon có đúng kích thước yêu cầu', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: FlameIcon(size: 36, color: Colors.orange)),
    ));

    expect(tester.getSize(find.byType(FlameIcon)), const Size(36, 36));
  });
}
