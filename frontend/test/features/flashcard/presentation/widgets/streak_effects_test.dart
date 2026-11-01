import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/flashcard/presentation/widgets/fire_celebration.dart';
import 'package:frontend/features/flashcard/presentation/widgets/streak_progress_bar.dart';

void main() {
  Widget bar(int streak, {double progress = 0.4}) => MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: StreakProgressBar(progress: progress, streak: streak),
          ),
        ),
      );

  Finder badge() => find.byKey(const ValueKey('streak-badge'));
  Finder badgeOut() => find.byKey(const ValueKey('streak-badge-out'));
  Finder sparks() => find.byKey(const ValueKey('streak-sparks'));

  group('mức nhiệt theo chuỗi', () {
    test('lửa to và rực dần theo chuỗi, đến 10 câu thì thành lửa xanh', () {
      expect(StreakHeat.of(2), same(StreakHeat.warm));
      expect(StreakHeat.of(4), same(StreakHeat.warm));
      expect(StreakHeat.of(5), same(StreakHeat.hot));
      expect(StreakHeat.of(9), same(StreakHeat.hot));
      expect(StreakHeat.of(10), same(StreakHeat.blaze));
      expect(StreakHeat.of(37), same(StreakHeat.blaze));
      expect(StreakHeat.warm.size, lessThan(StreakHeat.hot.size));
      expect(StreakHeat.hot.size, lessThan(StreakHeat.blaze.size));
      expect(StreakHeat.warm.sparks, lessThan(StreakHeat.blaze.sparks));
    });
  });

  group('ngọn lửa trên thanh tiến trình', () {
    testWidgets('chuỗi dưới 2 thì thanh màu thường, không có lửa', (tester) async {
      await tester.pumpWidget(bar(1));

      expect(find.byKey(const ValueKey('progress-fill')), findsOneWidget);
      expect(find.byKey(const ValueKey('progress-fill-fire')), findsNothing);
      expect(badge(), findsNothing);
    });

    testWidgets('từ chuỗi 2 thì thanh đổi màu lửa và hiện lửa mang số chuỗi', (tester) async {
      await tester.pumpWidget(bar(2));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('progress-fill-fire')), findsOneWidget);
      expect(badge(), findsOneWidget);
      expect(find.descendant(of: badge(), matching: find.text('2')), findsOneWidget);
    });

    testWidgets('khi có chuỗi, phần đã hoàn thành của thanh vẫn hiện đủ chiều cao và đúng bề rộng tiến trình', (tester) async {
      for (final streak in [0, 1, 2, 3, 6, 12]) {
        await tester.pumpWidget(bar(streak, progress: 0.4));
        await tester.pump(const Duration(milliseconds: 500));

        final track = tester.getSize(find.byKey(const ValueKey('progress-track')));
        final fillKey = streak >= 2 ? 'progress-fill-fire' : 'progress-fill';
        final fill = tester.getSize(find.byKey(ValueKey(fillKey)));
        expect(fill.height, track.height, reason: 'chuỗi $streak: phần đã hoàn thành phải cao bằng thanh');
        expect(fill.width, closeTo(track.width * 0.4, 0.5), reason: 'chuỗi $streak');
      }
    });

    testWidgets('chuỗi càng dài lửa càng to', (tester) async {
      for (final (streak, size) in [(2, 32.0), (5, 38.0), (10, 42.0)]) {
        await tester.pumpWidget(bar(streak));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.getSize(badge()).height, size, reason: 'chuỗi $streak');
      }
    });

    testWidgets('mỗi câu đúng tiếp theo bắn tia lửa và đổi số; tia lửa tự tắt', (tester) async {
      await tester.pumpWidget(bar(2));
      await tester.pump(const Duration(milliseconds: 1000)); // xong lần bắt lửa đầu
      expect(sparks(), findsNothing);

      await tester.pumpWidget(bar(3));
      await tester.pump(const Duration(milliseconds: 100));
      expect(sparks(), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(sparks(), findsNothing);
      expect(find.descendant(of: badge(), matching: find.text('3')), findsOneWidget);
      expect(find.descendant(of: badge(), matching: find.text('2')), findsNothing);
    });

    testWidgets('bắt lửa lần đầu (từ chuỗi 1 lên 2) cũng bắn tia lửa', (tester) async {
      await tester.pumpWidget(bar(1));
      await tester.pumpWidget(bar(2));
      await tester.pump(const Duration(milliseconds: 100));

      expect(badge(), findsOneWidget);
      expect(sparks(), findsOneWidget);
    });

    testWidgets('đứt chuỗi: lửa tắt kèm khói rồi biến mất, không để lại lửa thật', (tester) async {
      await tester.pumpWidget(bar(3));
      await tester.pump(const Duration(milliseconds: 400));
      expect(badge(), findsOneWidget);

      await tester.pumpWidget(bar(0));
      await tester.pump(const Duration(milliseconds: 100));
      expect(badge(), findsNothing);
      expect(badgeOut(), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      expect(badgeOut(), findsNothing);
      expect(find.byKey(const ValueKey('progress-fill')), findsOneWidget);
    });

    testWidgets('lửa lập lòe một lúc rồi dừng, màn hình vẫn yên được (không chạy mãi)', (tester) async {
      await tester.pumpWidget(bar(4));
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(minutes: 1));

      expect(badge(), findsOneWidget);
    });

    testWidgets('đầu lửa không tràn ra ngoài thanh khi tiến trình đầy', (tester) async {
      await tester.pumpWidget(bar(12, progress: 1));
      await tester.pump(const Duration(milliseconds: 400));

      final bar0 = tester.getRect(find.byKey(const ValueKey('progress-track')));
      final flame = tester.getRect(badge());
      expect(flame.right, lessThanOrEqualTo(bar0.right + 0.5));
      expect(flame.left, greaterThanOrEqualTo(bar0.left - 0.5));
    });
  });

  group('bùng lửa ở mốc chuỗi', () {
    Widget fire(int trigger, int streak) => MaterialApp(
          home: Scaffold(body: FireCelebration(trigger: trigger, streak: streak)),
        );

    testWidgets('đạt mốc thì hiện lửa và banner ghi số câu; xong thì gỡ hết', (tester) async {
      await tester.pumpWidget(fire(0, 0));
      expect(find.byKey(const ValueKey('fire-celebration')), findsNothing);
      expect(find.byKey(const ValueKey('fire-banner')), findsNothing);

      await tester.pumpWidget(fire(1, 5));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('fire-celebration')), findsOneWidget);
      expect(find.byKey(const ValueKey('fire-banner')), findsOneWidget);
      expect(find.text('5 câu đúng liên tiếp!'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.byKey(const ValueKey('fire-celebration')), findsNothing);
      expect(find.byKey(const ValueKey('fire-banner')), findsNothing);
    });

    testWidgets('banner giữ nguyên số của lúc đạt mốc dù chuỗi đổi giữa chừng', (tester) async {
      await tester.pumpWidget(fire(0, 0));
      await tester.pumpWidget(fire(1, 10));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(fire(1, 0)); // chuỗi đứt nhưng chưa phải lần kích hoạt mới
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('10 câu đúng liên tiếp!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets('không truyền chuỗi thì chỉ có lửa, không có banner', (tester) async {
      await tester.pumpWidget(fire(0, 0));
      await tester.pumpWidget(fire(1, 0));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('fire-celebration')), findsOneWidget);
      expect(find.byKey(const ValueKey('fire-banner')), findsNothing);
      await tester.pump(const Duration(milliseconds: 2000));
    });
  });
}
