import 'package:flutter/material.dart';

import '../../auth/data/services/auth_service.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../widgets/checkout_bottom_sheet.dart';
import '../widgets/subscription_success_dialog.dart';
import '../../../core/theme/app_palette.dart';

class SubscriptionScreen extends StatefulWidget {
  final int userId;

  /// Cho phép thay dịch vụ khi kiểm thử; mặc định dùng dịch vụ thật.
  final SubscriptionService? service;

  const SubscriptionScreen({super.key, this.userId = 1, this.service});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static const _defaultFeatures = [
    'Tạo bộ thẻ không giới hạn',
    'Học và ôn tập không quảng cáo',
    'Luyện nghe và tự luận không giới hạn lượt',
    'Đồng bộ trên mọi thiết bị',
  ];

  late final SubscriptionService _service =
      widget.service ?? SubscriptionService();
  List<SubscriptionPlan> _plans = [];
  SubscriptionStatus? _userStatus;
  bool _isLoading = true;
  String? _loadError;
  int? _selectedPlanId;
  String? _appliedPromoCode;
  int? _resolvedUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      int activeUserId = widget.userId;
      try {
        final currentUser = await AuthService.instance.getCurrentUser();
        if (currentUser?.id != null) activeUserId = currentUser!.id!;
      } catch (_) {}
      _resolvedUserId = activeUserId;

      final results = await Future.wait<Object?>([
        _service.getPlans(),
        _service.getMyStatus(),
      ]);
      final plans = List<SubscriptionPlan>.from(
        results[0] as List<SubscriptionPlan>,
      )..sort((a, b) => b.durationDays.compareTo(a.durationDays));

      if (mounted) {
        setState(() {
          _plans = plans;
          _userStatus = results[1] as SubscriptionStatus;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = error.toString();
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Gói đang dùng / gói đang chọn
  // ---------------------------------------------------------------------------

  bool get _isVip => _userStatus?.isVip ?? false;

  /// Gói đang dùng, tra theo mã gói do dịch vụ đối chiếu từ hồ sơ.
  SubscriptionPlan? get _currentPlan {
    final planId = _userStatus?.planId;
    if (!_isVip || planId == null) return null;
    for (final plan in _plans) {
      if (plan.id == planId) return plan;
    }
    return null;
  }

  /// Gói rẻ nhất tính theo tháng, làm mốc tính phần trăm tiết kiệm.
  SubscriptionPlan? get _baselinePlan {
    SubscriptionPlan? baseline;
    for (final plan in _plans) {
      if (plan.months == null) continue;
      if (baseline == null || plan.durationDays < baseline.durationDays) {
        baseline = plan;
      }
    }
    return baseline;
  }

  /// Mặc định: chưa có gói thì chọn gói đầu danh sách; đang có gói thì chọn gói
  /// cao hơn gần nhất, không còn gói cao hơn thì chọn chính gói đang dùng.
  SubscriptionPlan? get _defaultPlan {
    if (_plans.isEmpty) return null;
    final current = _currentPlan;
    if (current == null) return _plans.first;
    SubscriptionPlan? nextUp;
    for (final plan in _plans) {
      if (plan.price <= current.price) continue;
      if (nextUp == null || plan.price < nextUp.price) nextUp = plan;
    }
    return nextUp ?? current;
  }

  SubscriptionPlan? get _selectedPlan {
    for (final plan in _plans) {
      if (plan.id == _selectedPlanId) return plan;
    }
    return _defaultPlan;
  }

  /// Gói đang chọn, đã áp mã khuyến mãi (nếu có), để thanh toán.
  SubscriptionPlan? get _checkoutPlan {
    final base = _selectedPlan;
    if (base == null) return null;
    final code = _appliedPromoCode;
    if (code == null || code.isEmpty) return base;
    return SubscriptionPlan(
      id: base.id,
      name: base.name,
      code: base.code,
      description: base.description,
      price: (base.price * 0.9).roundToDouble(),
      dailyTokenLimit: base.dailyTokenLimit,
      originalPrice: base.originalPrice ?? base.price,
      durationDays: base.durationDays,
      features: base.features,
      isActive: base.isActive,
      displayOrder: base.displayOrder,
      badgeLabel: base.badgeLabel,
      discountPercent: base.discountPercent,
    );
  }

  PlanChangeKind _kindFor(SubscriptionPlan plan) {
    if (!_isVip) return PlanChangeKind.subscribe;
    final current = _currentPlan;
    if (current == null) return PlanChangeKind.change;
    if (plan.id == current.id) return PlanChangeKind.renew;
    return plan.price > current.price
        ? PlanChangeKind.upgrade
        : PlanChangeKind.change;
  }

  /// Gói trọn đời đang sở hữu thì không còn gì để gia hạn.
  bool _canPurchase(SubscriptionPlan plan) =>
      !(_kindFor(plan) == PlanChangeKind.renew && plan.isLifetime);

  // ---------------------------------------------------------------------------
  // Thanh toán
  // ---------------------------------------------------------------------------

  void _openCheckout() {
    final plan = _checkoutPlan;
    if (plan == null || !_canPurchase(plan)) return;
    final kind = _kindFor(plan);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) => CheckoutBottomSheet(
        plan: plan,
        userId: _resolvedUserId ?? widget.userId,
        kind: kind,
        currentStatus: _userStatus,
        onSuccess: (payment) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => SubscriptionSuccessDialog(
              payment: payment,
              plan: plan,
              kind: kind,
              onDismiss: () {
                // Đóng màn hình đăng ký gói và chuyển về trang Hồ sơ cá nhân (trả về true)
                Navigator.of(context).pop(true);
              },
            ),
          );
        },
      ),
    );
  }

  void _showPromoCodeDialog() {
    final controller = TextEditingController(text: _appliedPromoCode ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.discount_rounded, color: AppPalette.info, size: 24),
            const SizedBox(width: 8),
            Text(
              'Nhập mã khuyến mãi',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppPalette.textPrimary,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nhập mã giảm giá từ Kotoba hoặc cộng tác viên để nhận ưu đãi đặc biệt:',
              style: TextStyle(fontSize: 13, color: AppPalette.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: AppPalette.textPrimary),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'VD: KOTOBA2026, JLPTN1',
                hintStyle: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppPalette.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppPalette.info, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Hủy',
              style: TextStyle(color: AppPalette.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              Navigator.of(ctx).pop();
              if (code.isNotEmpty) {
                setState(() => _appliedPromoCode = code);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã áp dụng mã $code thành công!'),
                    backgroundColor: AppPalette.success,
                  ),
                );
              }
            },
            child: Text(
              'Áp dụng',
              style: TextStyle(
                color: AppPalette.onAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final showBottomBar =
        !_isLoading && _loadError == null && _checkoutPlan != null;

    return Scaffold(
      backgroundColor: AppPalette.background,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: AppPalette.background,
            boxShadow: [
              BoxShadow(
                color: AppPalette.videoScrim.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildBody()),
                if (showBottomBar) _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Quay lại',
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppPalette.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppPalette.accent));
    }
    if (_loadError != null) return _buildError();

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppPalette.accent,
      backgroundColor: AppPalette.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        children: [
          _buildHero(),
          if (_isVip) ...[const SizedBox(height: 20), _buildCurrentPlanCard()],
          const SizedBox(height: 24),
          if (_plans.isEmpty)
            _buildEmptyPlans()
          else ...[
            _buildSectionTitle(_isVip ? 'Chọn gói muốn áp dụng' : 'Chọn gói'),
            const SizedBox(height: 12),
            for (final plan in _plans) _buildPlanCard(plan),
            const SizedBox(height: 12),
            _buildFeatureCard(),
            const SizedBox(height: 8),
            _buildPromoLink(),
            const SizedBox(height: 8),
            _buildDisclaimer(),
          ],
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppPalette.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadData,
              child: Text(
                'Thử lại',
                style: TextStyle(color: AppPalette.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlans() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        'Hiện chưa có gói nào để đăng ký. Vui lòng quay lại sau.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppPalette.textSecondary, height: 1.4),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isVip ? 'GÓI THÀNH VIÊN' : 'KOTOBA PREMIUM',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppPalette.accent,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isVip
              ? 'Nâng cấp hoặc\nđổi gói của bạn'
              : 'Học thoải mái hơn,\nkhông giới hạn',
          style: TextStyle(
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: AppPalette.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppPalette.textPrimary,
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    final status = _userStatus!;
    final plan = _currentPlan;
    final isLifetime = plan?.isLifetime ?? status.isLifetime;
    final name = status.planName ?? plan?.name ?? 'Premium';
    final gold = AppPalette.gold;

    final progress = !isLifetime && plan != null && plan.durationDays > 0
        ? (status.remainingDays / plan.durationDays).clamp(0.0, 1.0).toDouble()
        : null;
    final detail = isLifetime
        ? 'Sở hữu trọn đời'
        : [
            'Còn ${status.remainingDays} ngày',
            if (status.endDate != null) 'hết hạn ${status.formattedExpiryDate}',
          ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: gold,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gói đang dùng',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: gold,
                backgroundColor: gold.withValues(alpha: 0.2),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            detail,
            style: TextStyle(fontSize: 12.5, color: AppPalette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan) {
    final isSelected = _selectedPlan?.id == plan.id;
    final isCurrent = _kindFor(plan) == PlanChangeKind.renew;
    final baseline = _baselinePlan;
    final savings = baseline == null ? null : plan.savingsPercentVs(baseline);
    final customBadge = plan.badgeLabel?.trim() ?? '';

    final String? badge;
    if (isCurrent) {
      badge = plan.isLifetime ? 'Đang sở hữu' : 'Đang dùng';
    } else if (customBadge.isNotEmpty) {
      badge = customBadge;
    } else if (savings != null) {
      badge = 'Tiết kiệm $savings%';
    } else {
      badge = null;
    }
    final badgeColor = isCurrent ? AppPalette.success : AppPalette.accent;

    final subtitle = [
      plan.durationLabel,
      if (plan.dailyTokenLimit > 0) '${plan.formattedTokenLimit} token AI/ngày',
    ].join(' · ');
    final months = plan.months;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.accentSoft : AppPalette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppPalette.accent : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _selectedPlanId = plan.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  _buildRadio(isSelected),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(height: 8),
                          _buildChip(badge, badgeColor),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _compactPrice(plan.formattedPrice),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                      if (plan.formattedOriginalPrice != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _compactPrice(plan.formattedOriginalPrice!),
                          style: TextStyle(
                            fontSize: 12,
                            decoration: TextDecoration.lineThrough,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ],
                      if (months != null && months > 1) ...[
                        const SizedBox(height: 2),
                        Text(
                          '≈ ${_compactPrice(plan.pricePerMonth)}/tháng',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppPalette.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRadio(bool isSelected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppPalette.accent : AppPalette.textSecondary,
          width: 1.6,
        ),
      ),
      alignment: Alignment.center,
      child: isSelected
          ? Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppPalette.accent,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// Quyền lợi của gói đang chọn; gói chưa khai báo thì dùng danh sách chung.
  Widget _buildFeatureCard() {
    final plan = _selectedPlan;
    if (plan == null) return const SizedBox.shrink();
    final features = plan.features.isNotEmpty
        ? plan.features
        : _defaultFeatures;
    final description = plan.description.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quyền lợi của gói',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppPalette.textPrimary,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppPalette.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppPalette.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPromoLink() {
    final plan = _selectedPlan;
    if (plan == null || !_canPurchase(plan)) return const SizedBox.shrink();
    final applied = _appliedPromoCode != null;

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _showPromoCodeDialog,
        icon: Icon(
          applied ? Icons.check_circle_rounded : Icons.discount_outlined,
          size: 18,
          color: applied ? AppPalette.success : AppPalette.accent,
        ),
        label: Text(
          applied ? 'Đã áp dụng mã: $_appliedPromoCode' : 'Nhập mã khuyến mãi',
          style: TextStyle(
            fontSize: 13,
            color: applied ? AppPalette.success : AppPalette.accent,
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Thanh toán một lần cho mỗi gói, không tự động gia hạn. Khi mua thêm '
        'hoặc đổi gói, gói mới có hiệu lực ngay và thời hạn còn lại được cộng dồn.',
        style: TextStyle(
          fontSize: 11.5,
          height: 1.4,
          color: AppPalette.textSecondary,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final plan = _checkoutPlan!;
    final kind = _kindFor(plan);
    final canPurchase = _canPurchase(plan);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      color: AppPalette.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canPurchase) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thanh toán',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.textSecondary,
                        ),
                      ),
                      Text(
                        _compactPrice(plan.formattedPrice),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppPalette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _expiryHint(plan),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppPalette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.accent,
                foregroundColor: AppPalette.onAccent,
                disabledBackgroundColor: AppPalette.surfaceHigh,
                disabledForegroundColor: AppPalette.textSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: canPurchase ? _openCheckout : null,
              child: Text(
                _ctaLabel(plan, kind, canPurchase),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _ctaLabel(SubscriptionPlan plan, PlanChangeKind kind, bool canBuy) {
    final duration = plan.durationLabel.toLowerCase();
    return switch (kind) {
      PlanChangeKind.subscribe => 'Nâng cấp Premium',
      PlanChangeKind.renew =>
        canBuy ? 'Gia hạn gói $duration' : 'Bạn đang sở hữu gói này',
      PlanChangeKind.upgrade => 'Nâng cấp lên gói $duration',
      PlanChangeKind.change => 'Đổi sang gói $duration',
    };
  }

  /// Hạn dùng dự kiến nếu mua gói [plan] ngay bây giờ.
  String _expiryHint(SubscriptionPlan plan) {
    if (plan.isLifetime) return 'Sở hữu trọn đời';
    final status = _userStatus;
    final expiry = status != null && status.isVip
        ? status.expiryAfterBuying(plan)
        : DateTime.now().add(Duration(days: plan.durationDays));
    final label = _isVip ? 'Hạn dùng mới' : 'Hiệu lực đến';
    return '$label\n${SubscriptionStatus.formatDate(expiry)}';
  }

  /// "890.000 đ" -> "890.000đ" cho gọn trên thẻ gói.
  static String _compactPrice(String formatted) =>
      formatted.replaceAll(' ', '');
}
