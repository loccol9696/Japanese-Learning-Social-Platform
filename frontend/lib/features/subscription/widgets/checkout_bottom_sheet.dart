import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import 'url_helper.dart';
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
  String _selectedMethod = 'MOCK';
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
      final payment = await _service.checkout(
        userId: widget.userId,
        planId: widget.plan.id,
        paymentMethod: _selectedMethod,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

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
        top: 24,
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
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Xác nhận thông tin đơn hàng',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D1B3E),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1B3E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thời hạn: ${widget.plan.durationLabel}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.plan.formattedPrice,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Phương thức thanh toán',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D1B3E),
            ),
          ),
          const SizedBox(height: 10),
          _buildPaymentMethodOption(
            value: 'MOCK',
            title: 'Mô phỏng tức thì (Mock Payment)',
            subtitle: 'Thử nghiệm môi trường DEV/Demo - Kích hoạt ngay',
            icon: Icons.flash_on_rounded,
            iconColor: Colors.amber.shade800,
            enabled: true,
          ),
          _buildPaymentMethodOption(
            value: 'VNPAY',
            title: 'Cổng thanh toán VNPAY (Sandbox)',
            subtitle: 'Thẻ ATM nội địa NCB, QR Pay (Thử nghiệm miễn phí)',
            icon: Icons.account_balance_rounded,
            iconColor: AppColors.primary,
            enabled: true,
          ),
          if (_selectedMethod == 'VNPAY')
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.link_rounded, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 6),
                      Text(
                        'Đường link thanh toán VNPAY Sandbox:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _handlePayment,
                    child: Text(
                      _previewVnpayUrl,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF2563EB),
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildPaymentMethodOption(
            value: 'MOMO',
            title: 'Ví điện tử MoMo',
            subtitle: 'Quét mã MoMo nhanh chóng (Sắp ra mắt)',
            icon: Icons.wallet_rounded,
            iconColor: Colors.pink.shade600,
            enabled: false,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tổng thanh toán:',
                  style: TextStyle(fontSize: 15, color: Colors.black54)),
              Text(widget.plan.formattedPrice,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  )),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D1B3E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _handlePayment,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Xác nhận & Thanh toán ngay',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
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
  }) {
    final isSelected = _selectedMethod == value;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : (enabled ? Colors.grey.shade300 : Colors.grey.shade200),
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: ListTile(
        enabled: enabled,
        dense: true,
        onTap: enabled
            ? () => setState(() => _selectedMethod = value)
            : null,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled ? iconColor.withValues(alpha: 0.1) : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: enabled ? iconColor : Colors.grey.shade400, size: 20),
        ),
        title: Text(title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: enabled ? const Color(0xFF0D1B3E) : Colors.grey.shade500,
            )),
        subtitle: Text(subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
            )),
        trailing: Icon(
          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: isSelected ? AppColors.primary : Colors.grey.shade300,
          size: 20,
        ),
      ),
    );
  }
}
