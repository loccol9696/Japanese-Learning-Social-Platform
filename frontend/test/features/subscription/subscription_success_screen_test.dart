import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/subscription/models/subscription_model.dart';
import 'package:frontend/features/subscription/screens/subscription_success_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) => base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

PaymentOrder _order({double amount = 99000}) => PaymentOrder.fromJson({
      'id': 1,
      'orderCode': 'JLSPYVEYTUAY',
      'transferMemo': 'JLSPYVEYTUAY',
      'amount': amount,
      'status': 'SUCCESS',
      'planId': 2,
      'planName': 'Premium',
    });

SubscriptionPlan _plan({int days = 30}) => SubscriptionPlan.fromJson({
      'id': 2,
      'name': 'Premium',
      'code': 'PRO_MONTHLY',
      'price': 99000,
      'durationDays': days,
      'dailyTokenLimit': 500,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late http.Response Function(http.Request) handler;
  var installed = false;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    handler = (_) => http.Response(
          jsonEncode({
            'status': 200,
            'data': {
              'vip': true,
              'planName': 'Premium',
              'expiresAt': '2026-12-01T10:00:00',
              'lifetime': false,
              'remainingDays': 30,
              'dailyTokenLimit': 500,
              'tokensUsedToday': 0,
              'tokensRemainingToday': 500,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
    if (!installed) {
      installed = true;
      ApiClient.overrideForTesting(MockClient((request) async => handler(request)));
    }
  });

  Future<SubscriptionSuccessAction?> open(WidgetTester tester, {PaymentOrder? order, SubscriptionPlan? plan}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    SubscriptionSuccessAction? result;
    var returned = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showSubscriptionSuccess(context, order: order ?? _order(), plan: plan ?? _plan());
              returned = true;
            },
            child: const Text('mở'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    addTearDown(() => returned = returned);
    return result;
  }

  testWidgets('hiện tiêu đề, lời chúc và đủ bốn dòng tóm tắt giao dịch', (tester) async {
    await open(tester);

    expect(find.text('Thanh toán thành công'), findsOneWidget);
    expect(find.text('Bạn đã là hội viên Kotoba Premium.'), findsOneWidget);
    expect(find.byKey(const ValueKey('success-badge')), findsOneWidget);
    expect(find.text('Gói'), findsOneWidget);
    expect(find.text('Hiệu lực đến'), findsOneWidget);
    expect(find.text('Số tiền'), findsOneWidget);
    expect(find.text('Mã giao dịch'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('success-plan'))).data, 'Premium · 1 tháng');
    expect(tester.widget<Text>(find.byKey(const ValueKey('success-amount'))).data, '99.000 đ');
    expect(tester.widget<Text>(find.byKey(const ValueKey('success-code'))).data, 'JLSPYVEYTUAY');
  });

  testWidgets('hiệu lực đến lấy ngày hết hạn thật từ server', (tester) async {
    await open(tester);

    expect(tester.widget<Text>(find.byKey(const ValueKey('success-until'))).data, '01/12/2026');
  });

  testWidgets('không gọi được server thì ước tính ngày hết hạn từ thời hạn của gói', (tester) async {
    handler = (_) => http.Response('{}', 500, headers: {'content-type': 'application/json'});
    await open(tester);

    final d = DateTime.now().add(const Duration(days: 30));
    final expected = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    expect(tester.widget<Text>(find.byKey(const ValueKey('success-until'))).data, expected);
  });

  testWidgets('gói trọn đời ghi "Trọn đời" thay cho ngày', (tester) async {
    handler = (_) => http.Response(
          jsonEncode({
            'status': 200,
            'data': {
              'vip': true,
              'planName': 'VIP',
              'lifetime': true,
              'remainingDays': 0,
              'dailyTokenLimit': 5000,
              'tokensUsedToday': 0,
              'tokensRemainingToday': 5000,
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
    await open(tester, plan: _plan(days: 36500));

    expect(tester.widget<Text>(find.byKey(const ValueKey('success-until'))).data, 'Trọn đời');
    expect(tester.widget<Text>(find.byKey(const ValueKey('success-plan'))).data, 'Premium · trọn đời');
  });

  testWidgets('số tiền là số đã trả sau giảm giá, không phải giá niêm yết của gói', (tester) async {
    await open(tester, order: _order(amount: 89100));

    expect(tester.widget<Text>(find.byKey(const ValueKey('success-amount'))).data, '89.100 đ');
  });

  testWidgets('nút sao chép đưa mã giao dịch vào clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await open(tester);

    await tester.tap(find.byKey(const ValueKey('success-copy')));
    await tester.pump();

    expect(copied, 'JLSPYVEYTUAY');
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('hai nút trả về đúng lựa chọn cho nơi gọi', (tester) async {
    SubscriptionSuccessAction? result;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => result = await showSubscriptionSuccess(context, order: _order(), plan: _plan()),
            child: const Text('mở'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('success-view-profile')));
    await tester.pumpAndSettle();
    expect(result, SubscriptionSuccessAction.viewProfile);

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('success-start-learning')));
    await tester.pumpAndSettle();
    expect(result, SubscriptionSuccessAction.startLearning);
  });
}
