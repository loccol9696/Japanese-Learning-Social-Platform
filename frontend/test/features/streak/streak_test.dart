import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/streak/streak_calendar.dart';
import 'package:frontend/features/streak/streak_chip.dart';
import 'package:frontend/features/streak/streak_model.dart';
import 'package:frontend/features/streak/streak_service.dart';
import 'package:frontend/features/streak/streak_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

/// Service giả: trả sẵn streak và các ngày đã học, ghi lại các khoảng đã hỏi.
class _FakeStreakService extends StreakService {
  _FakeStreakService(this.streak, this.days);

  final Streak streak;
  final Set<DateTime> days;
  final List<(DateTime, DateTime)> asked = [];

  @override
  Future<Streak> getMine() async => streak;

  @override
  Future<Set<DateTime>> getDays(DateTime from, DateTime to) async {
    asked.add((from, to));
    return days;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Streak.fromJson', () {
    test('đọc đủ trường', () {
      final s = Streak.fromJson({'currentStreak': 5, 'longestStreak': 9, 'activeToday': true});
      expect(s.currentStreak, 5);
      expect(s.longestStreak, 9);
      expect(s.activeToday, isTrue);
      expect(s.atRisk, isFalse);
    });

    test('thiếu trường thì về 0, không còn số giả', () {
      final s = Streak.fromJson({});
      expect(s.currentStreak, 0);
      expect(s.activeToday, isFalse);
      expect(s.atRisk, isFalse);
    });

    test('có streak nhưng hôm nay chưa học thì sắp đứt', () {
      expect(Streak.fromJson({'currentStreak': 3, 'activeToday': false}).atRisk, isTrue);
    });
  });

  group('monthGridDays', () {
    test('tháng 10/2026 bắt đầu từ CN 27/9 và kết thúc T7 31/10', () {
      final grid = monthGridDays(DateTime(2026, 10));
      expect(grid.first, DateTime(2026, 9, 27));
      expect(grid.last, DateTime(2026, 10, 31));
      expect(grid.length, 35);
    });

    test('tháng bắt đầu đúng Chủ nhật không có ô thừa phía trước', () {
      final grid = monthGridDays(DateTime(2026, 2)); // 1/2/2026 là Chủ nhật
      expect(grid.first, DateTime(2026, 2, 1));
      expect(grid.last, DateTime(2026, 2, 28));
      expect(grid.length, 28);
    });

    test('luôn đủ tuần, bắt đầu Chủ nhật, kết thúc Thứ bảy, không trùng ngày', () {
      for (var m = 1; m <= 12; m++) {
        final grid = monthGridDays(DateTime(2026, m));
        expect(grid.length % 7, 0, reason: 'tháng $m');
        expect(grid.toSet().length, grid.length);
        expect(grid.first.weekday, DateTime.sunday);
        expect(grid.last.weekday, DateTime.saturday);
      }
    });
  });

  test('streakDaysUrl định dạng ngày ISO', () {
    final url = ApiConstants.streakDaysUrl(DateTime(2026, 9, 27), DateTime(2026, 10, 31));
    expect(url, endsWith('/users/me/streak/days?from=2026-09-27&to=2026-10-31'));
  });

  test('StreakService.getDays gọi đúng endpoint và đọc danh sách ngày', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    late http.Request seen;
    ApiClient.overrideForTesting(MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode({'status': 200, 'data': ['2026-10-26', '2026-10-27']}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final days = await StreakService().getDays(DateTime(2026, 9, 27), DateTime(2026, 10, 31));

    expect(seen.url.path, endsWith('/users/me/streak/days'));
    expect(seen.headers['Authorization'], startsWith('Bearer '));
    expect(days, {DateTime(2026, 10, 26), DateTime(2026, 10, 27)});
  });

  group('StreakChip', () {
    testWidgets('hiện cả khi chuỗi bằng 0', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StreakChip(days: 0))));
      expect(find.text('0'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
    });

    testWidgets('bấm gọi onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StreakChip(days: 76, onTap: () => taps++)),
      ));
      expect(find.text('76'), findsOneWidget);
      await tester.tap(find.byType(StreakChip));
      expect(taps, 1);
    });
  });

  group('StreakSheet', () {
    final today = DateTime(2026, 10, 27);

    Future<_FakeStreakService> pumpSheet(WidgetTester tester, Set<DateTime> days, {int streak = 76}) async {
      final service = _FakeStreakService(Streak(currentStreak: streak, longestStreak: 80, activeToday: true), days);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreakSheet(initial: Streak(currentStreak: streak), service: service, today: today),
          ),
        ),
      ));
      await tester.pump();
      return service;
    }

    testWidgets('hiện số chuỗi, tháng hiện tại và ngọn lửa ở các ngày đã học', (tester) async {
      await pumpSheet(tester, {DateTime(2026, 9, 30), DateTime(2026, 10, 1), DateTime(2026, 10, 27)});

      expect(find.byKey(const ValueKey('streak-count')), findsOneWidget);
      expect(find.text('76'), findsOneWidget);
      expect(find.text('tháng 10 năm 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('streak-day-active-2026-10-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('streak-day-active-2026-10-27')), findsOneWidget);
      expect(find.byKey(const ValueKey('streak-day-active-2026-9-30')), findsOneWidget);
      expect(find.byKey(const ValueKey('streak-day-active-2026-10-28')), findsNothing);
    });

    testWidgets('hỏi đúng khoảng ngày phủ lưới tháng', (tester) async {
      final service = await pumpSheet(tester, {});
      expect(service.asked.first, (DateTime(2026, 9, 27), DateTime(2026, 10, 31)));
    });

    testWidgets('không cho đi tới tháng tương lai, lùi được về tháng trước', (tester) async {
      final service = await pumpSheet(tester, {});

      await tester.tap(find.byKey(const ValueKey('streak-next')));
      await tester.pump();
      expect(find.text('tháng 10 năm 2026'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('streak-prev')));
      await tester.pump();
      expect(find.text('tháng 9 năm 2026'), findsOneWidget);
      expect(service.asked.length, 2);

      await tester.tap(find.byKey(const ValueKey('streak-next')));
      await tester.pump();
      expect(find.text('tháng 10 năm 2026'), findsOneWidget);
    });
  });
}
