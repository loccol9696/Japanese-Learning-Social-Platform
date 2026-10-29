import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/subscription/models/subscription_model.dart';
import 'package:frontend/features/subscription/services/subscription_service.dart';
import 'package:frontend/features/subscription/widgets/vietqr_payment_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _jwt() {
  String b64(Map<String, dynamic> map) =>
      base64Url.encode(utf8.encode(jsonEncode(map))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000;
  return '${b64({'alg': 'none'})}.${b64({'exp': exp})}.sig';
}

Map<String, dynamic> _orderJson({
  String status = 'PENDING',
  num amount = 99000,
  num? paidAmount,
  DateTime? expiresAt,
}) => {
  'id': 11,
  'orderCode': 'JLSP7K3Q9M2X',
  'transferMemo': 'JLSP7K3Q9M2X',
  'planId': 2,
  'planName': 'Pro tháng',
  'amount': amount,
  'paidAmount': paidAmount,
  'status': status,
  'qrUrl': 'https://img.vietqr.io/image/970416-28442991-compact2.svg?amount=99000',
  'bankName': 'ACB',
  'accountNo': '28442991',
  'accountName': 'PHAM CONG NGUYEN',
  'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(minutes: 14))).toIso8601String(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late Map<String, dynamic> Function(http.Request request) respond;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(accessToken: _jwt(), refreshToken: 'r');
    requests = [];
    respond = (_) => _orderJson();
    ApiClient.overrideForTesting(MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({'status': 200, 'data': respond(request)}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  group('mô hình', () {
    test('đọc đơn và các cờ trạng thái', () {
      final pending = PaymentOrder.fromJson(_orderJson());
      expect(pending.transferMemo, 'JLSP7K3Q9M2X');
      expect(pending.amount, 99000);
      expect(pending.isFinished, isFalse);

      expect(PaymentOrder.fromJson(_orderJson(status: 'SUCCESS')).isPaid, isTrue);
      expect(PaymentOrder.fromJson(_orderJson(status: 'EXPIRED')).isFinished, isTrue);
      expect(PaymentOrder.fromJson(_orderJson(status: 'CANCELLED')).isCancelled, isTrue);

      final partial = PaymentOrder.fromJson(_orderJson(status: 'NEEDS_REVIEW', paidAmount: 50000));
      expect(partial.needsReview, isTrue);
      expect(partial.isFinished, isFalse); // khách còn chuyển bù được
      expect(partial.remainingAmount, 49000);
    });

    test('đọc trạng thái gói từ server', () {
      final status = SubscriptionStatus.fromJson({
        'vip': true,
        'planId': 2,
        'planName': 'Pro tháng',
        'expiresAt': '2026-11-28T10:00:00',
        'lifetime': false,
        'remainingDays': 30,
        'dailyTokenLimit': 500,
        'tokensUsedToday': 20,
        'tokensRemainingToday': 480,
      });
      expect(status.isVip, isTrue);
      expect(status.isLifetime, isFalse);
      expect(status.daysRemaining, 30);
      expect(status.formattedExpiryDate, '28/11/2026');

      expect(SubscriptionStatus.fromJson({}).isVip, isFalse);
    });
  });

  group('dịch vụ', () {
    test('tạo đơn chỉ gửi mã gói, kèm token, không gửi userId', () async {
      final order = await SubscriptionService().createOrder(planId: 2);

      expect(order.orderCode, 'JLSP7K3Q9M2X');
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/payments/orders'));
      expect(jsonDecode(request.body), {'planId': 2});
      expect(request.headers['Authorization'], startsWith('Bearer '));
      expect(request.headers.keys.map((k) => k.toLowerCase()), isNot(contains('x-user-id')));
    });

    test('xem đơn và gói của tôi chỉ dùng GET, không có đường tự xác nhận', () async {
      respond = (r) => r.url.path.endsWith('/my-subscription')
          ? {'vip': false, 'remainingDays': 0}
          : _orderJson(status: 'SUCCESS');
      final service = SubscriptionService();

      final order = await service.getOrder('JLSP7K3Q9M2X');
      final status = await service.getMyStatus();

      expect(order.isPaid, isTrue);
      expect(status.isVip, isFalse);
      expect(requests.map((r) => r.method).toSet(), {'GET'});
      expect(requests.map((r) => r.url.path).any((p) => p.contains('confirm')), isFalse);
    });

    test('danh sách gói bán bỏ gói FREE dù giá bị đặt khác 0', () async {
      respond = (_) => {};
      ApiClient.overrideForTesting(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 200,
            'data': [
              {'id': 1, 'name': 'Miễn phí', 'code': 'FREE', 'price': 5000, 'durationDays': 9999, 'isActive': true},
              {'id': 2, 'name': 'Pro', 'code': 'PRO_MONTHLY', 'price': 99000, 'durationDays': 30, 'isActive': true},
              {'id': 3, 'name': 'Ẩn', 'code': 'OLD', 'price': 1000, 'durationDays': 30, 'isActive': false},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }));

      final plans = await SubscriptionService().getPlans();

      expect(plans.map((p) => p.code), ['PRO_MONTHLY']);
    });

    test('không lưu VIP cục bộ sau khi xem đơn thành công', () async {
      respond = (_) => _orderJson(status: 'SUCCESS');

      await SubscriptionService().getOrder('JLSP7K3Q9M2X');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().where((k) => k.contains('subscription')), isEmpty);
    });
  });

  group('bảng thanh toán VietQR', () {
    Future<bool?> pumpSheet(WidgetTester tester, {PaymentOrder? order}) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => VietQrPaymentSheet(
                    order: order ?? PaymentOrder.fromJson(_orderJson()),
                    pollInterval: const Duration(milliseconds: 20),
                    slowPollInterval: const Duration(milliseconds: 20),
                    qrBuilder: (context, url) => Container(key: const ValueKey('qr-image'), color: Colors.black),
                  ),
                );
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pump(const Duration(milliseconds: 300));
      return result;
    }

    testWidgets('hiện số tiền, tài khoản nhận và nội dung chuyển khoản do server cấp', (tester) async {
      respond = (_) => _orderJson();
      await pumpSheet(tester);

      expect(find.text('JLSP7K3Q9M2X'), findsOneWidget);
      expect(find.text('99.000 đ'), findsOneWidget);
      expect(find.text('ACB'), findsOneWidget);
      expect(find.text('28442991'), findsOneWidget);
      expect(find.text('PHAM CONG NGUYEN'), findsOneWidget);
      expect(find.textContaining('Đang chờ thanh toán'), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-image')), findsOneWidget);
      // Không có nút nào tự xác nhận đã thanh toán.
      expect(find.textContaining('Tôi đã'), findsNothing);
      expect(find.textContaining('Xác nhận thanh toán'), findsNothing);
    });

    testWidgets('bấm sao chép đưa nội dung chuyển khoản vào clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpSheet(tester);
      await tester.pump(const Duration(seconds: 1));

      final copyButton = find.byKey(const ValueKey('copy-Nội dung'));
      await tester.ensureVisible(copyButton);
      await tester.pump();
      await tester.tap(copyButton);
      await tester.pump();

      expect(copied, 'JLSP7K3Q9M2X');
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('server báo SUCCESS thì bảng đóng và trả true', (tester) async {
      var polls = 0;
      respond = (_) => _orderJson(status: ++polls >= 3 ? 'SUCCESS' : 'PENDING');
      bool? result;
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => VietQrPaymentSheet(
                    order: PaymentOrder.fromJson(_orderJson()),
                    pollInterval: const Duration(milliseconds: 20),
                    slowPollInterval: const Duration(milliseconds: 20),
                    qrBuilder: (context, url) => Container(key: const ValueKey('qr-image'), color: Colors.black),
                  ),
                );
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pump(const Duration(milliseconds: 300));
      for (var i = 0; i < 20 && result == null; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(requests.every((r) => r.method == 'GET'), isTrue);
    });

    testWidgets('đơn hết hạn: báo hết hạn, ẩn mã QR và cho tạo đơn mới', (tester) async {
      respond = (_) => _orderJson(status: 'EXPIRED');
      await pumpSheet(tester, order: PaymentOrder.fromJson(_orderJson(status: 'EXPIRED')));

      expect(find.textContaining('Đơn đã hết hạn'), findsOneWidget);
      expect(find.byKey(const ValueKey('qr-image')), findsNothing);
      expect(find.byKey(const ValueKey('payment-new-order')), findsOneWidget);
    });

    testWidgets('chuyển thiếu tiền: báo còn thiếu bao nhiêu và vẫn cho chuyển bù', (tester) async {
      final partial = PaymentOrder.fromJson(_orderJson(status: 'NEEDS_REVIEW', paidAmount: 50000));
      respond = (_) => _orderJson(status: 'NEEDS_REVIEW', paidAmount: 50000);
      await pumpSheet(tester, order: partial);

      expect(find.textContaining('còn thiếu 49.000 đ'), findsOneWidget);
      expect(find.text('JLSP7K3Q9M2X'), findsOneWidget); // vẫn thấy nội dung để chuyển bù
    });

    testWidgets('mất mạng khi hỏi trạng thái không làm hỏng bảng', (tester) async {
      ApiClient.overrideForTesting(MockClient((request) async => throw Exception('offline')));
      await pumpSheet(tester);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Đang chờ thanh toán'), findsOneWidget);
    });
  });
}
