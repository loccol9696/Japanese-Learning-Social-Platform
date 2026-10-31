import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';

class AdminMembershipManageScreen extends StatefulWidget {
  const AdminMembershipManageScreen({super.key});

  @override
  State<AdminMembershipManageScreen> createState() => _AdminMembershipManageScreenState();
}

class _AdminMembershipManageScreenState extends State<AdminMembershipManageScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SubscriptionService _service = SubscriptionService.instance;

  // Plans State
  List<SubscriptionPlan> _plans = [];
  bool _isLoadingPlans = true;

  // Vouchers State
  List<PromoCodeItem> _vouchers = [];
  bool _isLoadingVouchers = true;
  String _voucherSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadPlans(),
      _loadVouchers(),
    ]);
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoadingPlans = true);
    try {
      final plans = await _service.getAllPlansAdmin();
      if (mounted) {
        setState(() {
          _plans = plans;
          _isLoadingPlans = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPlans = false);
    }
  }

  Future<void> _loadVouchers() async {
    setState(() => _isLoadingVouchers = true);
    try {
      final list = await _service.getPromoCodesAdmin();
      if (mounted) {
        setState(() {
          _vouchers = list;
          _isLoadingVouchers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingVouchers = false);
    }
  }

  // ==================== VOUCHER ACTIONS ====================

  void _showCreateVoucherSheet() {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '10');
    final maxUsesCtrl = TextEditingController(text: '100');
    bool isPercent = true;
    int durationDays = 365;
    bool isActive = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0E1E3A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: Color(0xFF1E3A5F))),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        Icon(Icons.discount_rounded, color: Color(0xFF38BDF8), size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Tạo Mã Ưu Đãi (Voucher) Mới',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Mã code
                    const Text('Mã Voucher (Viết liền, in hoa):', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: 'VD: JLSP30, TET2026, VIP50',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF0A192F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Mô tả
                    const Text('Mô tả ưu đãi:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'VD: Ưu đãi 30% cho học viên mới',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF0A192F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Loại giảm giá (Segment)
                    const Text('Hình thức giảm:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setSheetState(() {
                                isPercent = true;
                                if (double.tryParse(valueCtrl.text) == null || double.parse(valueCtrl.text) > 100) {
                                  valueCtrl.text = '20';
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isPercent ? const Color(0xFF0284C7) : const Color(0xFF0A192F),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isPercent ? const Color(0xFF38BDF8) : const Color(0xFF1E3A5F)),
                              ),
                              child: const Center(
                                child: Text('Theo % (Phần trăm)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setSheetState(() {
                                isPercent = false;
                                if (double.tryParse(valueCtrl.text) == null || double.parse(valueCtrl.text) <= 100) {
                                  valueCtrl.text = '50000';
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isPercent ? const Color(0xFF0284C7) : const Color(0xFF0A192F),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: !isPercent ? const Color(0xFF38BDF8) : const Color(0xFF1E3A5F)),
                              ),
                              child: const Center(
                                child: Text('Cố định (VNĐ)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Giá trị giảm & Giới hạn lượt dùng (2 cột)
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isPercent ? 'Mức giảm (%)' : 'Số tiền (VNĐ)', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: valueCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0A192F),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Số lượt tối đa:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: maxUsesCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0A192F),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Thời hạn
                    const Text('Thời hạn hiệu lực:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: durationDays,
                      dropdownColor: const Color(0xFF0A192F),
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF0A192F),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 30, child: Text('1 Tháng (30 ngày)')),
                        DropdownMenuItem(value: 90, child: Text('3 Tháng (90 ngày)')),
                        DropdownMenuItem(value: 180, child: Text('6 Tháng (180 ngày)')),
                        DropdownMenuItem(value: 365, child: Text('1 Năm (365 ngày)')),
                        DropdownMenuItem(value: 730, child: Text('2 Năm (730 ngày)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setSheetState(() => durationDays = val);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Nút Lưu
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final code = codeCtrl.text.trim().toUpperCase();
                          if (code.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Vui lòng nhập mã voucher!'), backgroundColor: Color(0xFFEF4444)),
                            );
                            return;
                          }

                          final val = double.tryParse(valueCtrl.text) ?? 0;
                          final maxUses = int.tryParse(maxUsesCtrl.text) ?? 100;

                          Navigator.of(ctx).pop();
                          final created = await _service.createPromoCodeAdmin(
                            code: code,
                            description: descCtrl.text.trim(),
                            discountPercent: isPercent ? val.toInt() : 0,
                            discountAmount: !isPercent ? val : 0,
                            maxUses: maxUses,
                            durationDays: durationDays,
                            isActive: isActive,
                          );

                          if (created != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Đã tạo thành công mã voucher $code!'), backgroundColor: const Color(0xFF10B981)),
                            );
                            _loadVouchers();
                          }
                        },
                        child: const Text('Tạo Voucher Ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleVoucher(PromoCodeItem v) async {
    final updated = await _service.togglePromoCodeAdmin(v.id);
    if (updated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${updated.isActive ? 'Đã kích hoạt' : 'Đã tạm khóa'} mã ${updated.code}'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      _loadVouchers();
    }
  }

  Future<void> _deleteVoucher(PromoCodeItem v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1E3A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa mã khuyến mãi?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa vĩnh viễn voucher "${v.code}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Hủy', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xác nhận xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await _service.deletePromoCodeAdmin(v.id);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa mã voucher ${v.code} thành công!'), backgroundColor: const Color(0xFF10B981)),
        );
        _loadVouchers();
      }
    }
  }

  // ==================== PLAN ACTIONS ====================

  void _showEditPlanSheet(SubscriptionPlan plan) {
    final nameCtrl = TextEditingController(text: plan.name);
    final priceCtrl = TextEditingController(text: plan.price.round().toString());
    final tokenLimitCtrl = TextEditingController(text: plan.dailyTokenLimit.toString());
    final durationCtrl = TextEditingController(text: plan.durationDays.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0E1E3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF1E3A5F))),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Color(0xFFFBBF24), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Cấu hình: ${plan.name}',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              const Text('Tên gói hiển thị:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0A192F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Giá gói (VNĐ):', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0A192F),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Token AI / ngày:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: tokenLimitCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF0A192F),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const Text('Thời hạn sử dụng (ngày):', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: durationCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF0A192F),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final price = double.tryParse(priceCtrl.text) ?? plan.price;
                    final tokens = int.tryParse(tokenLimitCtrl.text) ?? plan.dailyTokenLimit;
                    final days = int.tryParse(durationCtrl.text) ?? plan.durationDays;

                    Navigator.of(ctx).pop();
                    final success = await _service.updatePlanAdmin(
                      planId: plan.id,
                      name: nameCtrl.text.trim(),
                      price: price,
                      durationDays: days,
                      dailyTokenLimit: tokens,
                      description: plan.description,
                      features: plan.features.join('\n'),
                      isActive: plan.isActive,
                    );

                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã cập nhật biểu phí gói ${plan.name}!'), backgroundColor: const Color(0xFF10B981)),
                      );
                      _loadPlans();
                    }
                  },
                  child: const Text('Lưu Thay Đổi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== BUILD UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A192F),
        elevation: 0,
        title: const Text(
          'Quản Lý Gói & Voucher',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8)),
            tooltip: 'Tải lại',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          indicatorWeight: 3,
          labelColor: const Color(0xFF38BDF8),
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(icon: Icon(Icons.workspace_premium_rounded, size: 20), text: 'Gói Thành Viên'),
            Tab(icon: Icon(Icons.discount_rounded, size: 20), text: 'Mã Ưu Đãi (Voucher)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPlansTab(),
          _buildVouchersTab(),
        ],
      ),
    );
  }

  Widget _buildPlansTab() {
    if (_isLoadingPlans) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Helper notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0E1E3A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E3A5F)),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Quản trị viên có thể xem biểu phí, sửa giá VND và điều chỉnh hạn mức Token AI cấp phát mỗi ngày cho từng gói.',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        ..._plans.map((p) {
          final isFree = p.price == 0 || p.code == 'FREE';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1E3A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.code == 'PRO_MONTHLY' ? const Color(0xFF38BDF8) : const Color(0xFF1E3A5F)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isFree ? Colors.blue.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isFree ? 'MẶC ĐỊNH' : '${p.durationDays} NGÀY',
                        style: TextStyle(
                          color: isFree ? const Color(0xFF38BDF8) : const Color(0xFF34D399),
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Price & Token limit row
                Row(
                  children: [
                    Text(
                      isFree ? '0 đ (Miễn phí)' : p.formattedPrice,
                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 17),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 4),
                          Text(
                            '${p.dailyTokenLimit} Token AI/ngày',
                            style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Button edit
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF1E3A5F)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _showEditPlanSheet(p),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Chỉnh sửa biểu phí & Token', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildVouchersTab() {
    if (_isLoadingVouchers) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
    }

    final filtered = _vouchers.where((v) {
      final q = _voucherSearch.trim().toLowerCase();
      if (q.isEmpty) return true;
      return v.code.toLowerCase().contains(q) || (v.description != null && v.description!.toLowerCase().contains(q));
    }).toList();

    return Column(
      children: [
        // Action bar: Tạo voucher & Search
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          color: const Color(0xFF0A192F),
          child: Column(
            children: [
              // Nút Tạo mới
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  onPressed: _showCreateVoucherSheet,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: const Text('Tạo Mã Ưu Đãi (Voucher) Mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 10),

              // Search box
              TextField(
                onChanged: (val) => setState(() => _voucherSearch = val),
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Tìm theo mã voucher...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                  filled: true,
                  fillColor: const Color(0xFF0E1E3A),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1E3A5F))),
                ),
              ),
            ],
          ),
        ),

        // List vouchers
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text('Chưa có mã ưu đãi nào.', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final v = filtered[idx];
                    final percentUsed = v.maxUses > 0 ? (v.usedCount / v.maxUses).clamp(0.0, 1.0) : 0.0;
                    final isActive = v.isActive && !v.isExpired && !v.isExhausted;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1E3A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isActive ? const Color(0xFF1E3A5F) : Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  v.code,
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  v.discountLabel,
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Status pill
                              Text(
                                v.isExhausted
                                    ? 'Hết lượt'
                                    : (v.isExpired
                                        ? 'Hết hạn'
                                        : (v.isActive ? 'Đang mở' : 'Đã khóa')),
                                style: TextStyle(
                                  color: v.isExhausted || v.isExpired
                                      ? Colors.red
                                      : (v.isActive ? const Color(0xFF34D399) : Colors.grey),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          if (v.description != null && v.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              v.description!,
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
                            ),
                          ],
                          const SizedBox(height: 10),

                          // Usage progress bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lượt dùng: ${v.usedCount} / ${v.maxUses}',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                              ),
                              Text(
                                '${(percentUsed * 100).toInt()}%',
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percentUsed,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              percentUsed >= 1.0
                                  ? Colors.red
                                  : (percentUsed >= 0.8 ? Colors.amber : const Color(0xFF38BDF8)),
                            ),
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          const SizedBox(height: 10),

                          // Action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: v.isActive ? const Color(0xFFF87171) : const Color(0xFF34D399),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                                onPressed: () => _toggleVoucher(v),
                                icon: Icon(v.isActive ? Icons.lock_outline_rounded : Icons.lock_open_rounded, size: 16),
                                label: Text(v.isActive ? 'Khóa mã' : 'Mở khóa', style: const TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171), size: 18),
                                tooltip: 'Xóa voucher',
                                onPressed: () => _deleteVoucher(v),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
