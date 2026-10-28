import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import 'url_helper.dart';
import 'vietqr_payment_sheet.dart';
import 'vnpay_instruction_dialog.dart';

class CheckoutBottomSheet extends StatefulWidget {
  final SubscriptionPlan plan;
  final int userId;
  final Function(PaymentResponse) onSuccess;

  const CheckoutBottomSheet({
    super.key,
    required this.plan,
    required this.userId,
    required this.onSuccess,
  });

  @override
  State<CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<CheckoutBottomSheet> {
  final SubscriptionService _service = SubscriptionService();
  String _selectedMethod = 'VIETQR';
  bool _isLoading = false;
  String? _errorMessage;

  String get _previewVnpayUrl {
    final amount = widget.plan.price.round() * 100;
    return 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html'
        '?vnp_Version=2.1.0&vnp_Command=pay&vnp_TmnCode=CGXZLS0Z'
        '&vnp_Amount=$amount&vnp_CurrCode=VND&vnp_OrderInfo=Kotoba_VIP_${widget.plan.id}';
  }

  Future<void> _handlePayment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_selectedMethod == 'VIETQR') {
        final payment = await _service.createQrOrder(
          userId: widget.userId,
          planId: widget.plan.id,
          planName: widget.plan.name,
          price: widget.plan.price,
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        // Đóng BottomSheet chọn phương thức và mở Màn hình quét mã VietQR Napas
        Navigator.of(context).pop();

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => VietQrPaymentSheet(
            plan: widget.plan,
            payment: payment,
            userId: widget.userId,
            onSuccess: widget.onSuccess,
          ),
        );
        return;
      }

      final payment = await _service.checkout(
        userId: widget.userId,
        planId: widget.plan.id,
        paymentMethod: _selectedMethod,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (_selectedMethod == 'VNPAY') {
        final vnpayUrl = payment.paymentUrl ?? _previewVnpayUrl;
        launchPaymentUrl(vnpayUrl);

        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => VNPayInstructionDialog(
            payment: payment,
            plan: widget.plan,
            paymentUrl: vnpayUrl,
            onPaymentFinished: () {
              Navigator.of(ctx).pop(true);
            },
          ),
        );

        if (confirmed == true) {
          await _service.confirmVnpayPayment(
            userId: widget.userId,
            planId: widget.plan.id,
            planName: widget.plan.name,
            durationDays: widget.plan.durationDays,
          );
          if (mounted) {
            Navigator.of(context).pop();
            widget.onSuccess(payment);
          }
        }
      } else {
        Navigator.of(context).pop();
        widget.onSuccess(payment);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Thanh toán thất bại: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chọn phương thức thanh toán',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),

          // Plan Summary Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFF16A34A),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Thời hạn: ${widget.plan.durationLabel}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.plan.formattedPrice,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text(
            'Phương thức khả dụng',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),

          // Option 1: VietQR
          _buildPaymentMethodOption(
            value: 'VIETQR',
            title: 'Chuyển khoản Ngân hàng (VietQR Napas 24/7)',
            subtitle: 'Quét mã qua Timo, VCB, MB, Techcombank, MoMo...',
            icon: Icons.qr_code_2_rounded,
            iconColor: const Color(0xFF0284C7),
            enabled: true,
            badge: 'Khuyên dùng',
          ),

          // Option 2: VNPay Sandbox
          _buildPaymentMethodOption(
            value: 'VNPAY',
            title: 'Cổng thanh toán VNPAY (Sandbox)',
            subtitle: 'Thẻ ATM nội địa NCB, QR Pay giả lập',
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFF2563EB),
            enabled: true,
          ),

          // Option 3: Mock Test
          _buildPaymentMethodOption(
            value: 'MOCK',
            title: 'Mô phỏng tức thì (Test nhanh)',
            subtitle: 'Kích hoạt ngay không cần chuyển khoản',
            icon: Icons.flash_on_rounded,
            iconColor: const Color(0xFFD97706),
            enabled: true,
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(_errorMessage!, style: TextStyle(color: AppColors.error, fontSize: 12.5)),
          ],

          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng thanh toán:',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              Text(
                widget.plan.formattedPrice,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _handlePayment,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _selectedMethod == 'VIETQR'
                              ? 'Lấy mã VietQR chuyển khoản'
                              : 'Xác nhận & Thanh toán',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool enabled,
    String? badge,
  }) {
    final isSelected = _selectedMethod == value;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFF0F9FF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF0284C7)
              : (enabled ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9)),
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: ListTile(
        enabled: enabled,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        onTap: enabled ? () => setState(() => _selectedMethod = value) : null,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled ? iconColor.withValues(alpha: 0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: enabled ? iconColor : Colors.grey.shade400, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: enabled ? const Color(0xFF0F172A) : Colors.grey.shade500,
                ),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 11.5,
            color: enabled ? const Color(0xFF64748B) : Colors.grey.shade400,
          ),
        ),
        trailing: Icon(
          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: isSelected ? const Color(0xFF0284C7) : Colors.grey.shade300,
          size: 20,
        ),
      ),
    );
  }
}
