import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/flashcard/presentation/widgets/answer_streak.dart';
import 'package:frontend/features/flashcard/presentation/widgets/fire_celebration.dart';
import 'package:frontend/features/flashcard/presentation/widgets/streak_progress_bar.dart';

void main() {
  group('AnswerStreak', () {
    test('đếm câu đúng liên tiếp và đứt chuỗi khi sai', () {
      final streak = AnswerStreak();
      expect(streak.count, 0);

      streak.record(correct: true);
      streak.record(correct: true);
      expect(streak.count, 2);

      streak.record(correct: false);
      expect(streak.count, 0);
    });

    test('chỉ làm nổi bật từ chuỗi 2 trở lên', () {
      final streak = AnswerStreak();
      streak.record(correct: true);
      expect(streak.isHighlighted, isFalse);
      streak.record(correct: true);
      expect(streak.isHighlighted, isTrue);
    });

    test('chạm mốc lửa lớn đúng ở câu thứ 5, 10, 15... và không phải ở các câu khác', () {
      final streak = AnswerStreak();
      final milestones = <int>[];
      for (var i = 1; i <= 12; i++) {
        if (streak.record(correct: true)) milestones.add(i);
      }
      expect(milestones, [5, 10]);
    });

    test('sai giữa chừng thì phải đúng đủ 5 câu liên tiếp mới tới mốc lại', () {
      final streak = AnswerStreak();
      for (var i = 0; i < 4; i++) {
        expect(streak.record(correct: true), isFalse);
      }
      expect(streak.record(correct: false), isFalse);
      for (var i = 0; i < 4; i++) {
        expect(streak.record(correct: true), isFalse);
      }
      expect(streak.record(correct: true), isTrue);
    });

    test('reset đưa chuỗi về 0', () {
      final streak = AnswerStreak()..record(correct: true)..record(correct: true);
      streak.reset();
      expect(streak.count, 0);
    });
  });

  group('StreakProgressBar', () {
    Future<void> pumpBar(WidgetTester tester, {required double progress, required int streak}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: StreakProgressBar(progress: progress, streak: streak),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('bình thường: màu thường, không có ngọn lửa', (tester) async {
      await pumpBar(tester, progress: 0.4, streak: 0);

      expect(find.byKey(const ValueKey('progress-fill')), findsOneWidget);
      expect(find.byKey(const ValueKey('progress-fill-fire')), findsNothing);
      expect(find.byKey(const ValueKey('streak-badge')), findsNothing);
    });

    testWidgets('mới đúng 1 câu thì chưa đổi màu', (tester) async {
      await pumpBar(tester, progress: 0.4, streak: 1);

      expect(find.byKey(const ValueKey('streak-badge')), findsNothing);
    });

    testWidgets('đúng liên tiếp từ 2 câu: đổi sang màu cam và hiện ngọn lửa kèm số chuỗi', (tester) async {
      await pumpBar(tester, progress: 0.4, streak: 4);

      expect(find.byKey(const ValueKey('progress-fill-fire')), findsOneWidget);
      expect(find.byKey(const ValueKey('progress-fill')), findsNothing);
      expect(find.byKey(const ValueKey('streak-badge')), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('ngọn lửa nằm ở đầu phần đã hoàn thành và không tràn ra ngoài thanh khi gần đầy', (tester) async {
      await pumpBar(tester, progress: 1.0, streak: 3);

      final track = tester.getRect(find.byKey(const ValueKey('progress-track')));
      final badge = tester.getRect(find.byKey(const ValueKey('streak-badge')));
      expect(badge.right, lessThanOrEqualTo(track.right + 0.5));
      expect(badge.left, greaterThanOrEqualTo(track.left - 0.5));

      await pumpBar(tester, progress: 0.5, streak: 3);
      final badgeMid = tester.getRect(find.byKey(const ValueKey('streak-badge')));
      expect(badgeMid.center.dx, closeTo(track.left + track.width * 0.5, 2));
    });

    testWidgets('chuỗi đứt thì ngọn lửa biến mất và thanh về màu thường', (tester) async {
      await pumpBar(tester, progress: 0.4, streak: 3);
      expect(find.byKey(const ValueKey('streak-badge')), findsOneWidget);

      await pumpBar(tester, progress: 0.5, streak: 0);

      expect(find.byKey(const ValueKey('streak-badge')), findsNothing);
      expect(find.byKey(const ValueKey('progress-fill')), findsOneWidget);
    });
  });

  group('FireCelebration', () {
    Widget host(int trigger) => MaterialApp(
          home: Scaffold(body: Stack(fit: StackFit.expand, children: [FireCelebration(trigger: trigger)])),
        );

    testWidgets('chưa kích hoạt thì không vẽ gì', (tester) async {
      await tester.pumpWidget(host(0));

      expect(find.byKey(const ValueKey('fire-celebration')), findsNothing);
    });

    testWidgets('tăng trigger thì chơi hiệu ứng rồi tự biến mất', (tester) async {
      await tester.pumpWidget(host(0));

      await tester.pumpWidget(host(1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('fire-celebration')), findsOneWidget);

      await tester.pump(FireCelebration.duration);
      await tester.pump();
      expect(find.byKey(const ValueKey('fire-celebration')), findsNothing);
    });

    testWidgets('chơi lại mỗi lần trigger tăng thêm', (tester) async {
      await tester.pumpWidget(host(0));
      await tester.pumpWidget(host(1));
      await tester.pump(FireCelebration.duration + const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('fire-celebration')), findsNothing);

      await tester.pumpWidget(host(2));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('fire-celebration')), findsOneWidget);

      await tester.pump(FireCelebration.duration);
    });

    testWidgets('không chặn cử chỉ chạm của màn bên dưới', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: ElevatedButton(onPressed: () => taps++, child: const Text('bấm'))),
              const FireCelebration(trigger: 0),
            ],
          ),
        ),
      ));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: ElevatedButton(onPressed: () => taps++, child: const Text('bấm'))),
              const FireCelebration(trigger: 1),
            ],
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('bấm'));
      expect(taps, 1);

      await tester.pump(FireCelebration.duration);
    });

    test('hoạt ảnh trồi lên rồi mờ dần: độ đậm và độ cao nằm trong khoảng hợp lệ', () {
      for (var i = 0; i <= 100; i++) {
        final t = i / 100;
        expect(FirePainter.opacity(t), inInclusiveRange(0, 1), reason: 't=$t');
        expect(FirePainter.rise(t), inInclusiveRange(0, 1.2), reason: 't=$t'); // easeOutBack vọt nhẹ quá 1
      }
      expect(FirePainter.opacity(0), closeTo(0, 1e-9));
      expect(FirePainter.opacity(0.5), 1);
      expect(FirePainter.opacity(1), closeTo(0, 1e-9));
      expect(FirePainter.rise(0), closeTo(0, 1e-9));
    });
  });
}
