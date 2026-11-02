import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../../home/presentation/screens/home_screen.dart';
import '../../home/presentation/widgets/bottom_nav_dock.dart';
import 'subscription_success_screen.dart';
import '../widgets/vietqr_payment_sheet.dart';
import '../../../core/theme/app_palette.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static Color get _linkBlue => AppPalette.info;

  final SubscriptionService _service = SubscriptionService();
  final TextEditingController _promoController = TextEditingController();
  List<SubscriptionPlan> _plans = [];
  SubscriptionStatus? _userStatus;
  bool _isLoading = true;
  String? _loadError;
  int _selectedPlanIndex = 0; // Default to "Trọn đời" (first / best plan)
  bool _isCreatingOrder = false;

  // Voucher / Promo code state
  bool _isCheckingPromo = false;
  String? _appliedPromoCode;
  int? _discountPercent;
  double? _discountAmount;
  String? _promoSuccessMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  double _calculatePayablePrice(double basePrice) {
    if (_appliedPromoCode == null) return basePrice;
    double discount = 0;
    if (_discountPercent != null && _discountPercent! > 0) {
      discount = (basePrice * _discountPercent!) / 100.0;
    } else if (_discountAmount != null && _discountAmount! > 0) {
      discount = _discountAmount!;
    }
    final finalPrice = basePrice - discount;
    return finalPrice < 1000 ? 1000 : finalPrice;
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      AppToast.showError('Vui lòng nhập mã khuyến mãi / voucher', context: context);
      return;
    }
    final plan = _currentSelectedPlan;
    setState(() => _isCheckingPromo = true);
    try {
      final res = await _service.verifyPromoCode(code, planId: plan?.id);
      if (mounted) {
        setState(() {
          _appliedPromoCode = res['code']?.toString() ?? code.toUpperCase();
          _discountPercent = (res['discountPercent'] as num?)?.toInt();
          _discountAmount = (res['discountAmount'] as num?)?.toDouble();
          _promoSuccessMessage = res['description']?.toString() ?? 'Đã áp dụng mã ưu đãi!';
        });
        AppToast.showSuccess('Áp dụng mã $_appliedPromoCode thành công!', context: context);
      }
    } on ApiException catch (e) {
      if (mounted) AppToast.showError(e.message, context: context);
    } catch (_) {
      if (mounted) AppToast.showError('Mã ưu đãi không hợp lệ hoặc đã hết hạn', context: context);
    } finally {
      if (mounted) setState(() => _isCheckingPromo = false);
    }
  }

  void _removePromoCode() {
    setState(() {
      _appliedPromoCode = null;
      _discountPercent = null;
      _discountAmount = null;
      _promoSuccessMessage = null;
      _promoController.clear();
    });
    AppToast.showSuccess('Đã hủy áp dụng mã ưu đãi', context: context);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _service.getPlans(),
        _service.getMyStatus(),
      ]);
      final plans = results[0] as List<SubscriptionPlan>;
      final status = results[1] as SubscriptionStatus;

      // Sắp xếp các gói: Trọn đời lên đầu, rồi 1 Năm, rồi 3 Tháng (chuẩn như Mazii)
      final sortedPlans = List<SubscriptionPlan>.from(plans);
      sortedPlans.sort((a, b) {
        if (a.durationDays >= 3650) return -1;
        if (b.durationDays >= 3650) return 1;
        return b.durationDays.compareTo(a.durationDays);
      });

      if (mounted) {
        setState(() {
          _plans = sortedPlans;
          _userStatus = status;
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

  bool get _isUserLifetimeVip => (_userStatus?.isVip ?? false) && (_userStatus?.isLifetime ?? false);

  /// Số ngày của gói người dùng đang có (tra theo mã gói trong danh sách gói bán); trọn đời tính là lớn nhất.
  int get _currentOwnedDurationDays {
    final status = _userStatus;
    if (status == null || !status.isVip) return 0;
    if (status.isLifetime) return 36500;
    for (final plan in _plans) {
      if (plan.id == status.planId) return plan.durationDays;
    }
    return 0;
  }

  List<SubscriptionPlan> get _visiblePlans => _plans;

  SubscriptionPlan? get _currentSelectedPlan {
    final visible = _visiblePlans;
    if (visible.isEmpty) return null;
    final basePlan =
        (_selectedPlanIndex >= 0 && _selectedPlanIndex < visible.length)
        ? visible[_selectedPlanIndex]
        : visible.first;
    return basePlan;
  }

  Future<void> _openCheckout() async {
    if (_isCreatingOrder) return;
    if (_isUserLifetimeVip) {
      AppToast.showSuccess('Bạn đang sở hữu Gói Trọn Đời cao cấp nhất!', context: context);
      return;
    }

    final plan = _currentSelectedPlan;
    if (plan == null) return;

    // Server tạo đơn (số tiền, mã chuyển khoản, QR); app chỉ hiển thị và chờ server nhận tiền.
    setState(() => _isCreatingOrder = true);
    PaymentOrder order;
    try {
      order = await _service.createOrder(planId: plan.id, promoCode: _appliedPromoCode);
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
      return;
    } catch (_) {
      if (mounted) AppToast.showError('Không tạo được đơn thanh toán. Vui lòng thử lại.', context: context);
      return;
    } finally {
      if (mounted) setState(() => _isCreatingOrder = false);
    }
    if (!mounted) return;

    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VietQrPaymentSheet(order: order, plan: plan),
      ),
    );
    if (!mounted) return;
    if (paid == true) {
      final action = await showSubscriptionSuccess(context, order: order, plan: plan);
      if (!mounted) return;
      // Đóng màn đăng ký gói và về trang cá nhân (trả về true để màn đó tải lại trạng thái).
      Navigator.of(context).pop(true);
      if (action == SubscriptionSuccessAction.startLearning) HomeScreen.tabRequest.value = BottomNavDock.homeIndex;
    } else {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background, // Deep backdrop on web
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440), // Mobile container
          decoration: BoxDecoration(
            color: AppPalette.background, // Rich Dark Navy Background
            boxShadow: [
              BoxShadow(
                color: AppPalette.videoScrim.withValues(alpha: 0.25),
                blurRadius: 30,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 1. Top Bar (Close button on top right)
                _buildTopBar(),

                // 2. Main Scrollable Content
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppPalette.info,
                          ),
                        )
                      : _loadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppPalette.textSecondary),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppPalette.info,
                          backgroundColor: AppPalette.background,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title & Brand Glow Badge
                                _buildHeroHeader(),
                                const SizedBox(height: 24),

                                // Feature Checklist with Cute Green Icons
                                _buildFeatureChecklist(),
                                const SizedBox(height: 18),

                                // Current active VIP info if applicable
                                if (_userStatus != null &&
                                    _userStatus!.isVip) ...[
                                  _buildCurrentVipBadge(),
                                  const SizedBox(height: 16),
                                ],

                                // Plan Selection Stack (Vertical List)
                                _buildPlanSelectionCards(),
                                const SizedBox(height: 16),

                                // Voucher / Promo Code input section
                                _buildPromoCodeSection(),
                                const SizedBox(height: 16),

                                // Terms & Auto-renew disclaimer
                                _buildDisclaimer(),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                ),

                // 3. Sticky Bottom Bar with Promo Code & CTA
                _buildStickyBottomBar(),
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
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppPalette.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KOTOBA PREMIUM',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: _linkBlue,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Học thoải mái hơn,\nkhông giới hạn',
          style: TextStyle(
            fontSize: 30,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: AppPalette.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureChecklist() {
    const features = [
      '2.000 Token AI/ngày cho mọi gói Premium',
      'Tạo bộ thẻ và Flashcard không giới hạn',
      'Học và ôn tập không quảng cáo',
      'Luyện nghe và tự luận không giới hạn lượt',
      'Đồng bộ trên mọi thiết bị',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final feature in features)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.check_rounded, size: 18, color: _linkBlue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    feature,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppPalette.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCurrentVipBadge() {
    if (_userStatus == null || !_userStatus!.isVip) {
      return const SizedBox.shrink();
    }

    final isLifetime = _isUserLifetimeVip;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isLifetime ? AppPalette.warningContainer : AppPalette.warningContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLifetime ? AppPalette.success : AppPalette.warning,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLifetime
                ? Icons.workspace_premium_rounded
                : Icons.verified_rounded,
            color: isLifetime
                ? AppPalette.success
                : AppPalette.warning,
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLifetime
                      ? 'BẠN ĐANG SỞ HỮU GÓI CAO CẤP NHẤT'
                      : 'GÓI ĐANG HOẠT ĐỘNG',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: isLifetime
                        ? AppPalette.success
                        : AppPalette.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isLifetime
                      ? 'Gói Trọn Đời (Lifetime) • Toàn bộ đặc quyền mở khóa vĩnh viễn'
                      : 'Tài khoản VIP (${_userStatus!.planName ?? 'Premium'}) • Còn ${_userStatus!.remainingDays} ngày (Cộng dồn khi nạp thêm)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isLifetime ? AppPalette.onAccent : AppPalette.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelectionCards() {
    final visible = _visiblePlans;
    if (visible.isEmpty) return const SizedBox.shrink();

    return Column(
      children: List.generate(visible.length, (index) {
        final plan = visible[index];
        final isSelected = _selectedPlanIndex == index;
        return _buildPlanCardItem(plan, index: index, isSelected: isSelected);
      }),
    );
  }

  Widget _buildPlanCardItem(
    SubscriptionPlan plan, {
    required int index,
    required bool isSelected,
  }) {
    final isYearlyPlan = plan.durationDays >= 360;
    final ownedDuration = _currentOwnedDurationDays;
    final isCurrentlyVip = _userStatus?.isVip ?? false;
    final isCurrentPlan = ownedDuration > 0 && plan.durationDays == ownedDuration;
    const isPlanDisabled = false;

    String subtitle = plan.durationLabel;
    if (isCurrentPlan) {
      subtitle = 'Gói đang dùng · Chạm để cộng dồn thêm ${plan.durationLabel}';
    } else if (isCurrentlyVip) {
      subtitle = 'Cộng dồn thêm ${plan.durationLabel} (+${plan.durationDays} ngày)';
    } else if (plan.durationDays >= 700) {
      subtitle = '2.000 Token AI/ngày · Tiết kiệm 45% (~53k/tháng)';
    } else if (plan.durationDays >= 360) {
      subtitle = '2.000 Token AI/ngày · Tiết kiệm 41% (~58k/tháng)';
    } else {
      subtitle = '2.000 Token AI/ngày · Đầy đủ tính năng Premium';
    }

    String? discountBadge = plan.badgeLabel;
    if (discountBadge == null || discountBadge.isEmpty) {
      if (plan.durationDays >= 700) {
        discountBadge = 'Tiết kiệm 45% · Tối ưu nhất';
      } else if (plan.durationDays >= 360) {
        discountBadge = 'Tiết kiệm 41% · Khuyên dùng';
      }
    }

    return Opacity(
      opacity: isPlanDisabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: () {
          if (isPlanDisabled) {
            AppToast.showSuccess('Bạn đang sở hữu gói cao hơn - Toàn bộ tính năng đã có sẵn!', context: context);
            return;
          }
          setState(() => _selectedPlanIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppPalette.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppPalette.accent
                  : (isYearlyPlan ? AppPalette.accent.withValues(alpha: 0.5) : AppPalette.surface),
              width: isSelected ? 1.8 : (isYearlyPlan ? 1.2 : 1.0),
            ),
          ),
          child: Row(
            children: [
              // Nút chọn dạng radio
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppPalette.accent : AppPalette.textSecondary,
                    width: 1.5,
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
              ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      discountBadge != null && !isPlanDisabled && !isCurrentPlan
                          ? '$subtitle · $discountBadge'
                          : subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrentPlan ? AppPalette.success : AppPalette.textSecondary,
                        fontWeight: isCurrentPlan ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.formattedPrice.replaceAll(' ', ''),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.textPrimary,
                    ),
                  ),
                  if (plan.originalPrice != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      plan.formattedOriginalPrice?.replaceAll(' ', '') ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.lineThrough,
                        color: AppPalette.textSecondary,
                      ),
                    ),
                  ] else if (plan.durationDays > 30) ...[
                    const SizedBox(height: 2),
                    Text(
                      '~${plan.pricePerMonth.replaceAll(' ', '')}/tháng',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppPalette.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (isCurrentPlan) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppPalette.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Đang dùng',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoCodeSection() {
    if (_isUserLifetimeVip) return const SizedBox.shrink();

    final isApplied = _appliedPromoCode != null;
    final plan = _currentSelectedPlan;
    final basePrice = plan?.price ?? 0;
    final payable = _calculatePayablePrice(basePrice);
    final savedAmount = basePrice - payable;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isApplied ? AppPalette.success.withValues(alpha: 0.5) : AppPalette.surface,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.confirmation_number_outlined,
                size: 18,
                color: isApplied ? AppPalette.success : AppPalette.info,
              ),
              const SizedBox(width: 8),
              Text(
                'Mã ưu đãi / Voucher',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.textPrimary,
                ),
              ),
              const Spacer(),
              if (isApplied)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppPalette.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _discountPercent != null && _discountPercent! > 0
                        ? '-$_discountPercent%'
                        : '-${SubscriptionPlan.formatNumber(savedAmount.round())}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (isApplied) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppPalette.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppPalette.success, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _appliedPromoCode!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        if (_promoSuccessMessage != null)
                          Text(
                            _promoSuccessMessage!,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppPalette.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: AppPalette.textSecondary),
                    onPressed: _removePromoCode,
                    tooltip: 'Xóa mã',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppPalette.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppPalette.surfaceHighest),
                    ),
                    child: TextField(
                      controller: _promoController,
                      textCapitalization: TextCapitalization.characters,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppPalette.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập mã (JLSP10, JLSP20, SENSEI...)',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: AppPalette.textSecondary.withValues(alpha: 0.6),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _applyPromoCode(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _isCheckingPromo ? null : _applyPromoCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.accent,
                      foregroundColor: AppPalette.onAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _isCheckingPromo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Áp dụng',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: EdgeInsets.zero,
      child: Text(
        'Thanh toán một lần bằng chuyển khoản VietQR, không tự động gia hạn. Gói được kích hoạt tự động ngay khi hệ thống nhận được tiền; mua thêm trước khi hết hạn sẽ được cộng dồn thời gian.',
        textAlign: TextAlign.left,
        style: TextStyle(fontSize: 11.5, color: AppPalette.textSecondary, height: 1.4),
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    final isLifetimeOwned = _isUserLifetimeVip;
    final isCurrentlyVip = _userStatus?.isVip ?? false;
    final plan = _currentSelectedPlan;
    final basePrice = plan?.price ?? 0;
    final payable = _calculatePayablePrice(basePrice);
    final hasDiscount = _appliedPromoCode != null && payable < basePrice;

    String buttonText;
    if (isLifetimeOwned) {
      buttonText = 'Bạn đã sở hữu Gói Trọn Đời';
    } else if (hasDiscount) {
      if (isCurrentlyVip) {
        buttonText = 'Gia hạn thêm ${plan?.durationLabel ?? ''} (+${plan?.durationDays ?? 0} ngày) • ${SubscriptionPlan.formatNumber(payable.round())}';
      } else {
        buttonText = 'Đăng ký ${plan?.name ?? 'Premium'} • ${SubscriptionPlan.formatNumber(payable.round())}';
      }
    } else if (isCurrentlyVip) {
      buttonText = 'Gia hạn thêm ${plan?.durationLabel ?? ''} (+${plan?.durationDays ?? 0} ngày)';
    } else {
      buttonText = 'Đăng ký ${plan?.name ?? 'Premium'}';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: AppPalette.background,
        border: Border(top: BorderSide(color: AppPalette.surface, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDiscount && !isLifetimeOwned) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ưu đãi voucher ($_appliedPromoCode)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.success,
                    ),
                  ),
                  Text(
                    '-${SubscriptionPlan.formatNumber((basePrice - payable).round())}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLifetimeOwned
                    ? AppPalette.surface
                    : AppPalette.accent,
                foregroundColor: isLifetimeOwned
                    ? AppPalette.textPrimary
                    : AppPalette.onAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: isLifetimeOwned
                  ? () => Navigator.of(context).pop()
                  : _openCheckout,
              child: Text(
                buttonText,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
