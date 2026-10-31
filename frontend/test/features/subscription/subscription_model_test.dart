import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/subscription/models/subscription_model.dart';

SubscriptionPlan _plan({
  required int id,
  required double price,
  required int durationDays,
  String features = '',
}) {
  return SubscriptionPlan.fromJson({
    'id': id,
    'name': 'Plan $id',
    'price': price,
    'durationDays': durationDays,
    'description': '',
    'features': features,
  });
}

void main() {
  group('SubscriptionPlan', () {
    test('tách quyền lợi theo dấu phẩy nhưng giữ số hàng nghìn', () {
      final plan = _plan(
        id: 3,
        price: 890000,
        durationDays: 365,
        features: 'Tất cả quyền lợi Pro, 2,000 token AI/ngày, Ưu tiên hỗ trợ',
      );

      expect(plan.features, [
        'Tất cả quyền lợi Pro',
        '2,000 token AI/ngày',
        'Ưu tiên hỗ trợ',
      ]);
    });

    test('phân loại gói trọn đời và số tháng', () {
      expect(_plan(id: 2, price: 99000, durationDays: 30).months, 1);
      expect(_plan(id: 3, price: 890000, durationDays: 365).months, 12);
      final lifetime = _plan(id: 4, price: 1990000, durationDays: 3650);
      expect(lifetime.isLifetime, isTrue);
      expect(lifetime.months, isNull);
    });

    test('phần trăm tiết kiệm so với gói theo tháng', () {
      final monthly = _plan(id: 2, price: 99000, durationDays: 30);
      final yearly = _plan(id: 3, price: 890000, durationDays: 365);
      final lifetime = _plan(id: 4, price: 1990000, durationDays: 3650);

      expect(yearly.savingsPercentVs(monthly), 25);
      // Gói trọn đời và chính gói mốc không có phần trăm tiết kiệm.
      expect(lifetime.savingsPercentVs(monthly), isNull);
      expect(monthly.savingsPercentVs(monthly), isNull);
    });

    test('định dạng số token có dấu chấm ngăn cách', () {
      final plan = SubscriptionPlan.fromJson({
        'id': 3,
        'name': 'Plan',
        'price': 1,
        'durationDays': 365,
        'dailyTokenLimit': 2000,
      });
      expect(plan.formattedTokenLimit, '2.000');
    });
  });

  group('SubscriptionStatus.expiryAfterBuying', () {
    final now = DateTime(2026, 11, 1);
    final yearly = _plan(id: 3, price: 890000, durationDays: 365);

    test('cộng dồn vào hạn hiện tại khi gói còn hiệu lực', () {
      final status = SubscriptionStatus(
        isVip: true,
        endDate: DateTime(2026, 12, 1),
        remainingDays: 30,
      );

      expect(
        status.expiryAfterBuying(yearly, now: now),
        DateTime(2026, 12, 1).add(const Duration(days: 365)),
      );
    });

    test('tính từ hôm nay khi chưa có gói hoặc đã hết hạn', () {
      const none = SubscriptionStatus(isVip: false, remainingDays: 0);
      final expired = SubscriptionStatus(
        isVip: true,
        endDate: DateTime(2026, 10, 1),
        remainingDays: 0,
      );
      final expected = now.add(const Duration(days: 365));

      expect(none.expiryAfterBuying(yearly, now: now), expected);
      expect(expired.expiryAfterBuying(yearly, now: now), expected);
    });
  });
}
