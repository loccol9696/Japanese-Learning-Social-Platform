import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/subscription_model.dart';

/// Gói thành viên và thanh toán. Mọi việc đi qua server bằng access token của người dùng; app không tự suy ra trạng thái
/// VIP, không lưu VIP cục bộ và không có đường nào tự đánh dấu "đã thanh toán": gói chỉ được kích hoạt khi server nhận
/// tiền từ ngân hàng (hoặc admin duyệt), app chỉ hỏi lại trạng thái đơn.
class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService();

  Future<List<SubscriptionPlan>> getPlans() async {
    try {
      final data = await ApiClient.instance.get(ApiConstants.subscriptionPlansUrl);
      final List list = data is List ? data : const [];
      return list
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          // Gói FREE không bán, kể cả khi ai đó lỡ đặt giá khác 0 trong dữ liệu.
          .where((p) => p.isActive && p.price > 0 && p.code.toUpperCase() != 'FREE')
          .toList();
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException(
        statusCode: 503,
        message: 'Không thể kết nối để tải danh sách gói hội viên.',
      );
    }
  }

  /// Thông tin mô tả của một gói: theo [planId] (gói đang dùng), hoặc gói FREE nếu không truyền.
  /// Trả về null khi không tải được hoặc không tìm thấy gói.
  Future<SubscriptionPlan?> getPlanDetail({int? planId}) async {
    try {
      final data = await ApiClient.instance.get(ApiConstants.subscriptionPlansUrl);
      final List list = data is List ? data : const [];
      for (final item in list) {
        final plan = SubscriptionPlan.fromJson(item as Map<String, dynamic>);
        final matches = planId != null ? plan.id == planId : plan.code.toUpperCase() == 'FREE';
        if (matches) return plan;
      }
    } catch (_) {}
    return null;
  }

  /// Tạo đơn mua gói (hoặc mở lại đơn đang chờ cho cùng gói). Chỉ gửi gói muốn mua; người mua do server lấy từ token.
  Future<PaymentOrder> createOrder({required int planId, String? promoCode}) async {
    final body = <String, dynamic>{'planId': planId};
    if (promoCode != null && promoCode.trim().isNotEmpty) {
      body['promoCode'] = promoCode.trim().toUpperCase();
    }
    final data = await ApiClient.instance.post(
      ApiConstants.paymentOrdersUrl,
      body: body,
    );
    if (data is! Map<String, dynamic>) {
      throw ApiException(statusCode: 500, message: 'Máy chủ trả về đơn thanh toán không hợp lệ.');
    }
    return PaymentOrder.fromJson(data);
  }

  /// Trạng thái hiện tại của một đơn (chỉ đọc).
  Future<PaymentOrder> getOrder(String orderCode) async {
    final data = await ApiClient.instance.get(ApiConstants.paymentOrderUrl(orderCode));
    if (data is! Map<String, dynamic>) {
      throw ApiException(statusCode: 500, message: 'Máy chủ trả về đơn thanh toán không hợp lệ.');
    }
    return PaymentOrder.fromJson(data);
  }

  /// Gói hiện tại của chính người dùng. Lỗi thì ném ra để màn hình tự xử lý, không giả vờ là VIP hay miễn phí.
  Future<SubscriptionStatus> getMyStatus() async {
    final data = await ApiClient.instance.get(ApiConstants.mySubscriptionUrl);
    if (data is! Map<String, dynamic>) {
      throw ApiException(statusCode: 500, message: 'Máy chủ trả về trạng thái gói không hợp lệ.');
    }
    return SubscriptionStatus.fromJson(data);
  }

  Future<Map<String, dynamic>> verifyPromoCode(String code, {int? planId}) async {
    final data = await ApiClient.instance.get(
      '${ApiConstants.baseUrl}/payments/verify-promo?code=${Uri.encodeComponent(code.trim().toUpperCase())}${planId != null ? '&planId=$planId' : ''}',
    );
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw ApiException(statusCode: 400, message: 'Mã khuyến mãi không hợp lệ');
  }

  Future<List<SubscriptionPlan>> getAllPlansAdmin() async {
    try {
      final data = await ApiClient.instance.get('${ApiConstants.subscriptionPlansUrl}/admin-all');
      final List list = data is List ? data : const [];
      return list.map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}
    return getPlans();
  }

  Future<bool> updatePlanAdmin({
    required int planId,
    required String name,
    required double price,
    required int durationDays,
    required int dailyTokenLimit,
    String? description,
    String? features,
    bool? isActive,
  }) async {
    try {
      await ApiClient.instance.put(
        '${ApiConstants.subscriptionPlansUrl}/$planId',
        body: {
          'name': name,
          'price': price,
          'durationDays': durationDays,
          'dailyTokenLimit': dailyTokenLimit,
          'description': description,
          'features': features,
          'isActive': isActive ?? true,
        },
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<PromoCodeItem>> getPromoCodesAdmin() async {
    try {
      final data = await ApiClient.instance.get('${ApiConstants.baseUrl}/admin/promo-codes');
      final List list = data is List ? data : const [];
      return list.map((e) => PromoCodeItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {}
    return [];
  }

  Future<PromoCodeItem?> createPromoCodeAdmin({
    required String code,
    String? description,
    int? discountPercent,
    double? discountAmount,
    int? maxUses,
    int? durationDays,
    bool? isActive,
  }) async {
    try {
      final now = DateTime.now();
      final endDate = (durationDays != null && durationDays > 0)
          ? now.add(Duration(days: durationDays))
          : now.add(const Duration(days: 365));

      final data = await ApiClient.instance.post(
        '${ApiConstants.baseUrl}/admin/promo-codes',
        body: {
          'code': code.trim().toUpperCase(),
          'description': description,
          'discountPercent': discountPercent ?? 0,
          'discountAmount': discountAmount ?? 0,
          'maxUses': maxUses ?? 100,
          'startDate': now.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'isActive': isActive ?? true,
        },
      );
      if (data is Map<String, dynamic>) {
        return PromoCodeItem.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  Future<PromoCodeItem?> togglePromoCodeAdmin(int id) async {
    try {
      final data = await ApiClient.instance.put('${ApiConstants.baseUrl}/admin/promo-codes/$id/toggle');
      if (data is Map<String, dynamic>) {
        return PromoCodeItem.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> deletePromoCodeAdmin(int id) async {
    try {
      await ApiClient.instance.delete('${ApiConstants.baseUrl}/admin/promo-codes/$id');
      return true;
    } catch (_) {
      return false;
    }
  }
}
