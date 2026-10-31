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
  int _selectedPlanIndex = 0;
  String? _appliedPromoCode;
  int _discountPercent = 0;
  double _discountAmount = 0.0;
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

      // Sắp xếp các gói theo thời hạn: 2 Năm -> 1 Năm -> 1 Tháng
      final sortedPlans = List<SubscriptionPlan>.from(plans);
      sortedPlans.sort((a, b) => b.durationDays.compareTo(a.durationDays));

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

  bool get _isUserLifetimeVip => false;

  int get _currentOwnedDurationDays {
    if (_userStatus == null || !_userStatus!.isVip) return 0;
    final name = (_userStatus!.planName ?? '').toLowerCase();
    if (name.contains('2 năm') || _userStatus!.remainingDays > 380) {
      return 730;
    }
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

  SubscriptionPlan _applyDiscountToPlan(SubscriptionPlan basePlan) {
    if (_appliedPromoCode == null || _appliedPromoCode!.isEmpty) {
      return basePlan;
    }
    double discountedPrice = basePlan.price;
    if (_discountPercent > 0) {
      discountedPrice = (basePlan.price * (1.0 - _discountPercent / 100.0)).roundToDouble();
    } else if (_discountAmount > 0) {
      discountedPrice = (basePlan.price - _discountAmount);
      if (discountedPrice < 10000) discountedPrice = 10000;
    }
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
      badgeLabel: _discountPercent > 0 ? '-$_discountPercent%' : (basePlan.badgeLabel ?? '-Ưu đãi'),
      discountPercent: _discountPercent > 0 ? _discountPercent : basePlan.discountPercent,
    );
  }

  List<SubscriptionPlan> get _visiblePlans {
    if (_appliedPromoCode != null && _appliedPromoCode!.isNotEmpty) {
      return _plans.map(_applyDiscountToPlan).toList();
    }
    return _plans;
  }

  SubscriptionPlan? get _currentSelectedPlan {
    final visible = _visiblePlans;
    if (visible.isEmpty) return null;
    return (_selectedPlanIndex >= 0 && _selectedPlanIndex < visible.length)
        ? visible[_selectedPlanIndex]
        : visible.first;
  }

  /// Mở trực tiếp màn hình quét mã VietQR Napas 24/7 (1 chạm)
  Future<void> _openVietQrDirect() async {
    final plan = _currentSelectedPlan;
    if (plan == null) return;
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
                onViewProfile: () {
                  _loadData();
                  if (mounted && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(true);
                  }
                },
                onDismiss: () {
                  _loadData();
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
    final plan = _currentSelectedPlan;
    if (plan == null) return;
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
              onViewProfile: () {
                _loadData();
                if (mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop(true);
                }
              },
              onDismiss: () {
                _loadData();
              },
            ),
          );
        },
      ),
    );
  }

  void _showPromoCodeDialog() {
    final controller = TextEditingController(text: _appliedPromoCode ?? '');
    bool isChecking = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                'Nhập mã ưu đãi của bạn (ví dụ: JLSP10, JLSP20, SENSEI, KOTOBA):',
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
              onPressed: isChecking
                  ? null
                  : () async {
                      final code = controller.text.trim().toUpperCase();
                      if (code.isEmpty) return;

                      setDialogState(() => isChecking = true);
                      try {
                        final promoData = await _service.verifyPromoCode(
                          code,
                          planId: _currentSelectedPlan?.id,
                        );
                        if (!mounted) return;
                        Navigator.of(ctx).pop();

                        final percent = (promoData['discountPercent'] as num?)?.toInt() ?? 0;
                        final amount = (promoData['discountAmount'] as num?)?.toDouble() ?? 0.0;
                        final desc = promoData['description'] as String? ?? 'Áp dụng mã thành công!';

                        setState(() {
                          _appliedPromoCode = code;
                          _discountPercent = percent;
                          _discountAmount = amount;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Đã áp dụng mã $code: $desc'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => isChecking = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString().replaceAll('Exception: ', '')),
                            backgroundColor: const Color(0xFFEF4444),
                          ),
                        );
                      }
                    },
              child: isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Áp dụng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCancelSubscriptionDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1E3A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E3A5F)),
        ),
        title: const Text(
          'Hủy gói thành viên?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: const Text(
          'Bạn có chắc chắn muốn hủy gói thành viên hiện tại? Sau khi hủy, tài khoản sẽ quay về Gói Miễn Phí (50 Token AI/ngày) và dừng các đặc quyền VIP.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Giữ lại gói', style: TextStyle(color: Color(0xFF38BDF8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận hủy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final userId = _resolvedUserId ?? widget.userId;
        await _service.cancelSubscription(userId: userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã hủy gói thành viên thành công. Tài khoản đã quay về Gói Miễn Phí.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khi hủy gói: $e'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    }
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
                                // Title & Brand Glow Badge (Dynamic with selected plan)
                                _buildHeroHeader(),
                                const SizedBox(height: 18),

                                // Current active VIP info if applicable
                                if (_userStatus != null && _userStatus!.isVip && !_userStatus!.isAdmin) ...[
                                  _buildCurrentVipBadge(),
                                  const SizedBox(height: 16),
                                ],

                                // Plan Selection Stack (Vertical List)
                                _buildPlanSelectionCards(),
                                const SizedBox(height: 20),

                                // Feature Checklist (Dynamic with selected plan)
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
    final selected = _currentSelectedPlan;
    final planTitle = selected != null ? selected.name : 'Gói Hội Viên Kotoba';
    final tokenLimit = selected != null && selected.dailyTokenLimit > 0
        ? '${selected.dailyTokenLimit} Token AI/ngày'
        : 'Mở khóa toàn bộ đặc quyền';

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars_rounded, color: Color(0xFFFBBF24), size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      planTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      'Hạn mức: $tokenLimit • Thời hạn: ${selected?.durationLabel ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFBAE6FD),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureChecklist() {
    final selected = _currentSelectedPlan;
    List<String> features = [];

    if (selected != null && selected.features.isNotEmpty) {
      features = List<String>.from(selected.features);
    } else {
      features = [
        'Hạn mức ${selected?.dailyTokenLimit ?? 500} Token AI luyện Shadowing mỗi ngày',
        'Trích xuất lời video không giới hạn phụ đề',
        'Bộ từ vựng Flashcard đầy đủ trình độ N5 - N1',
        'Kho đề luyện thi JLPT chuẩn format mới nhất',
        'Tra từ điển thông minh trực tiếp trên video bài học',
        'Trải nghiệm học tập mượt mà, không quảng cáo',
      ];
    }

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
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF34D399), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đặc quyền gói ${selected?.name ?? 'Kotoba VIP'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
              color: const Color(0xFF38BDF8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentVipBadge() {
    if (_userStatus == null || !_userStatus!.isVip) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2818),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            color: Color(0xFF34D399),
            size: 26,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GÓI ĐANG HOẠT ĐỘNG',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: Color(0xFF34D399),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_userStatus!.planName ?? 'Kotoba VIP'} • Còn ${_userStatus!.remainingDays} ngày (${_userStatus!.effectiveTokenLimit} Token AI/ngày)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _showCancelSubscriptionDialog,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
              ),
              child: const Text(
                'Hủy gói',
                style: TextStyle(
                  color: Color(0xFFF87171),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(visible.length, (index) {
        final plan = visible[index];
        final isSelected = _selectedPlanIndex == index;
        return _buildPlanCardItem(plan, index: index, isSelected: isSelected);
      }),
    );
  }

  Widget _buildPlanCardItem(SubscriptionPlan plan, {required int index, required bool isSelected}) {
    final ownedPlanId = _userStatus?.planId;
    final isAlreadyOwned = _userStatus != null && _userStatus!.isVip && (ownedPlanId == plan.id);

    String subtitle = 'Gói học tiết kiệm';
    if (isAlreadyOwned) {
      subtitle = 'Gói hiện tại (Còn ${_userStatus!.remainingDays} ngày) • Chạm để gia hạn';
    } else if (plan.durationDays >= 700) {
      subtitle = 'Tiết kiệm tối đa • 5.000 Token AI/ngày';
    } else if (plan.durationDays >= 360) {
      subtitle = 'Chỉ ~34.900 đ / tháng • 2.000 Token AI/ngày';
    } else {
      subtitle = 'Linh hoạt 30 ngày • 500 Token AI/ngày';
    }

    String? discountBadge = plan.badgeLabel;
    if (discountBadge == null) {
      if (plan.durationDays >= 700) discountBadge = '-30%';
      if (plan.durationDays >= 360) discountBadge = '-16%';
    }

    return GestureDetector(
      onTap: () {
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
                      ] else if (discountBadge != null) ...[
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
    );
  }

  Widget _buildDisclaimer() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.0),
      child: Text(
        'Thanh toán một lần qua chuyển khoản VietQR Napas 24/7. Không tự động trừ tiền khi hết hạn. Bạn có thể chủ động gia hạn hoặc đổi gói bất kỳ lúc nào.',
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
    final ownedPlanId = _userStatus?.planId;
    final isSelectedOwned = _userStatus != null && _userStatus!.isVip && (ownedPlanId == _currentSelectedPlan?.id);

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
                        _appliedPromoCode != null
                            ? '$_appliedPromoCode (${_discountPercent > 0 ? '-$_discountPercent%' : '-50k'})'
                            : 'Nhập mã ưu đãi',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _appliedPromoCode != null ? const Color(0xFF34D399) : const Color(0xFF93C5FD),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (_appliedPromoCode != null)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _appliedPromoCode = null;
                              _discountPercent = 0;
                              _discountAmount = 0.0;
                            });
                          },
                          child: const Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFF87171)),
                        )
                      else
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Big Action Button: VietQR Direct (1 chạm)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelectedOwned ? const Color(0xFF059669) : const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFF0284C7).withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _openVietQrDirect,
              icon: Icon(isSelectedOwned ? Icons.add_circle_outline_rounded : Icons.qr_code_2_rounded, size: 22),
              label: Text(
                _userStatus != null && _userStatus!.isVip
                    ? (isSelectedOwned
                        ? 'Gia hạn thêm (${_currentSelectedPlan?.durationLabel ?? ''}) — ${_currentSelectedPlan?.formattedPrice ?? ''}'
                        : 'Nâng cấp / Đổi gói — ${_currentSelectedPlan?.formattedPrice ?? ''}')
                    : 'Thanh toán VietQR — ${_currentSelectedPlan?.formattedPrice ?? ''}',
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
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
      ),
    );
  }
}
