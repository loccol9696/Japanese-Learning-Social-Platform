import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/subscription/models/subscription_model.dart';
import 'package:frontend/features/subscription/screens/subscription_screen.dart';
import 'package:frontend/features/subscription/services/subscription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSubscriptionService extends SubscriptionService {
  _FakeSubscriptionService(this.status);

  final SubscriptionStatus status;

  // Gói giống dữ liệu BE khởi tạo (không gồm gói Free vì đã bị lọc giá 0).
  static final plans = [
    SubscriptionPlan.fromJson({
      'id': 2,
      'name': 'JLSP Pro (1 Tháng)',
      'price': 99000,
      'durationDays': 30,
      'dailyTokenLimit': 500,
      'description': 'Gói luyện tập hàng tháng',
      'features': 'Trích xuất lời video, 500 token AI/ngày',
    }),
    SubscriptionPlan.fromJson({
      'id': 3,
      'name': 'JLSP Mastery (1 Năm)',
      'price': 890000,
      'durationDays': 365,
      'dailyTokenLimit': 2000,
      'description': 'Tiết kiệm 25%',
      'features': 'Tất cả quyền lợi Pro, 2,000 token AI/ngày',
    }),
    SubscriptionPlan.fromJson({
      'id': 4,
      'name': 'JLSP VIP Đặc Biệt',
      'price': 1990000,
      'durationDays': 3650,
      'dailyTokenLimit': 5000,
      'description': 'Gói cao cấp nhất',
      'features': 'Không giới hạn trích xuất, 5,000 token AI/ngày',
    }),
  ];

  @override
  Future<List<SubscriptionPlan>> getPlans() async => plans;

  @override
  Future<SubscriptionStatus> getMyStatus() async => status;
}

Future<void> _pumpScreen(WidgetTester tester, SubscriptionStatus status) async {
  await tester.binding.setSurfaceSize(const Size(1200, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: SubscriptionScreen(service: _FakeSubscriptionService(status)),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _planCard(String name) =>
    find.descendant(of: find.byType(InkWell), matching: find.text(name));

SubscriptionStatus _vip({
  required int planId,
  required String name,
  int days = 20,
}) => SubscriptionStatus(
  isVip: true,
  planId: planId,
  planName: name,
  endDate: DateTime.now().add(Duration(days: days)),
  remainingDays: days,
);

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('người dùng Free thấy đủ các gói và nút đăng ký', (tester) async {
    await _pumpScreen(
      tester,
      const SubscriptionStatus(isVip: false, remainingDays: 0),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Chọn gói'), findsOneWidget);
    expect(_planCard('JLSP Pro (1 Tháng)'), findsOneWidget);
    expect(_planCard('JLSP Mastery (1 Năm)'), findsOneWidget);
    expect(_planCard('JLSP VIP Đặc Biệt'), findsOneWidget);
    expect(find.text('Gói đang dùng'), findsNothing);
    // Phần trăm tiết kiệm tính từ giá gói tháng, không còn con số cố định.
    expect(find.text('Tiết kiệm 25%'), findsOneWidget);
    expect(find.text('Nâng cấp Premium'), findsOneWidget);
  });

  testWidgets('đang dùng gói tháng: nâng cấp, gia hạn và đổi gói đều được', (
    tester,
  ) async {
    await _pumpScreen(tester, _vip(planId: 2, name: 'JLSP Pro (1 Tháng)'));

    expect(tester.takeException(), isNull);
    expect(find.text('Chọn gói muốn áp dụng'), findsOneWidget);
    expect(find.text('Gói đang dùng'), findsOneWidget);
    expect(find.text('Đang dùng'), findsOneWidget);

    // Mặc định chọn gói cao hơn gần nhất.
    expect(find.text('Nâng cấp lên gói 1 năm'), findsOneWidget);

    await tester.tap(_planCard('JLSP VIP Đặc Biệt'));
    await tester.pumpAndSettle();
    expect(find.text('Nâng cấp lên gói trọn đời'), findsOneWidget);

    await tester.tap(_planCard('JLSP Pro (1 Tháng)'));
    await tester.pumpAndSettle();
    expect(find.text('Gia hạn gói 1 tháng'), findsOneWidget);
  });

  testWidgets(
    'đang dùng gói trọn đời: không gia hạn nhưng vẫn đổi được gói khác',
    (tester) async {
      await _pumpScreen(
        tester,
        _vip(planId: 4, name: 'JLSP VIP Đặc Biệt', days: 3000),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Sở hữu trọn đời'), findsWidgets);
      expect(find.text('Đang sở hữu'), findsOneWidget);

      final ownedButton = find.widgetWithText(
        ElevatedButton,
        'Bạn đang sở hữu gói này',
      );
      expect(ownedButton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(ownedButton).onPressed, isNull);

      await tester.tap(_planCard('JLSP Mastery (1 Năm)'));
      await tester.pumpAndSettle();
      final changeButton = find.widgetWithText(
        ElevatedButton,
        'Đổi sang gói 1 năm',
      );
      expect(changeButton, findsOneWidget);
      expect(tester.widget<ElevatedButton>(changeButton).onPressed, isNotNull);
    },
  );

  testWidgets('bấm nâng cấp mở bảng xác nhận kèm hạn dùng mới', (tester) async {
    await _pumpScreen(tester, _vip(planId: 2, name: 'JLSP Pro (1 Tháng)'));

    await tester.tap(find.text('Nâng cấp lên gói 1 năm'));
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận nâng cấp gói'), findsOneWidget);
    expect(find.textContaining('Hạn dùng mới:'), findsOneWidget);
  });
}
