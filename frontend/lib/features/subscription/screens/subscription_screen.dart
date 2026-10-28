import 'package:flutter/material.dart';
import '../../auth/data/services/auth_service.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import '../widgets/checkout_bottom_sheet.dart';
import '../widgets/subscription_success_dialog.dart';
import '../widgets/vietqr_payment_sheet.dart';

class SubscriptionScreen extends StatefulWidget {
  final int userId;

  const SubscriptionScreen({
    super.key,
    this.userId = 1,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final SubscriptionService _service = SubscriptionService();
  List<SubscriptionPlan> _plans = [];
  SubscriptionStatus? _userStatus;
  bool _isLoading = true;
  int _selectedPlanIndex = 0; // Default to "Trọn đời" (first / best plan)
  String? _appliedPromoCode;
  int? _resolvedUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
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
        if (a.isLifetime) return -1;
        if (b.isLifetime) return 1;
        return b.durationDays.compareTo(a.durationDays);
      });

      if (mounted) {
        setState(() {
          _plans = sortedPlans;
          _userStatus = status;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _isUserLifetimeVip {
    if (_userStatus == null || !_userStatus!.isVip) return false;
    return _userStatus!.isLifetime;
  }

  int get _currentOwnedDurationDays {
    if (_userStatus == null || !_userStatus!.isVip) return 0;
    if (_isUserLifetimeVip) return 3650;
    final name = (_userStatus!.planName ?? '').toLowerCase();
    if (name.contains('1 năm') ||
        name.contains('12 tháng') ||
        name.contains('mastery') ||
        _userStatus!.remainingDays > 95) {
      return 365;
    }
    if (name.contains('3 tháng') || _userStatus!.remainingDays > 35) {
      return 90;
    }
    if (name.contains('1 tháng') || name.contains('pro') || _userStatus!.remainingDays > 0) {
      return 30;
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
    final basePlan = (_selectedPlanIndex >= 0 && _selectedPlanIndex < visible.length)
        ? visible[_selectedPlanIndex]
        : visible.first;
    if (_appliedPromoCode != null && _appliedPromoCode!.isNotEmpty) {
      final discountedPrice = (basePlan.price * 0.9).roundToDouble();
      return SubscriptionPlan(
        id: basePlan.id,
        name: basePlan.name,
        description: basePlan.description,
        price: discountedPrice,
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

  /// Mở trực tiếp màn hình quét mã VietQR Napas 24/7 (1 chạm)
  Future<void> _openVietQrDirect() async {
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
    if (_currentOwnedDurationDays > 0 && plan.durationDays <= _currentOwnedDurationDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đang sở hữu gói này. Vui lòng chọn gói cao hơn để nâng cấp!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      return;
    }
    final checkoutUserId = _resolvedUserId ?? widget.userId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
      ),
    );

    try {
      final payment = await _service.createQrOrder(
        userId: checkoutUserId,
        planId: plan.id,
        planName: plan.name,
        price: plan.price,
      );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Đóng loading

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (bottomSheetCtx) => VietQrPaymentSheet(
          plan: plan,
          payment: payment,
          userId: checkoutUserId,
          onSuccess: (p) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (dialogCtx) => SubscriptionSuccessDialog(
                payment: p,
                plan: plan,
                onDismiss: () {
                  _loadData();
                  if (mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            );
          },
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _openCheckout();
    }
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
    if (_currentOwnedDurationDays > 0 && plan.durationDays <= _currentOwnedDurationDays) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đang sở hữu gói này. Vui lòng chọn gói cao hơn để nâng cấp!'),
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
                _loadData();
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop(true);
                }
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
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập mã giảm giá (ví dụ: KOTOBA2026 hoặc JLSPVIP) để nhận ưu đãi 10%:',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Nhập mã tại đây...',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF13284F),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1E3A5F)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              Navigator.of(ctx).pop();
              if (code.isNotEmpty) {
                setState(() => _appliedPromoCode = code);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã áp dụng mã $code thành công (-10%)!'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
              }
            },
            child: const Text('Áp dụng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                // 1. Top Bar
                _buildTopBar(),

                // 2. Main Scrollable Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: const Color(0xFF38BDF8),
                          backgroundColor: const Color(0xFF0A192F),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title & Brand Glow Badge
                                _buildHeroHeader(),
                                const SizedBox(height: 18),

                                // Current active VIP info if applicable
                                if (_userStatus != null && _userStatus!.isVip) ...[
                                  _buildCurrentVipBadge(),
                                  const SizedBox(height: 16),
                                ],

                                // Plan Selection Stack (Vertical List)
                                _buildPlanSelectionCards(),
                                const SizedBox(height: 20),

                                // Feature Checklist
                                _buildFeatureChecklist(),
                                const SizedBox(height: 18),

                                // Comparison Table Free vs VIP
                                _buildComparisonTable(),
                                const SizedBox(height: 14),

                                // Terms & Disclaimer
                                _buildDisclaimer(),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                ),

                // 3. Sticky Bottom Bar with VietQR CTA
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'KOTOBA VIP',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF132247),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF223A66)),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Nâng tầm tiếng Nhật',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF0284C7)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 20),
              SizedBox(width: 8),
              Text(
                'Kotoba Premium Pass',
                style: TextStyle(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureChecklist() {
    final features = [
      'Học không giới hạn toàn bộ Bộ từ vựng Flashcard',
      'Luyện Shadowing AI chuẩn ngữ điệu bản xứ Tokyo',
      'Trò chuyện & sửa lỗi ngữ pháp cùng Trợ lý AI',
      'Tra từ điển thông minh trực tiếp trên video phụ đề',
      'Kho đề thi thử JLPT chuẩn format N5 - N1',
      'Huy hiệu Vương miện Vàng danh dự bên cạnh tên',
      'Học offline & không bao giờ bị quảng cáo làm phiền',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1E3A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Color(0xFF34D399), size: 20),
              SizedBox(width: 8),
              Text(
                'Đặc quyền khi sở hữu Kotoba VIP',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F3227),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: Color(0xFF34D399),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE2E8F0),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1E3A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows_rounded, color: Color(0xFF38BDF8), size: 20),
              SizedBox(width: 8),
              Text(
                'So sánh đặc quyền tài khoản',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildComparisonRow('Tính năng', 'Miễn phí', 'Kotoba VIP', isHeader: true),
          const Divider(color: Color(0xFF1E3A5F), height: 16),
          _buildComparisonRow('Flashcard thông minh', '20 từ / ngày', 'Không giới hạn'),
          const Divider(color: Color(0xFF1E3A5F), height: 16),
          _buildComparisonRow('Luyện phát âm AI Shadowing', '5 bài / ngày', 'Không giới hạn'),
          const Divider(color: Color(0xFF1E3A5F), height: 16),
          _buildComparisonRow('Kho đề luyện thi JLPT N5-N1', 'Đề mẫu', 'Toàn bộ kho đề'),
          const Divider(color: Color(0xFF1E3A5F), height: 16),
          _buildComparisonRow('Tra từ điển trên video', '10 lượt / ngày', 'Không giới hạn'),
          const Divider(color: Color(0xFF1E3A5F), height: 16),
          _buildComparisonRow('Huy hiệu Vương miện Vàng', '❌', '👑 Có'),
          const Divider(color: Color(0xFF1E3A5F), height: 16),
          _buildComparisonRow('Trải nghiệm không quảng cáo', '❌', '✅ Có'),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String feature, String freeVal, String vipVal, {bool isHeader = false}) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            feature,
            style: TextStyle(
              fontSize: isHeader ? 12.5 : 12,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
              color: isHeader ? const Color(0xFF94A3B8) : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            freeVal,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isHeader ? 12.5 : 11.5,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            vipVal,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isHeader ? 12.5 : 12,
              fontWeight: FontWeight.bold,
              color: isHeader ? const Color(0xFF38BDF8) : const Color(0xFF38BDF8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentVipBadge() {
    if (_userStatus == null || !_userStatus!.isVip) return const SizedBox.shrink();

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
            isLifetime ? Icons.workspace_premium_rounded : Icons.verified_rounded,
            color: isLifetime ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
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
                    color: isLifetime ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
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

  Widget _buildPlanCardItem(SubscriptionPlan plan, {required int index, required bool isSelected}) {
    final isLifetimePlan = plan.isLifetime;
    final isYearlyPlan = plan.durationDays >= 360 && !isLifetimePlan;
    final userHasLifetime = _isUserLifetimeVip;
    final ownedDuration = _currentOwnedDurationDays;

    final isPlanDisabled = ownedDuration > 0 && plan.durationDays < ownedDuration;
    final isAlreadyOwned = (userHasLifetime && isLifetimePlan) ||
        (ownedDuration > 0 && plan.durationDays == ownedDuration);

    String subtitle = 'Gói học tiết kiệm';
    if (isAlreadyOwned) {
      subtitle = isLifetimePlan
          ? 'Đang sở hữu vĩnh viễn trên tài khoản này'
          : 'Gói hiện tại của bạn đang hoạt động';
    } else if (isPlanDisabled) {
      subtitle = 'Đã bao gồm trong gói hiện tại của bạn';
    } else if (isLifetimePlan) {
      subtitle = 'Lựa chọn số 1 • Thanh toán 1 lần dùng mãi mãi';
    } else if (isYearlyPlan) {
      subtitle = 'Chỉ ~34.900 đ / tháng';
    } else {
      subtitle = 'Linh hoạt theo kỳ học';
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
                content: Text('Bạn đang sở hữu gói cao hơn - Toàn bộ tính năng đã có sẵn!'),
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
                : (isSelected ? const Color(0xFF13284F) : const Color(0xFF0E1E3A)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAlreadyOwned
                  ? const Color(0xFF10B981)
                  : (isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E3356)),
              width: (isAlreadyOwned || isSelected) ? 2.0 : 1.2,
            ),
            boxShadow: (isAlreadyOwned || isSelected)
                ? [
                    BoxShadow(
                      color: (isAlreadyOwned ? const Color(0xFF10B981) : const Color(0xFF0284C7))
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
              // Radio indicator
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                    width: isSelected ? 6 : 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + Discount Pill + Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            plan.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (isAlreadyOwned) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '✓ ĐANG SỞ HỮU',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ] else if (discountBadge != null && !isPlanDisabled) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFF1E3A5F),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              discountBadge,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? Colors.white : const Color(0xFF93C5FD),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isAlreadyOwned
                            ? const Color(0xFF6EE7B7)
                            : (isSelected ? const Color(0xFF93C5FD) : const Color(0xFF94A3B8)),
                      ),
                    ),
                  ],
                ),
              ),

              // Right: Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.formattedPrice,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: isAlreadyOwned
                          ? const Color(0xFF34D399)
                          : (isSelected ? const Color(0xFF38BDF8) : Colors.white),
                    ),
                  ),
                  if (plan.formattedOriginalPrice != null && !isAlreadyOwned)
                    Text(
                      plan.formattedOriginalPrice!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
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
        'Thanh toán bảo mật chuẩn Napas 24/7. Hỗ trợ quét qua ứng dụng ngân hàng cá nhân hoặc ví điện tử. Gói học được kích hoạt tự động ngay sau khi xác nhận chuyển khoản.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          color: Color(0xFF7E8FA6),
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildStickyBottomBar() {
    final isLifetimeOwned = _isUserLifetimeVip;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: const BoxDecoration(
        color: Color(0xFF0A192F),
        border: Border(top: BorderSide(color: Color(0xFF162540))),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLifetimeOwned) ...[
            // Voucher bar
            GestureDetector(
              onTap: _showPromoCodeDialog,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.discount_rounded, size: 16, color: Color(0xFF38BDF8)),
                        SizedBox(width: 6),
                        Text(
                          'Mã giảm giá',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _appliedPromoCode != null ? 'Đã áp dụng: $_appliedPromoCode' : 'Nhập mã ưu đãi',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _appliedPromoCode != null ? const Color(0xFF34D399) : const Color(0xFF93C5FD),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Big Action Button: VietQR Direct (1 chạm)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: isLifetimeOwned
                ? ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F3227),
                      foregroundColor: const Color(0xFF34D399),
                      side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.verified_rounded, color: Color(0xFF34D399), size: 22),
                    label: const Text(
                      'Bạn đã sở hữu Gói Trọn Đời',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                    ),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _openVietQrDirect,
                    icon: const Icon(Icons.qr_code_2_rounded, size: 22),
                    label: Text(
                      _userStatus != null && _userStatus!.isVip
                          ? 'Nâng cấp VietQR — ${_currentSelectedPlan?.formattedPrice ?? ''}'
                          : 'Thanh toán VietQR — ${_currentSelectedPlan?.formattedPrice ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
          ),
          if (!isLifetimeOwned) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _openCheckout,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Chọn phương thức khác (VNPAY / Mô phỏng)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
