import 'package:flutter/material.dart';

import '../../auth/data/services/auth_service.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../widgets/checkout_bottom_sheet.dart';
import '../widgets/subscription_success_dialog.dart';

class SubscriptionScreen extends StatefulWidget {
  final int userId;

  const SubscriptionScreen({super.key, this.userId = 1});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
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
        const SnackBar(
          content: Text('Bạn đang sở hữu Gói Trọn Đời cao cấp nhất!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      return;
    }

    final plan = _currentSelectedPlan;
    if (plan == null) return;
    if (_currentOwnedDurationDays > 0 &&
        plan.durationDays <= _currentOwnedDurationDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn đang sở hữu gói này. Vui lòng chọn gói cao hơn để nâng cấp!',
          ),
          backgroundColor: Color(0xFF10B981),
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
        backgroundColor: const Color(0xFF0E1E3A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E3A5F)),
        ),
        title: const Row(
          children: [
            Icon(Icons.discount_rounded, color: Color(0xFF38BDF8), size: 24),
            SizedBox(width: 8),
            Text(
              'Nhập mã khuyến mãi',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập mã giảm giá từ Kotoba hoặc cộng tác viên để nhận ưu đãi đặc biệt:',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'VD: KOTOBA2026, JLPTN1',
                hintStyle: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: const Color(0xFF132247),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF223A66)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF223A66)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF38BDF8),
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
            child: const Text(
              'Hủy',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
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
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text(
              'Áp dụng',
              style: TextStyle(
                color: Colors.white,
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
      backgroundColor: const Color(0xFF060B17), // Deep backdrop on web
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 440), // Mobile container
          decoration: const BoxDecoration(
            color: Color(0xFF0A192F), // Rich Dark Navy Background
            boxShadow: [
              BoxShadow(
                color: Color(0x40000000),
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
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF38BDF8),
                          ),
                        )
                      : _loadError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFCBD5E1)),
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: const Color(0xFF38BDF8),
                          backgroundColor: const Color(0xFF0A192F),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title & Brand Glow Badge
                                _buildHeroHeader(),
                                const SizedBox(height: 20),

                                // Feature Checklist with Cute Green Icons
                                _buildFeatureChecklist(),
                                const SizedBox(height: 22),

                                // Current active VIP info if applicable
                                if (_userStatus != null &&
                                    _userStatus!.isVip) ...[
                                  _buildCurrentVipBadge(),
                                  const SizedBox(height: 16),
                                ],

                                // Plan Selection Stack (Vertical List)
                                _buildPlanSelectionCards(),
                                const SizedBox(height: 24),

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF132247), // Soft dark navy pill
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF223A66)),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Colors.white, // Clean bright white icon
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nền tảng học tiếng Nhật',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kotoba Premium',
                style: TextStyle(
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: 6),
              Text('✨', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureChecklist() {
    final features = [
      'Trò chuyện & Luyện hội thoại cùng AI',
      'AI kiểm tra ngữ pháp & giải nghĩa từ',
      'Luyện nói & Đánh giá phát âm Shadowing chuẩn AI',
      'Không giới hạn Flashcard & Bộ từ vựng thông minh',
      'Lưu & học từ vựng trực tiếp qua Video',
      'Sử dụng toàn bộ bài học & Flashcard offline',
      'Loại bỏ hoàn toàn quảng cáo làm phiền',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...features.map(
          (feature) => Padding(
            padding: const EdgeInsets.only(bottom: 9.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F3227),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xFF34D399),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE2E8F0),
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
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
        color: isLifetime ? const Color(0xFF1E2818) : const Color(0xFF261E08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLifetime ? const Color(0xFF10B981) : const Color(0xFF785E08),
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
                ? const Color(0xFF34D399)
                : const Color(0xFFFBBF24),
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
                        ? const Color(0xFF34D399)
                        : const Color(0xFFFBBF24),
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
                    color: isLifetime ? Colors.white : const Color(0xFFFDE68A),
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
                backgroundColor: const Color(0xFF10B981),
                duration: const Duration(seconds: 2),
              ),
            );
            return;
          }
          if (isPlanDisabled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Bạn đang sở hữu gói cao hơn - Toàn bộ tính năng đã có sẵn!',
                ),
                backgroundColor: Color(0xFF10B981),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isAlreadyOwned
                ? const Color(0xFF0F2B20)
                : (isSelected
                      ? const Color(0xFF13284F)
                      : const Color(0xFF0E1E3A)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAlreadyOwned
                  ? const Color(0xFF10B981)
                  : (isSelected
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF1E3356)),
              width: (isAlreadyOwned || isSelected) ? 2.0 : 1.2,
            ),
            boxShadow: (isAlreadyOwned || isSelected)
                ? [
                    BoxShadow(
                      color:
                          (isAlreadyOwned
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF1E40AF))
                              .withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Left: Name + Discount Pill + Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (isAlreadyOwned) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              '✓ ĐANG SỞ HỮU',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ] else if (discountBadge != null &&
                            !isPlanDisabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFF4D4F)
                                  : const Color(0xFF1E3A5F),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              discountBadge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF93C5FD),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isAlreadyOwned
                            ? const Color(0xFF6EE7B7)
                            : (isSelected
                                  ? const Color(0xFFBFDBFE)
                                  : const Color(0xFF8899B5)),
                      ),
                    ),
                    if (plan.dailyTokenLimit > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${plan.dailyTokenLimit} token AI mỗi ngày',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Right: Price + Strikethrough original price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (isAlreadyOwned)
                    const Text(
                      'ĐÃ KÍCH HOẠT',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF34D399),
                      ),
                    )
                  else ...[
                    Text(
                      '${plan.formattedPrice.replaceAll(' ', '')}VND',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    if (plan.originalPrice != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${plan.formattedOriginalPrice?.replaceAll(' ', '')}VND',
                        style: TextStyle(
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          color: isSelected
                              ? const Color(0xFF93C5FD).withValues(alpha: 0.7)
                              : const Color(0xFF5A6E8C),
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
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.0),
      child: Text(
        'Đăng ký tự động gia hạn khi tới cuối kỳ, trừ khi bạn huỷ đăng ký trước 24 giờ. Bạn có thể huỷ bất cứ lúc nào trong phần cài đặt tài khoản.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11.5, color: Color(0xFF7E8FA6), height: 1.4),
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    final isLifetimeOwned = _isUserLifetimeVip;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A192F),
        border: Border(top: BorderSide(color: const Color(0xFF162540))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLifetimeOwned) ...[
            // Row: Mã giảm giá > Nhập mã khuyến mãi
            GestureDetector(
              onTap: _showPromoCodeDialog,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mã giảm giá',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _appliedPromoCode != null
                              ? 'Đã áp dụng: $_appliedPromoCode'
                              : 'Nhập mã khuyến mãi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _appliedPromoCode != null
                                ? const Color(0xFF34D399)
                                : const Color(0xFF93C5FD),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Big Action Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: isLifetimeOwned
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3227),
                      foregroundColor: const Color(0xFF34D399),
                      side: const BorderSide(
                        color: Color(0xFF10B981),
                        width: 1.2,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF34D399),
                      size: 22,
                    ),
                    label: const Text(
                      'Bạn đã sở hữu Gói Trọn Đời',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF34D399),
                      ),
                    ),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFF2563EB)
                          .withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _openCheckout,
                    child: Text(
                      _userStatus != null && _userStatus!.isVip
                          ? 'Nâng cấp lên ${_currentSelectedPlan?.name ?? 'gói mới'}'
                          : 'Nâng cấp ngay',
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
