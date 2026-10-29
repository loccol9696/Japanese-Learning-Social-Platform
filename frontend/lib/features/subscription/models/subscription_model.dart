class SubscriptionPlan {
  final int id;
  final String name;
  final String code;
  final String description;
  final double price;
  final int dailyTokenLimit;
  final double? originalPrice;
  final int durationDays;
  final List<String> features;
  final bool isActive;
  final int displayOrder;
  final String? badgeLabel;
  final int? discountPercent;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    this.code = '',
    required this.description,
    required this.price,
    this.dailyTokenLimit = 0,
    this.originalPrice,
    required this.durationDays,
    required this.features,
    this.isActive = true,
    this.displayOrder = 0,
    this.badgeLabel,
    this.discountPercent,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    var rawFeatures = json['features'];
    List<String> parsedFeatures = [];
    if (rawFeatures is List) {
      parsedFeatures = rawFeatures.map((e) => e.toString()).toList();
    } else if (rawFeatures is String) {
      parsedFeatures = rawFeatures
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return SubscriptionPlan(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      dailyTokenLimit: (json['dailyTokenLimit'] as num?)?.toInt() ?? 0,
      originalPrice: (json['originalPrice'] as num?)?.toDouble(),
      durationDays: json['durationDays'] as int? ?? 0,
      features: parsedFeatures,
      isActive: json['isActive'] as bool? ?? true,
      displayOrder: json['displayOrder'] as int? ?? 0,
      badgeLabel: json['badgeLabel'] as String?,
      discountPercent: json['discountPercent'] as int?,
    );
  }

  String get formattedPrice {
    final intPrice = price.round();
    return _formatNumber(intPrice);
  }

  String? get formattedOriginalPrice {
    if (originalPrice == null) return null;
    return _formatNumber(originalPrice!.round());
  }

  String get pricePerMonth {
    if (durationDays <= 0) return formattedPrice;
    final months = durationDays / 30;
    if (months <= 0) return formattedPrice;
    final perMonth = (price / months).round();
    return _formatNumber(perMonth);
  }

  String get durationLabel {
    if (durationDays >= 3650) return 'Trọn đời';
    if (durationDays >= 365) return '${(durationDays / 365).round()} Năm';
    if (durationDays >= 30) return '${(durationDays / 30).round()} Tháng';
    return '$durationDays Ngày';
  }

  static String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return '${buffer.toString().split('').reversed.join('')} đ';
  }
}

/// Đơn thanh toán chuyển khoản VietQR do server tạo. Số tiền, mã chuyển khoản và thông tin tài khoản nhận đều lấy từ
/// server; app không tự tính hay ghi cứng.
class PaymentOrder {
  final int id;
  final String orderCode;

  /// Nội dung chuyển khoản người dùng phải ghi đúng (cũng là mã đơn).
  final String transferMemo;
  final double amount;
  final double? paidAmount;

  /// PENDING, SUCCESS, EXPIRED, CANCELLED, NEEDS_REVIEW (hoặc FAILED).
  final String status;
  final int? planId;
  final String? planName;
  final String? qrUrl;
  final String bankName;
  final String accountNo;
  final String accountName;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? completedAt;

  const PaymentOrder({
    required this.id,
    required this.orderCode,
    required this.transferMemo,
    required this.amount,
    this.paidAmount,
    required this.status,
    this.planId,
    this.planName,
    this.qrUrl,
    this.bankName = '',
    this.accountNo = '',
    this.accountName = '',
    this.expiresAt,
    this.createdAt,
    this.completedAt,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) =>
        json[key] != null ? DateTime.tryParse(json[key].toString()) : null;
    final code = json['orderCode']?.toString() ?? '';
    return PaymentOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      orderCode: code,
      transferMemo: json['transferMemo']?.toString() ?? code,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble(),
      status: json['status']?.toString() ?? 'PENDING',
      planId: (json['planId'] as num?)?.toInt(),
      planName: json['planName']?.toString(),
      qrUrl: json['qrUrl']?.toString(),
      bankName: json['bankName']?.toString() ?? '',
      accountNo: json['accountNo']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      expiresAt: date('expiresAt'),
      createdAt: date('createdAt'),
      completedAt: date('completedAt'),
    );
  }

  bool get isPaid => status == 'SUCCESS';
  bool get isExpired => status == 'EXPIRED';
  bool get isCancelled => status == 'CANCELLED' || status == 'FAILED';

  /// Đã nhận tiền nhưng chưa đủ hoặc về muộn: cần người quản trị xem xét.
  bool get needsReview => status == 'NEEDS_REVIEW';

  /// Không còn thay đổi nếu chỉ chờ thêm (không tính NEEDS_REVIEW vì khách có thể chuyển bù).
  bool get isFinished => isPaid || isExpired || isCancelled;

  /// Số tiền còn thiếu khi đã chuyển một phần.
  double get remainingAmount {
    final left = amount - (paidAmount ?? 0);
    return left > 0 ? left : 0;
  }
}

/// Gói thành viên hiện tại của người đang đăng nhập, lấy từ server (`/payments/my-subscription`).
class SubscriptionStatus {
  final bool isVip;
  final int? planId;
  final String? planCode;
  final String? planName;
  final DateTime? endDate;
  final bool lifetime;
  final int remainingDays;
  final int dailyTokenLimit;
  final int tokensUsedToday;
  final int tokensRemainingToday;

  const SubscriptionStatus({
    required this.isVip,
    this.planId,
    this.planCode,
    this.planName,
    this.endDate,
    this.lifetime = false,
    required this.remainingDays,
    this.dailyTokenLimit = 0,
    this.tokensUsedToday = 0,
    this.tokensRemainingToday = 0,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isVip: json['vip'] as bool? ?? false,
      planId: (json['planId'] as num?)?.toInt(),
      planCode: json['planCode']?.toString(),
      planName: json['planName']?.toString(),
      endDate: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      lifetime: json['lifetime'] as bool? ?? false,
      remainingDays: (json['remainingDays'] as num?)?.toInt() ?? 0,
      dailyTokenLimit: (json['dailyTokenLimit'] as num?)?.toInt() ?? 0,
      tokensUsedToday: (json['tokensUsedToday'] as num?)?.toInt() ?? 0,
      tokensRemainingToday:
          (json['tokensRemainingToday'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasActiveSubscription => isVip;
  bool get isLifetime => lifetime;

  String get formattedExpiryDate {
    if (endDate == null) return '';
    return '${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}';
  }

  int get daysRemaining => remainingDays;
}
