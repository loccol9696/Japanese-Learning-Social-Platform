import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_palette.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/subscription/models/token_usage_model.dart';
import 'package:frontend/features/subscription/screens/token_usage_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime get _today {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

Map<String, dynamic> _status({
  bool vip = false,
  String? planName,
  int limit = 5000,
  int used = 1420,
  bool lifetime = false,
}) =>
    {
      'vip': vip,
      'planName': planName,
      'expiresAt': vip && !lifetime ? _iso(_today.add(const Duration(days: 20))) : null,
      'lifetime': lifetime,
      'remainingDays': vip && !lifetime ? 20 : 0,
      'dailyTokenLimit': limit,
      'tokensUsedToday': used,
      'tokensRemainingToday': limit - used,
    };

/// Tuần này: thứ hai..chủ nhật; mỗi ngày có số token theo [perDay] (mặc định tăng dần), hôm nay luôn là 1.510.
Map<String, dynamic> _week({int subtitle = 640, int grammar = 360, bool empty = false}) {
  final monday = _today.subtract(Duration(days: _today.weekday - 1));
  final days = [
    for (var i = 0; i < 7; i++)
      {
        'date': _iso(monday.add(Duration(days: i))),
        'tokens': empty ? 0 : (monday.add(Duration(days: i)) == _today ? 1510 : 100 * (i + 1)),
      },
  ];
  return {
    'range': 'week',
    'totalTokens': days.fold<int>(0, (s, d) => s + (d['tokens'] as int)),
    'days': days,
    'features': [
      {'feature': 'VIDEO_SUBTITLE', 'tokens': empty ? 0 : subtitle},
      {'feature': 'GRAMMAR_ANALYSIS', 'tokens': empty ? 0 : grammar},
    ],
  };
}

Map<String, dynamic> _month() {
  final first = DateTime(_today.year, _today.month, 1);
  final length = DateTime(_today.year, _today.month + 1, 0).day;
  return {
    'range': 'month',
    'totalTokens': 0,
    'days': [
      for (var i = 0; i < length; i++)
        {'date': _iso(first.add(Duration(days: i))), 'tokens': first.add(Duration(days: i)) == _today ? 70 : 0},
    ],
    'features': [
      {'feature': 'VIDEO_SUBTITLE', 'tokens': 50},
      {'feature': 'GRAMMAR_ANALYSIS', 'tokens': 20},
    ],
  };
}

http.Response _ok(Object data) => http.Response(
      jsonEncode({'status': 200, 'data': data}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _fail() => http.Response(
      jsonEncode({'status': 500, 'message': 'Lỗi máy chủ'}),
      500,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late http.Response Function(http.Request) handler;
  var installed = false;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    requests = [];
    handler = (request) {
      final path = request.url.path;
      if (path.endsWith('/payments/my-subscription')) return _ok(_status());
      if (path.endsWith('/payments/token-usage')) {
        return _ok(request.url.queryParameters['range'] == 'month' ? _month() : _week());
      }
      return _ok(<String, dynamic>{});
    };
    if (!installed) {
      installed = true;
      ApiClient.overrideForTesting(MockClient((request) async {
        requests.add(request);
        return handler(request);
      }));
    }
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: TokenUsageScreen()));
    await tester.pumpAndSettle();
  }

  group('định dạng số', () {
    test('dấu chấm ngăn cách hàng nghìn', () {
      expect(formatTokenCount(0), '0');
      expect(formatTokenCount(50), '50');
      expect(formatTokenCount(3580), '3.580');
      expect(formatTokenCount(10000), '10.000');
      expect(formatTokenCount(1234567), '1.234.567');
    });
  });

  testWidgets('thẻ trên cùng: còn lại hôm nay, hạn mức, đã dùng, ngày làm mới và gói miễn phí', (tester) async {
    await open(tester);

    expect(find.text('Token AI'), findsOneWidget);
    expect(find.text('Còn lại hôm nay'), findsOneWidget);
    expect(find.byKey(const ValueKey('token-remaining')).evaluate().isNotEmpty, isTrue);
    expect(tester.widget<Text>(find.byKey(const ValueKey('token-remaining'))).data, '3.580');
    expect(find.text('/ 5.000 token'), findsOneWidget);
    expect(find.text('Đã dùng 1.420'), findsOneWidget);
    final tomorrow = _today.add(const Duration(days: 1));
    expect(
      find.text('Làm mới ${tomorrow.day.toString().padLeft(2, '0')}/${tomorrow.month.toString().padLeft(2, '0')}'),
      findsOneWidget,
    );
    expect(find.descendant(of: find.byKey(const ValueKey('token-plan-badge')), matching: find.text('Miễn phí')), findsOneWidget);
    expect(find.byKey(const ValueKey('token-upgrade')), findsOneWidget);
  });

  testWidgets('thanh hạn mức đầy theo tỉ lệ đã dùng', (tester) async {
    await open(tester);

    final track = tester.getSize(find.byKey(const ValueKey('token-quota-card'))).width - 40;
    final fill = tester.getSize(find.byKey(const ValueKey('token-quota-fill'))).width;
    expect(fill, closeTo(track * 1420 / 5000, 1.5));
  });

  testWidgets('hạn mức chuyển sang màu cam khi chỉ còn không quá 10%', (tester) async {
    handler = (request) {
      final path = request.url.path;
      if (path.endsWith('/payments/my-subscription')) {
        return _ok(_status(limit: 10000, used: 9420));
      }
      if (path.endsWith('/payments/token-usage')) return _ok(_week());
      return _ok(<String, dynamic>{});
    };
    await open(tester);

    final remaining = tester.widget<Text>(find.byKey(const ValueKey('token-remaining')));
    expect(remaining.data, '580');
    expect(remaining.style?.color, AppPalette.warning);

    final fill = tester.widget<Container>(find.byKey(const ValueKey('token-quota-fill')));
    final decoration = fill.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, [AppPalette.warning, AppPalette.warning]);
  });

  testWidgets('gói trả phí: hiện tên gói và ngày hết hạn, không còn lời mời nâng cấp', (tester) async {
    handler = (request) {
      final path = request.url.path;
      if (path.endsWith('/payments/my-subscription')) {
        return _ok(_status(vip: true, planName: 'Pro tháng', limit: 500, used: 120));
      }
      if (path.endsWith('/payments/token-usage')) return _ok(_week());
      return _ok(<String, dynamic>{});
    };
    await open(tester);

    expect(find.descendant(of: find.byKey(const ValueKey('token-plan-badge')), matching: find.text('Pro tháng')), findsOneWidget);
    expect(find.textContaining('Hết hạn'), findsOneWidget);
    expect(find.textContaining('còn 20 ngày'), findsOneWidget);
    expect(find.byKey(const ValueKey('token-upgrade')), findsNothing);
    expect(tester.widget<Text>(find.byKey(const ValueKey('token-remaining'))).data, '380');
  });

  testWidgets('gói trọn đời ghi "Gói trọn đời" thay cho ngày hết hạn', (tester) async {
    handler = (request) {
      final path = request.url.path;
      if (path.endsWith('/payments/my-subscription')) {
        return _ok(_status(vip: true, planName: 'VIP trọn đời', limit: 5000, used: 0, lifetime: true));
      }
      if (path.endsWith('/payments/token-usage')) return _ok(_week());
      return _ok(<String, dynamic>{});
    };
    await open(tester);

    expect(find.text('Gói trọn đời'), findsOneWidget);
    expect(find.textContaining('Hết hạn'), findsNothing);
  });

  testWidgets('"Dùng cho tính năng" chỉ có đúng hai tính năng AI thật của hệ thống', (tester) async {
    await open(tester);

    expect(find.text('Dùng cho tính năng'), findsOneWidget);
    expect(find.text('Tạo phụ đề tự động cho video'), findsOneWidget);
    expect(find.text('Phân tích ngữ pháp'), findsOneWidget);
    // Những tính năng trong ảnh mẫu nhưng hệ thống không tính token.
    expect(find.textContaining('Tra từ'), findsNothing);
    expect(find.textContaining('luyện nói'), findsNothing);
    expect(find.textContaining('nghe và viết'), findsNothing);
    expect(find.textContaining('Dịch kịch bản'), findsNothing);
    // 640 / (640 + 360) = 64%, 360 / 1000 = 36%.
    expect(find.text('64%'), findsOneWidget);
    expect(find.text('36%'), findsOneWidget);
    expect(find.text('640'), findsOneWidget);
    expect(find.text('360'), findsOneWidget);
  });

  testWidgets('tuần: 7 cột, mặc định chọn hôm nay; chạm cột khác thì đổi số liệu ở trên', (tester) async {
    await open(tester);

    for (var i = 0; i < 7; i++) {
      expect(find.byKey(ValueKey('token-bar-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('token-bar-7')), findsNothing);
    for (final label in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']) {
      expect(find.text(label), findsOneWidget);
    }
    final caption = find.byKey(const ValueKey('token-chart-caption'));
    expect(tester.widget<Text>(caption).textSpan!.toPlainText(), startsWith('1.510 token · '));
    expect(tester.widget<Text>(caption).textSpan!.toPlainText(), contains(weekdayFullOf(_today)));

    // Chạm thứ hai (đầu tuần): 100 token, hoặc 1.510 nếu hôm nay đúng là thứ hai.
    await tester.tap(find.byKey(const ValueKey('token-bar-0')));
    await tester.pump();
    final monday = _today.subtract(Duration(days: _today.weekday - 1));
    final expected = monday == _today ? '1.510' : '100';
    expect(tester.widget<Text>(caption).textSpan!.toPlainText(), '$expected token · Thứ hai');
  });

  testWidgets('đổi sang Tháng: gom dữ liệu thành bốn tuần và hiện tổng tuần đang chọn', (tester) async {
    await open(tester);
    expect(requests.where((r) => r.url.path.endsWith('/token-usage')).map((r) => r.url.queryParameters['range']), ['week']);

    await tester.tap(find.byKey(const ValueKey('token-range-month')));
    await tester.pumpAndSettle();

    expect(requests.where((r) => r.url.path.endsWith('/token-usage')).last.url.queryParameters['range'], 'month');
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(ValueKey('token-bar-$i')), findsOneWidget);
      expect(find.text('Tuần ${i + 1}'), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('token-bar-4')), findsNothing);
    final caption = tester.widget<Text>(find.byKey(const ValueKey('token-chart-caption'))).textSpan!.toPlainText();
    final week = _today.day <= 21 ? ((_today.day - 1) ~/ 7) + 1 : 4;
    final start = (week - 1) * 7 + 1;
    final monthLength = DateTime(_today.year, _today.month + 1, 0).day;
    final end = week == 4 ? monthLength : week * 7;
    expect(caption, '70 token · Tuần $week ($start–$end/${_today.month})');
    expect(find.text('Tháng này'), findsOneWidget);
    expect(find.text('71%'), findsOneWidget); // 50 / 70
  });

  testWidgets('quay lại Tuần dùng dữ liệu đã tải, không gọi server lại', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('token-range-month')));
    await tester.pumpAndSettle();
    final before = requests.where((r) => r.url.path.endsWith('/token-usage')).length;

    await tester.tap(find.byKey(const ValueKey('token-range-week')));
    await tester.pumpAndSettle();

    expect(requests.where((r) => r.url.path.endsWith('/token-usage')).length, before);
    expect(find.byKey(const ValueKey('token-bar-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('token-bar-7')), findsNothing);
  });

  testWidgets('chưa dùng token nào thì không hiện mô tả thừa và các tính năng đều 0%', (tester) async {
    handler = (request) {
      final path = request.url.path;
      if (path.endsWith('/payments/my-subscription')) return _ok(_status(used: 0));
      if (path.endsWith('/payments/token-usage')) return _ok(_week(empty: true));
      return _ok(<String, dynamic>{});
    };
    await open(tester);

    expect(find.text('Tuần này bạn chưa dùng token nào.'), findsNothing);
    expect(find.textContaining('Token là hạn mức dùng AI mỗi ngày'), findsNothing);
    expect(find.text('0%'), findsNWidgets(2));
    expect(tester.widget<Text>(find.byKey(const ValueKey('token-remaining'))).data, '5.000');
  });

  testWidgets('lỗi tải ban đầu giữ loading và tự phục hồi khi server sẵn sàng', (tester) async {
    handler = (_) => _fail();
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: TokenUsageScreen()));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const ValueKey('token-quota-card')), findsNothing);

    handler = (request) {
      final path = request.url.path;
      if (path.endsWith('/payments/my-subscription')) return _ok(_status());
      if (path.endsWith('/payments/token-usage')) return _ok(_week());
      return _ok(<String, dynamic>{});
    };
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('token-quota-card')), findsOneWidget);
  });

  testWidgets('lỗi tạm thời được tự tải lại mà không hiện trang báo lỗi', (tester) async {
    var statusAttempts = 0;
    handler = (request) {
      final path = request.url.path;
      if (path.endsWith('/payments/my-subscription')) {
        statusAttempts++;
        return statusAttempts == 1 ? _fail() : _ok(_status());
      }
      if (path.endsWith('/payments/token-usage')) return _ok(_week());
      return _ok(<String, dynamic>{});
    };

    await open(tester);

    expect(statusAttempts, 2);
    expect(find.byKey(const ValueKey('token-quota-card')), findsOneWidget);
  });

  testWidgets('đổi sang Tháng bị lỗi thì giữ nguyên Tuần', (tester) async {
    await open(tester);
    handler = (request) => request.url.path.endsWith('/token-usage') ? _fail() : _ok(_status());

    await tester.tap(find.byKey(const ValueKey('token-range-month')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('token-bar-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('token-bar-7')), findsNothing);
    expect(find.text('Tuần này'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });
}
