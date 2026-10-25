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

  String get formattedExpiryDate {
    if (endDate == null) return '';
    return '${endDate!.day.toString().padLeft(2, '0')}/${endDate!.month.toString().padLeft(2, '0')}/${endDate!.year}';
  }

  int get daysRemaining => remainingDays;
}
