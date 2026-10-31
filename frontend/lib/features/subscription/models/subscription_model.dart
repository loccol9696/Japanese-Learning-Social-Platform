/// Quan hệ giữa gói đang chọn và gói người dùng đang dùng.
enum PlanChangeKind {
  /// Chưa có gói trả phí.
  subscribe,

  /// Mua lại đúng gói đang dùng (cộng thêm thời hạn).
  renew,

  /// Gói có giá cao hơn gói đang dùng.
  upgrade,

  /// Gói có giá thấp hơn gói đang dùng (hoặc không xác định được gói hiện tại).
  change,
}

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
      // BE trả một chuỗi: tách theo dòng hoặc dấu phẩy, nhưng giữ nguyên
      // dấu phân cách hàng nghìn trong số ("2,000 token").
      parsedFeatures = rawFeatures
          .split(RegExp(r'\n|,(?!\d{3}\b)'))
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

  bool get isLifetime => durationDays >= 3650;

  /// Số tháng của gói; null với gói trọn đời hoặc dưới một tháng.
  int? get months {
    if (isLifetime || durationDays < 30) return null;
    return (durationDays / 30).round();
  }

  /// Phần trăm tiết kiệm so với việc mua [baseline] lặp lại theo tháng.
  /// Null khi không so sánh được hoặc không rẻ hơn.
  int? savingsPercentVs(SubscriptionPlan baseline) {
    final planMonths = months;
    final baselineMonths = baseline.months;
    if (planMonths == null || baselineMonths == null) return null;
    if (baseline.price <= 0 || price <= 0) return null;
    final perMonth = price / planMonths;
    final baselinePerMonth = baseline.price / baselineMonths;
    final percent = ((1 - perMonth / baselinePerMonth) * 100).round();
    return percent > 0 ? percent : null;
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

  /// Hạn mức token AI mỗi ngày, có dấu chấm ngăn cách hàng nghìn ("2.000").
  String get formattedTokenLimit => _groupDigits(dailyTokenLimit);

  static String _formatNumber(int number) => '${_groupDigits(number)} đ';

  static String _groupDigits(int number) {
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
    return buffer.toString().split('').reversed.join('');
  }
}

class PaymentResponse {
  final int paymentId;
  final String transactionRef;
  final double amount;
  final String paymentMethod;
  final String status;
  final int? planId;
  final String? planName;
  final int? subscriptionId;
  final String? paymentUrl;
  final DateTime? paidAt;
  final DateTime? createdAt;

  const PaymentResponse({
    required this.paymentId,
    required this.transactionRef,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.planId,
    this.planName,
    this.subscriptionId,
    this.paymentUrl,
    this.paidAt,
    this.createdAt,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      paymentId: json['paymentId'] as int? ?? 0,
      transactionRef: json['transactionRef'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? 'MOCK',
      status: json['status'] as String? ?? 'SUCCESS',
      planId: json['planId'] as int?,
      planName: json['planName'] as String?,
      subscriptionId: json['subscriptionId'] as int?,
      paymentUrl: json['paymentUrl'] as String?,
      paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
    );
  }
}

class SubscriptionStatus {
  final bool isVip;
  final int? subscriptionId;
  final int? planId;
  final String? planName;
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final int remainingDays;

  const SubscriptionStatus({
    required this.isVip,
    this.subscriptionId,
    this.planId,
    this.planName,
    this.status,
    this.startDate,
    this.endDate,
    required this.remainingDays,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      isVip: json['isVip'] as bool? ?? false,
      subscriptionId: json['subscriptionId'] as int?,
      planId: json['planId'] as int?,
      planName: json['planName'] as String?,
      status: json['status'] as String?,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'])
          : null,
      remainingDays: (json['remainingDays'] as num?)?.toInt() ?? 0,
    );
  }

  bool get hasActiveSubscription => isVip;
  bool get isLifetime {
    final normalizedName = (planName ?? '').toLowerCase();
    return normalizedName.contains('trọn đời') ||
        normalizedName.contains('lifetime') ||
        remainingDays >= 3650;
  }

  String get formattedExpiryDate => endDate == null ? '' : formatDate(endDate!);

  static String formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  /// Hạn dùng dự kiến sau khi mua [plan]. Khớp cách BE xác nhận đơn: thời hạn
  /// gói mới được cộng dồn vào hạn hiện tại (nếu còn hiệu lực), không quy đổi
  /// phần còn lại của gói cũ.
  DateTime expiryAfterBuying(SubscriptionPlan plan, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final end = endDate;
    final base = isVip && end != null && end.isAfter(current) ? end : current;
    return base.add(Duration(days: plan.durationDays));
  }

  int get daysRemaining => remainingDays;
}
