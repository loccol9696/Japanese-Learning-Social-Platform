import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
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

  Future<List<SubscriptionPlan>> getPlans() async {
    try {
      final data = await ApiClient.instance.get(
        ApiConstants.subscriptionPlansUrl,
      );
      final List list = data is List ? data : const [];
      return list
          .map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>))
          .where((p) => p.isActive && p.price > 0)
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
      final data = await ApiClient.instance.get(
        ApiConstants.subscriptionPlansUrl,
      );
      final List list = data is List ? data : const [];
      for (final item in list) {
        final plan = SubscriptionPlan.fromJson(item as Map<String, dynamic>);
        final matches = planId != null
            ? plan.id == planId
            : plan.code.toUpperCase() == 'FREE';
        if (matches) return plan;
      }
    } catch (_) {}
    return null;
  }

  Future<PaymentResponse> checkout({
    required int userId,
    required int planId,
    String paymentMethod = 'MOCK',
  }) async {
    final currentUser = await AuthService.instance.getCurrentUser();
    final effectiveUserId = currentUser?.id ?? userId;

    if (paymentMethod == 'VNPAY') {
      throw ApiException(
        statusCode: 501,
        message: 'Thanh toán VNPay chưa được cấu hình trên máy chủ. Gói chưa được đăng ký.',
      );
    }

    if (paymentMethod == 'MOCK') {
      return _createAndConfirmMockOrder(
        userId: effectiveUserId,
        planId: planId,
      );
    }

    PaymentResponse? result;
    try {
      // Người mua do server lấy từ access token, không gửi userId.
      final data = await ApiClient.instance.post(
        '$baseUrl/checkout',
        body: {'planId': planId, 'paymentMethod': paymentMethod},
      );
      if (data is Map<String, dynamic>) {
        result = PaymentResponse.fromJson(data);
      }
    } catch (_) {}

    if (result == null) {
      final isVNPay = paymentMethod == 'VNPAY';
      final ts = DateTime.now().millisecondsSinceEpoch;
      final txnRef = '${isVNPay ? 'VNP' : 'MOCK'}_$ts';
      final int amount = planId == 1 ? 299000 : (planId == 2 ? 699000 : 419000);
      final String resolvedPlanName = planId == 1
          ? 'Gói 3 Tháng'
          : (planId == 2 ? 'Gói Trọn Đời' : 'Gói 1 Năm');
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

    return result;
  }

  Future<PaymentResponse> _createAndConfirmMockOrder({
    required int userId,
    required int planId,
  }) async {
    final token = await TokenStorage.instance.getAccessToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
    final createResponse = await _client
        .post(
          Uri.parse('${ApiConstants.baseUrl}/payments/create-order'),
          headers: headers,
          body: jsonEncode({'userId': userId, 'planId': planId}),
        )
        .timeout(const Duration(seconds: 5));
    if (createResponse.statusCode != 200 && createResponse.statusCode != 201) {
      throw ApiException(
        statusCode: createResponse.statusCode,
        message: 'Không thể tạo đơn mua gói trên máy chủ.',
      );
    }

    final order =
        (jsonDecode(createResponse.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final orderCode = order['orderCode']?.toString();
    final verificationCode = order['verificationCode']?.toString();
    if (orderCode == null || verificationCode == null) {
      throw const FormatException('Máy chủ trả về đơn mua gói không đầy đủ.');
    }

    final confirmResponse = await _client
        .post(
          Uri.parse('${ApiConstants.baseUrl}/payments/confirm'),
          headers: headers,
          body: jsonEncode({
            'orderCode': orderCode,
            'verificationCode': verificationCode,
          }),
        )
        .timeout(const Duration(seconds: 5));
    if (confirmResponse.statusCode != 200) {
      throw ApiException(
        statusCode: confirmResponse.statusCode,
        message: 'Đơn mua gói chưa được xác nhận.',
      );
    }

    final confirmed =
        (jsonDecode(confirmResponse.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    return PaymentResponse(
      paymentId: (confirmed['id'] as num?)?.toInt() ?? 0,
      transactionRef: orderCode,
      amount: (confirmed['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: 'MOCK',
      status: confirmed['status']?.toString() ?? 'SUCCESS',
      planId: (confirmed['planId'] as num?)?.toInt() ?? planId,
      planName: confirmed['planName']?.toString(),
      paidAt: DateTime.now(),
      createdAt: DateTime.tryParse(confirmed['createdAt']?.toString() ?? ''),
    );
  }

  Future<void> confirmVnpayPayment({
    required int userId,
    required int planId,
    String? planName,
  }) async {
    throw ApiException(
      statusCode: 501,
      message: 'Không thể xác nhận VNPay thủ công. Gói chỉ được kích hoạt sau khi máy chủ xác nhận giao dịch.',
    );
  }

  /// Gói hiện tại của người dùng. BE chưa có endpoint trạng thái gói riêng nên
  /// đọc từ hồ sơ (`subscriptionPlanName`, `vipExpiresAt`) rồi đối chiếu tên với
  /// danh sách gói để biết mã gói. Lỗi mạng coi như chưa có gói.
  Future<SubscriptionStatus> getMyStatus() async {
    const notVip = SubscriptionStatus(isVip: false, remainingDays: 0);
    try {
      final results = await Future.wait<Object?>([
        ApiClient.instance.get(ApiConstants.profileUrl),
        _paidPlansOrEmpty(),
      ]);
      final profile = results[0];
      final plans = results[1] as List<SubscriptionPlan>;
      if (profile is! Map<String, dynamic>) return notVip;

      final planName = (profile['subscriptionPlanName'] as String?)?.trim();
      if (planName == null || planName.isEmpty) return notVip;

      // Giống BE: có gói và chưa hết hạn (hạn trống = còn hiệu lực).
      final now = DateTime.now();
      final expiresAt = DateTime.tryParse(
        profile['vipExpiresAt']?.toString() ?? '',
      );
      if (expiresAt != null && !expiresAt.isAfter(now)) return notVip;

      SubscriptionPlan? plan;
      for (final candidate in plans) {
        if (candidate.name.trim().toLowerCase() == planName.toLowerCase()) {
          plan = candidate;
          break;
        }
      }

      final remainingDays = expiresAt == null
          ? (plan?.durationDays ?? 0)
          : (expiresAt.difference(now).inHours / 24).ceil();

      return SubscriptionStatus(
        isVip: true,
        planId: plan?.id,
        planName: planName,
        status: 'ACTIVE',
        endDate: expiresAt,
        remainingDays: remainingDays,
      );
    } catch (_) {
      return notVip;
    }
  }

  Future<List<SubscriptionPlan>> _paidPlansOrEmpty() async {
    try {
      return await getPlans();
    } catch (_) {
      return const [];
    }
  }
}
