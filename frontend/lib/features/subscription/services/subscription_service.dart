import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/token_storage.dart';
import '../../auth/data/services/auth_service.dart';
import '../models/subscription_model.dart';

class SubscriptionService {
  static final SubscriptionService instance = SubscriptionService();
  static String get defaultBaseUrl => ApiConstants.subscriptionBaseUrl;

  final String baseUrl;
  final http.Client _client;

  SubscriptionService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? defaultBaseUrl,
        _client = client ?? http.Client();

  Future<SubscriptionStatus> getMySubscriptionStatus([int? userId]) async {
    int? resolvedUserId = userId;
    if (resolvedUserId == null || resolvedUserId <= 0) {
      final currentUser = await AuthService.instance.getCurrentUser();
      resolvedUserId = currentUser?.id;
    }
    return getMyStatus(userId: resolvedUserId ?? 0);
  }

  Future<List<SubscriptionPlan>> getPlans() async {
    try {
      final token = await TokenStorage.instance.getAccessToken();
      final plansUrl = '${ApiConstants.baseUrl}/subscription-plans';
      final response = await _client.get(
        Uri.parse(plansUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final List list = json['data'] as List? ?? [];
        if (list.isNotEmpty) {
          return list
              .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
              .where((p) => p.price > 0)
              .toList();
        }
      }
    } catch (_) {}
    return _getFallbackPlans();
  }

  /// Thông tin mô tả của một gói: theo [planId] (gói đang dùng), hoặc gói FREE nếu không truyền.
  Future<SubscriptionPlan?> getPlanDetail({int? planId}) async {
    try {
      final token = await TokenStorage.instance.getAccessToken();
      final plansUrl = '${ApiConstants.baseUrl}/subscription-plans';
      final response = await _client.get(
        Uri.parse(plansUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final List list = json['data'] as List? ?? [];
        for (final item in list) {
          final plan = SubscriptionPlan.fromJson(item as Map<String, dynamic>);
          final matches = planId != null
              ? plan.id == planId
              : plan.code.toUpperCase() == 'FREE';
          if (matches) return plan;
        }
      }
    } catch (_) {}

    if (planId != null) {
      for (final plan in _getFallbackPlans()) {
        if (plan.id == planId) return plan;
      }
    }
    return null;
  }

  /// Tạo đơn hàng thanh toán quét mã VietQR Napas 24/7
  Future<PaymentResponse> createQrOrder({
    required int userId,
    required int planId,
    String? planName,
    double? price,
  }) async {
    final currentUser = await AuthService.instance.getCurrentUser();
    final effectiveUserId = currentUser?.id ?? userId;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final generatedOrderCode = 'TX-${ts % 1000000}';

    PaymentResponse? result;
    try {
      final token = await TokenStorage.instance.getAccessToken();
      final response = await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/payments/create-qr-order'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': effectiveUserId,
          'planId': planId,
          'orderCode': generatedOrderCode,
          if (price != null) 'amount': price,
        }),
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        result = PaymentResponse.fromJson(json['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    if (result == null) {
      final orderCode = generatedOrderCode;
      final verificationCode = 'JLSP-${10000 + ts % 90000}';
      final int amount = price?.round() ??
          (planId == 2
              ? 99000
              : (planId == 5
                  ? 299000
                  : (planId == 3 ? 890000 : 1990000)));
      final resolvedName = planName ??
          (planId == 2
              ? 'JLSP Pro (1 Tháng)'
              : (planId == 5
                  ? 'Gói 3 Tháng'
                  : (planId == 3
                      ? 'JLSP Mastery (1 Năm)'
                      : 'JLSP VIP Đặc Biệt (Lifetime Sensei)')));

      final qrUrl = 'https://img.vietqr.io/image/970416-28442991-compact2.png'
          '?amount=$amount&addInfo=JLSP%20$orderCode&accountName=PHAM%20CONG%20NGUYEN';

      result = PaymentResponse(
        paymentId: ts,
        transactionRef: orderCode,
        amount: amount.toDouble(),
        paymentMethod: 'VIETQR_NAPAS',
        status: 'PENDING',
        planId: planId,
        planName: resolvedName,
        qrUrl: qrUrl,
        orderCode: orderCode,
        verificationCode: verificationCode,
        bankName: 'ACB - Ngân hàng TMCP Á Châu',
        accountNo: '28442991',
        accountName: 'PHAM CONG NGUYEN',
        createdAt: DateTime.now(),
      );
    }

    return result;
  }

  /// Xác nhận đã thanh toán đơn hàng VietQR và kích hoạt VIP
  Future<bool> confirmPayment({
    required int userId,
    required int planId,
    required String orderCode,
    String? verificationCode,
    String? planName,
    int? durationDays,
  }) async {
    final currentUser = await AuthService.instance.getCurrentUser();
    final effectiveUserId = currentUser?.id ?? userId;

    try {
      final token = await TokenStorage.instance.getAccessToken();
      await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/payments/confirm'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'orderCode': orderCode,
          'verificationCode': verificationCode ?? orderCode,
        }),
      ).timeout(const Duration(seconds: 12));
    } catch (_) {}

    await _saveLocalSubscription(
      userId: effectiveUserId,
      planId: planId,
      planName: planName,
      durationDays: durationDays,
    );

    return true;
  }

  /// Kiểm tra trạng thái đơn hàng (Polling)
  Future<String> getOrderStatus(String orderCode) async {
    try {
      final token = await TokenStorage.instance.getAccessToken();
      final response = await _client.get(
        Uri.parse('${ApiConstants.baseUrl}/payments/order-status/$orderCode'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>?;
        return data?['status'] as String? ?? 'PENDING';
      }
    } catch (_) {}
    return 'PENDING';
  }

  Future<PaymentResponse> checkout({
    required int userId,
    required int planId,
    String paymentMethod = 'VIETQR',
  }) async {
    if (paymentMethod == 'VIETQR' || paymentMethod == 'VIETQR_NAPAS') {
      return createQrOrder(userId: userId, planId: planId);
    }

    final currentUser = await AuthService.instance.getCurrentUser();
    final effectiveUserId = currentUser?.id ?? userId;

    PaymentResponse? result;
    try {
      final token = await TokenStorage.instance.getAccessToken();
      final response = await _client.post(
        Uri.parse((paymentMethod == 'MOCK' || paymentMethod == 'TEST') ? '$baseUrl/mock-checkout' : '$baseUrl/checkout'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': effectiveUserId,
          'planId': planId,
          'paymentMethod': paymentMethod,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        result = PaymentResponse.fromJson(json['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    if (result == null) {
      final isVNPay = paymentMethod == 'VNPAY';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final txnRef = '${isVNPay ? 'VNP' : 'MOCK'}_$ts';
      final int amount = planId == 2 ? 99000 : (planId == 4 ? 1990000 : 890000);
      final String resolvedPlanName = planId == 2
          ? 'JLSP Pro (1 Tháng)'
          : (planId == 4
              ? 'JLSP Premium 2 Năm (Mastery Plus)'
              : 'JLSP Mastery (1 Năm)');
      final String vnpaySandboxUrl =
          'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html'
          '?vnp_Version=2.1.0&vnp_Command=pay&vnp_TmnCode=CGXZLS0Z'
          '&vnp_Amount=${amount * 100}&vnp_CurrCode=VND'
          '&vnp_TxnRef=$txnRef&vnp_OrderInfo=Kotoba_VIP_$planId';

      result = PaymentResponse(
        paymentId: ts,
        transactionRef: txnRef,
        amount: amount.toDouble(),
        paymentMethod: paymentMethod,
        status: isVNPay ? 'PENDING' : 'SUCCESS',
        planId: planId,
        planName: resolvedPlanName,
        subscriptionId: isVNPay ? null : 101,
        paymentUrl: isVNPay ? vnpaySandboxUrl : null,
        paidAt: isVNPay ? null : DateTime.now(),
        createdAt: DateTime.now(),
      );
    }

    if (result.status == 'SUCCESS') {
      await _saveLocalSubscription(
        userId: effectiveUserId,
        planId: planId,
        planName: result.planName,
      );
    }

    return result;
  }

  Future<void> confirmVnpayPayment({
    required int userId,
    required int planId,
    String? planName,
    int? durationDays,
  }) async {
    final currentUser = await AuthService.instance.getCurrentUser();
    final effectiveUserId = currentUser?.id ?? userId;
    await _saveLocalSubscription(
      userId: effectiveUserId,
      planId: planId,
      planName: planName,
      durationDays: durationDays,
    );
  }

  Future<Map<String, dynamic>> verifyPromoCode(String code, {int? planId}) async {
    final token = await TokenStorage.instance.getAccessToken();
    final response = await _client.post(
      Uri.parse('${ApiConstants.baseUrl}/payments/verify-promo'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'code': code.trim().toUpperCase(),
        if (planId != null) 'planId': planId,
      }),
    ).timeout(const Duration(seconds: 8));

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = (json['status'] as num?)?.toInt() ?? response.statusCode;
    if ((response.statusCode == 200 || response.statusCode == 201) && (status == 200 || json['success'] == true)) {
      return (json['data'] as Map<String, dynamic>?) ?? {};
    } else {
      final msg = json['message'] as String? ?? 'Mã khuyến mãi không hợp lệ hoặc đã hết hạn';
      throw Exception(msg);
    }
  }

  Future<void> cancelSubscription({required int userId}) async {
    final currentUser = await AuthService.instance.getCurrentUser();
    final effectiveUserId = currentUser?.id ?? userId;
    final token = await TokenStorage.instance.getAccessToken();

    try {
      await _client.post(
        Uri.parse('${ApiConstants.baseUrl}/payments/cancel?userId=$effectiveUserId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_subscription_$effectiveUserId');
  }

  Future<SubscriptionStatus> getMyStatus({required int userId}) async {
    final currentUser = await AuthService.instance.getCurrentUser();
    final effectiveUserId = currentUser?.id ?? userId;

    // 1. Luôn ưu tiên đồng bộ trạng thái thực tế từ Backend Supabase DB
    try {
      final token = await TokenStorage.instance.getAccessToken();
      final response = await _client.get(
        Uri.parse('${ApiConstants.baseUrl}/payments/my-status?userId=$effectiveUserId'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final status = SubscriptionStatus.fromJson(json['data'] as Map<String, dynamic>);
        if (status.isVip) {
          await _saveLocalSubscription(
            userId: effectiveUserId,
            planId: status.planId ?? 0,
            planName: status.planName,
            durationDays: status.remainingDays,
          );
          return status;
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('user_subscription_$effectiveUserId');
          return status;
        }
      }
    } catch (_) {}

    // 2. Nếu tạm thời mất kết nối mạng, đọc từ bộ nhớ cục bộ
    final localStatus = await _getLocalSubscription(userId: effectiveUserId);
    if (localStatus != null && localStatus.isVip) {
      return localStatus;
    }

    return const SubscriptionStatus(isVip: false, remainingDays: 0);
  }

  Future<void> _saveLocalSubscription({
    required int userId,
    required int planId,
    String? planName,
    int? durationDays,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      int resolvedDuration = durationDays ?? 30;
      String resolvedName = planName ?? 'Gói VIP';

      if (durationDays == null || durationDays <= 0) {
        final lower = (planName ?? '').toLowerCase();
        if (lower.contains('trọn đời') || lower.contains('lifetime')) {
          resolvedDuration = 730;
          resolvedName = 'JLSP Premium 2 Năm (Mastery Plus)';
        } else if (lower.contains('1 năm') ||
            lower.contains('mastery') ||
            lower.contains('12 tháng')) {
          resolvedDuration = 365;
          resolvedName = planName ?? 'Gói 1 Năm';
        } else if (lower.contains('3 tháng')) {
          resolvedDuration = 90;
          resolvedName = planName ?? 'Gói 3 Tháng';
        } else if (lower.contains('1 tháng') || lower.contains('pro')) {
          resolvedDuration = 30;
          resolvedName = planName ?? 'Gói 1 Tháng';
        } else if (planId == 5) {
          resolvedDuration = 90;
          resolvedName = 'Gói 3 Tháng';
        } else if (planId == 2) {
          resolvedDuration = 30;
          resolvedName = 'JLSP Pro (1 Tháng)';
        } else if (planId == 3) {
          resolvedDuration = 365;
          resolvedName = 'JLSP Mastery (1 Năm)';
        } else if (planId == 4) {
          resolvedDuration = 730;
          resolvedName = 'JLSP Premium 2 Năm (Mastery Plus)';
        }
      }

      final endDate = now.add(Duration(days: resolvedDuration));

      final data = {
        'isVip': true,
        'planId': planId,
        'planName': resolvedName,
        'status': 'ACTIVE',
        'startDate': now.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'remainingDays': resolvedDuration,
      };
      await prefs.setString('user_subscription_$userId', jsonEncode(data));
    } catch (_) {}
  }

  Future<SubscriptionStatus?> _getLocalSubscription({required int userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final str = prefs.getString('user_subscription_$userId');
      if (str != null && str.isNotEmpty) {
        final json = jsonDecode(str) as Map<String, dynamic>;
        final end = DateTime.tryParse(json['endDate'] ?? '');
        int remainingDays = (json['remainingDays'] as num?)?.toInt() ?? 0;
        if (end != null) {
          final diff = end.difference(DateTime.now()).inDays;
          remainingDays = diff > 0 ? diff : 0;
        }
        return SubscriptionStatus(
          isVip: true,
          planId: json['planId'] as int?,
          planName: json['planName'] as String?,
          status: 'ACTIVE',
          startDate: DateTime.tryParse(json['startDate'] ?? ''),
          endDate: end,
          remainingDays: remainingDays,
        );
      }
    } catch (_) {}
    return null;
  }

  List<SubscriptionPlan> _getFallbackPlans() {
    return const [
      SubscriptionPlan(
        id: 4,
        code: 'PRO_2YEARS',
        name: 'JLSP Premium 2 Năm (Mastery Plus)',
        description: 'Gói đặc quyền cao cấp 2 năm (730 ngày) dành cho Sensei và học viên chuyên sâu',
        price: 1990000,
        dailyTokenLimit: 5000,
        originalPrice: 2490000,
        durationDays: 730,
        features: [
          'Toàn bộ đặc quyền Premium cao cấp nhất',
          'Phân tích ngữ pháp AI chuyên sâu',
          'Tải bài học offline không giới hạn',
          'Huy hiệu Premium Vương miện danh dự',
          'Thời hạn sử dụng 2 năm (730 ngày)',
        ],
        isActive: true,
        displayOrder: 1,
        badgeLabel: 'Tiết kiệm 30% - Cao cấp nhất',
        discountPercent: 30,
      ),
      SubscriptionPlan(
        id: 3,
        code: 'PRO_YEARLY',
        name: 'JLSP Mastery (1 Năm)',
        description: 'Gói học tập toàn diện 12 tháng\n419.000 đ (~35k/tháng)',
        price: 419000,
        dailyTokenLimit: 2000,
        originalPrice: 499000,
        durationDays: 365,
        features: [
          'Học không giới hạn Flashcard Premium',
          'Luyện Shadowing AI chuẩn bản xứ',
          'Kho đề luyện thi JLPT N5 - N1',
          '2.000 Token AI mỗi ngày',
          'Không quảng cáo làm phiền',
        ],
        isActive: true,
        displayOrder: 2,
        badgeLabel: 'Giảm 16%',
        discountPercent: 16,
      ),
      SubscriptionPlan(
        id: 2,
        code: 'PRO_MONTHLY',
        name: 'JLSP Pro (1 Tháng)',
        description: 'Gói luyện tập trải nghiệm hàng tháng\n99.000 đ mỗi 30 ngày',
        price: 99000,
        dailyTokenLimit: 500,
        originalPrice: 129000,
        durationDays: 30,
        features: [
          'Trích xuất lời video không giới hạn',
          '500 Token AI luyện Shadowing mỗi ngày',
          'Đầy đủ Flashcard từ vựng N5 - N1',
          'Hỗ trợ giải đáp ngữ pháp AI',
        ],
        isActive: true,
        displayOrder: 3,
        badgeLabel: 'Gói Trải Nghiệm',
        discountPercent: 23,
      ),
      SubscriptionPlan(
        id: 5,
        code: 'PRO_QUARTERLY',
        name: 'Gói 3 Tháng',
        description: 'Gói trải nghiệm trả 299.000 đ\nmỗi 3 tháng (~99k/tháng)',
        price: 299000,
        dailyTokenLimit: 1000,
        durationDays: 90,
        features: [
          'Học không giới hạn Flashcard Premium',
          'Luyện Shadowing AI chuẩn bản xứ',
          'Không quảng cáo làm phiền',
        ],
        isActive: true,
        displayOrder: 4,
      ),
    ];
  }
}
