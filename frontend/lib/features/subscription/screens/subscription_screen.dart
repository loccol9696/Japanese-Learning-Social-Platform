import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../widgets/subscription_success_dialog.dart';
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
  List<SubscriptionPlan> _plans = [];
  SubscriptionStatus? _userStatus;
  bool _isLoading = true;
  String? _loadError;
  int _selectedPlanIndex = 0; // Default to "Trọn đời" (first / best plan)
  bool _isCreatingOrder = false;

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

  List<SubscriptionPlan> get _visiblePlans {
    final ownedDuration = _currentOwnedDurationDays;
    if (ownedDuration <= 0) return _plans;
    // Ẩn hoàn toàn các gói thấp hơn gói người dùng đang sở hữu
    return _plans.where((plan) => plan.durationDays >= ownedDuration).toList();
  }

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
    if (_currentOwnedDurationDays > 0 && plan.durationDays <= _currentOwnedDurationDays) {
      AppToast.showSuccess('Bạn đang sở hữu gói này. Vui lòng chọn gói cao hơn để nâng cấp!', context: context);
      return;
    }

    // Server tạo đơn (số tiền, mã chuyển khoản, QR); app chỉ hiển thị và chờ server nhận tiền.
    setState(() => _isCreatingOrder = true);
    PaymentOrder order;
    try {
      order = await _service.createOrder(planId: plan.id);
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

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VietQrPaymentSheet(order: order, plan: plan),
    );
    if (!mounted) return;
    if (paid == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => SubscriptionSuccessDialog(
          order: order,
          plan: plan,
          // Hộp thoại tự đóng trước khi gọi hàm này: đóng màn đăng ký gói và về trang cá nhân (trả về true để
          // màn đó tải lại trạng thái).
          onDismiss: () => Navigator.of(context).pop(true),
        ),
      );
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
      'Tạo bộ thẻ không giới hạn',
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
                      : 'Tài khoản VIP (${_userStatus!.planName ?? 'Premium'}) • Còn ${_userStatus!.remainingDays} ngày',
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
    final isLifetimePlan = plan.durationDays >= 3650;
    final isYearlyPlan = plan.durationDays >= 360 && !isLifetimePlan;
    final userHasLifetime = _isUserLifetimeVip;
    final ownedDuration = _currentOwnedDurationDays;

    final isPlanDisabled =
        ownedDuration > 0 && plan.durationDays < ownedDuration;
    final isAlreadyOwned =
        (userHasLifetime && isLifetimePlan) ||
        (ownedDuration > 0 && plan.durationDays == ownedDuration);

    String subtitle = plan.durationLabel;
    if (isAlreadyOwned) {
      subtitle = isLifetimePlan
          ? 'Đang sở hữu vĩnh viễn trên tài khoản này'
          : 'Gói hiện tại của bạn đang hoạt động';
    } else if (isPlanDisabled) {
      subtitle = 'Đã bao gồm trong gói hiện tại của bạn';
    } else if (isLifetimePlan) {
      subtitle = 'Phù hợp nhất dành cho bạn';
    } else if (isYearlyPlan) {
      subtitle = plan.description.isNotEmpty
          ? plan.description
          : plan.durationLabel;
    } else {
      subtitle = plan.description.isNotEmpty
          ? plan.description
          : plan.durationLabel;
    }

    // Chỉ hiện nhãn do server cấu hình; không tự bịa phần trăm giảm giá.
    final String? discountBadge = plan.badgeLabel;

    return Opacity(
      opacity: isPlanDisabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: () {
          if (isAlreadyOwned) {
            AppToast.showSuccess(
              isLifetimePlan
                  ? 'Bạn đang sở hữu Gói Trọn Đời cao cấp nhất!'
                  : 'Bạn đang sử dụng ${plan.name}. Hãy chọn gói cao hơn để nâng cấp!',
              context: context,
            );
            return;
          }
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
              color: isAlreadyOwned
                  ? AppPalette.success
                  : (isSelected ? AppPalette.accent : AppPalette.surface),
              width: 1.5,
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
                    color: isSelected
                        ? AppPalette.accent
                        : AppPalette.textSecondary,
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
                      isAlreadyOwned
                          ? 'Đang sở hữu'
                          : (discountBadge != null && !isPlanDisabled
                                ? '$subtitle · $discountBadge'
                                : subtitle),
                      style: TextStyle(
                        fontSize: 12,
                        color: isAlreadyOwned
                            ? AppPalette.success
                            : AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isAlreadyOwned)
                    Text(
                      'Đã kích hoạt',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.success,
                      ),
                    )
                  else ...[
                    Text(
                      plan.formattedPrice.replaceAll(' ', ''), // đã có chữ đ ở cuối
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
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: AppPalette.background,
        border: Border(top: BorderSide(color: AppPalette.surface, width: 1)),
      ),
      child: SizedBox(
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
            isLifetimeOwned
                ? 'Bạn đã sở hữu Gói Trọn Đời'
                : (_userStatus != null && _userStatus!.isVip
                      ? 'Nâng cấp lên ${_currentSelectedPlan?.name ?? 'gói mới'}'
                      : 'Nâng cấp Premium'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
