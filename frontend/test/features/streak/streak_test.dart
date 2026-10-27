import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/streak/streak_chip.dart';
import 'package:frontend/features/streak/streak_model.dart';
import 'package:frontend/features/streak/streak_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
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

  test('StreakService gọi đúng endpoint kèm access token', () async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    late http.Request seen;
    ApiClient.overrideForTesting(MockClient((request) async {
      seen = request;
      return http.Response(
        jsonEncode({'status': 200, 'data': {'currentStreak': 4, 'longestStreak': 6, 'activeToday': true}}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));

    final streak = await StreakService().getMine();

    expect(seen.url.toString(), ApiConstants.streakUrl);
    expect(seen.headers['Authorization'], startsWith('Bearer '));
    expect(streak.currentStreak, 4);
  });

  testWidgets('StreakChip hiện số ngày', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StreakChip(days: 12))));

    expect(find.textContaining('12'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
  });
}
