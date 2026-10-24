import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<SubscriptionStatus> getMySubscriptionStatus([int? userId]) async {
    int? resolvedUserId = userId;
    if (resolvedUserId == null || resolvedUserId <= 0) {
      final currentUser = await AuthService.instance.getCurrentUser();
      resolvedUserId = currentUser?.id;
    }
    return getMyStatus(userId: resolvedUserId ?? 4);
  }

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

    if (result.status == 'SUCCESS') {
      await _saveLocalSubscription(
        userId: effectiveUserId,
        planId: planId,
        planName: result.planName,
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
    final result = PaymentResponse(
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
    await _saveLocalSubscription(
      userId: userId,
      planId: planId,
      planName: result.planName,
    );
    return result;
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

  Future<SubscriptionStatus> getMyStatus({required int userId}) async {
    final currentUser = await AuthService.instance.getCurrentUser();
    final effectiveUserId = currentUser?.id ?? userId;
    final email = (currentUser?.email ?? '').trim().toLowerCase();
    final username = (currentUser?.username ?? '').trim().toLowerCase();

    // Tài khoản sakura@jlsp.com (ID 4) hoặc demo (ID 10) mặc định sở hữu Gói Trọn Đời
    final isSakuraLifetime =
        effectiveUserId == 4 ||
        effectiveUserId == 10 ||
        email == 'sakura@jlsp.com' ||
        username == 'sakura_learner';

    if (isSakuraLifetime) {
      return SubscriptionStatus(
        isVip: true,
        planId: 2,
        planName: 'Gói Trọn Đời',
        status: 'ACTIVE',
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now().add(const Duration(days: 36500)),
        remainingDays: 36500,
      );
    }

    // Kiểm tra trạng thái đã lưu khi mua thành công của user hiện tại
    final localStatus = await _getLocalSubscription(userId: effectiveUserId);
    if (localStatus != null && localStatus.isVip) {
      return localStatus;
    }

    try {
      final data = await ApiClient.instance.get('$baseUrl/my-status');
      if (data is Map<String, dynamic>) {
        final status = SubscriptionStatus.fromJson(data);
        if (status.isVip) {
          return status;
        }
      }
    } catch (_) {}

    return const SubscriptionStatus(isVip: false, remainingDays: 0);
  }

  Future<void> _saveLocalSubscription({
    required int userId,
    required int planId,
    String? planName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      int durationDays = 365;
      String resolvedName = planName ?? 'Gói 1 Năm';
      final normalizedPlanName = resolvedName.toLowerCase();
      if (planId == 1) {
        durationDays = 90;
        resolvedName = 'Gói 3 Tháng';
      } else if (planId == 2 ||
          normalizedPlanName.contains('trọn đời') ||
          normalizedPlanName.contains('lifetime')) {
        durationDays = 36500;
        resolvedName = 'Gói Trọn Đời';
      }
      final endDate = now.add(Duration(days: durationDays));

      final data = {
        'isVip': true,
        'planId': planId,
        'planName': resolvedName,
        'status': 'ACTIVE',
        'startDate': now.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'remainingDays': durationDays,
      };
      await prefs.setString('user_subscription_$userId', jsonEncode(data));
    } catch (_) {}
  }

  Future<SubscriptionStatus?> _getLocalSubscription({
    required int userId,
  }) async {
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
}
