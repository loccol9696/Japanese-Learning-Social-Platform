import 'package:flutter/material.dart';

import '../../auth/data/services/auth_service.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../widgets/checkout_bottom_sheet.dart';
import '../widgets/subscription_success_dialog.dart';
import '../../../core/theme/app_palette.dart';

class SubscriptionScreen extends StatefulWidget {
  final int userId;

  const SubscriptionScreen({super.key, this.userId = 1});

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
      final currentUser = await AuthService.instance.getCurrentUser();
      if (currentUser?.id != null) {
        activeUserId = currentUser!.id!;
      }
      _resolvedUserId = activeUserId;

      final results = await Future.wait([
        _service.getPlans(),
        _service.getMyStatus(userId: activeUserId),
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

  bool get _isUserLifetimeVip {
    if (_userStatus == null || !_userStatus!.isVip) return false;
    final name = (_userStatus!.planName ?? '').toLowerCase();
    return _userStatus!.remainingDays >= 3650 ||
        _userStatus!.planId == 2 ||
        name.contains('trọn đời') ||
        name.contains('lifetime');
  }

  int get _currentOwnedDurationDays {
    if (_userStatus == null || !_userStatus!.isVip) return 0;
    if (_isUserLifetimeVip) return 36500;
    final name = (_userStatus!.planName ?? '').toLowerCase();
    if (_userStatus!.planId == 3 ||
        name.contains('1 năm') ||
        name.contains('12 tháng') ||
        _userStatus!.remainingDays > 95) {
      return 365;
    }
    if (_userStatus!.planId == 1 ||
        name.contains('3 tháng') ||
        _userStatus!.remainingDays > 0) {
      return 90;
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
    if (_appliedPromoCode != null && _appliedPromoCode!.isNotEmpty) {
      final discountedPrice = (basePlan.price * 0.9).roundToDouble();
      return SubscriptionPlan(
        id: basePlan.id,
        name: basePlan.name,
        code: basePlan.code,
        description: basePlan.description,
        price: discountedPrice,
        dailyTokenLimit: basePlan.dailyTokenLimit,
        originalPrice: basePlan.originalPrice ?? basePlan.price,
        durationDays: basePlan.durationDays,
        features: basePlan.features,
        isActive: basePlan.isActive,
        displayOrder: basePlan.displayOrder,
        badgeLabel: basePlan.badgeLabel,
        discountPercent: basePlan.discountPercent,
      );
    }
    return basePlan;
  }

  void _openCheckout() {
    if (_isUserLifetimeVip) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bạn đang sở hữu Gói Trọn Đời cao cấp nhất!'),
          backgroundColor: AppPalette.success,
        ),
      );
      return;
    }

    final plan = _currentSelectedPlan;
    if (plan == null) return;
    if (_currentOwnedDurationDays > 0 &&
        plan.durationDays <= _currentOwnedDurationDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bạn đang sở hữu gói này. Vui lòng chọn gói cao hơn để nâng cấp!',
          ),
          backgroundColor: AppPalette.success,
        ),
      );
      return;
    }
    final checkoutUserId = _resolvedUserId ?? widget.userId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) => CheckoutBottomSheet(
        plan: plan,
        userId: checkoutUserId,
        onSuccess: (payment) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => SubscriptionSuccessDialog(
              payment: payment,
              plan: plan,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppPalette.surface),
        ),
        title: Row(
          children: [
            Icon(Icons.discount_rounded, color: AppPalette.info, size: 24),
            SizedBox(width: 8),
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
                  borderSide: BorderSide(color: AppPalette.surface),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppPalette.surface),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppPalette.info,
                    width: 1.5,
                  ),
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
                color: AppPalette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
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
                                if (!_isUserLifetimeVip) _buildPromoLink(),
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

    String? discountBadge = plan.badgeLabel;
    if (discountBadge == null) {
      if (isLifetimePlan) discountBadge = '-30%';
      if (isYearlyPlan) discountBadge = '-16%';
    }

    return Opacity(
      opacity: isPlanDisabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: () {
          if (isAlreadyOwned) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isLifetimePlan
                      ? 'Bạn đang sở hữu Gói Trọn Đời cao cấp nhất!'
                      : 'Bạn đang sử dụng ${plan.name}. Hãy chọn gói cao hơn để nâng cấp!',
                ),
                backgroundColor: AppPalette.success,
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
          if (isPlanDisabled) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Bạn đang sở hữu gói cao hơn - Toàn bộ tính năng đã có sẵn!',
                ),
                backgroundColor: AppPalette.success,
                duration: Duration(seconds: 2),
              ),
            );
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
                      '${plan.formattedPrice.replaceAll(' ', '')}đ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                    if (plan.originalPrice != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${plan.formattedOriginalPrice?.replaceAll(' ', '')}đ',
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

  Widget _buildPromoLink() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: _showPromoCodeDialog,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: Text(
          _appliedPromoCode != null
              ? 'Đã áp dụng mã: $_appliedPromoCode'
              : 'Nhập mã khuyến mãi',
          style: TextStyle(
            fontSize: 13,
            color: _appliedPromoCode != null
                ? AppPalette.success
                : _linkBlue,
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Padding(
      padding: EdgeInsets.zero,
      child: Text(
        'Đăng ký tự động gia hạn khi tới cuối kỳ, trừ khi bạn huỷ đăng ký trước 24 giờ. Bạn có thể huỷ bất cứ lúc nào trong phần cài đặt tài khoản.',
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
