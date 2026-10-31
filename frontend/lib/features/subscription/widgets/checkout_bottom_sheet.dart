import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';
import 'url_helper.dart';
import 'vnpay_instruction_dialog.dart';
import '../../../core/theme/app_palette.dart';

class CheckoutBottomSheet extends StatefulWidget {
  final SubscriptionPlan plan;
  final int userId;
  final Function(PaymentResponse) onSuccess;

  /// Gói mới so với gói đang dùng; quyết định tiêu đề và ghi chú thay đổi.
  final PlanChangeKind kind;

  /// Gói đang dùng (nếu có), để tính hạn dùng mới.
  final SubscriptionStatus? currentStatus;

  const CheckoutBottomSheet({
    super.key,
    required this.plan,
    required this.userId,
    required this.onSuccess,
    this.kind = PlanChangeKind.subscribe,
    this.currentStatus,
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

  String get _title => switch (widget.kind) {
    PlanChangeKind.subscribe => 'Xác nhận đăng ký',
    PlanChangeKind.renew => 'Xác nhận gia hạn',
    PlanChangeKind.upgrade => 'Xác nhận nâng cấp gói',
    PlanChangeKind.change => 'Xác nhận đổi gói',
  };

  /// Ghi chú về hiệu lực của đơn: BE áp dụng gói mới ngay và cộng dồn thời hạn.
  Widget? _buildChangeNotice() {
    final status = widget.currentStatus;
    if (widget.kind == PlanChangeKind.subscribe || status == null) return null;

    final expiry = widget.plan.isLifetime
        ? 'Trọn đời'
        : SubscriptionStatus.formatDate(status.expiryAfterBuying(widget.plan));
    final remaining = status.isLifetime
        ? 'thời hạn trọn đời'
        : '${status.remainingDays} ngày còn lại';
    final isWarning = widget.kind == PlanChangeKind.change;
    final color = isWarning ? AppPalette.warning : AppPalette.info;
    final message = switch (widget.kind) {
      PlanChangeKind.renew =>
        'Thời hạn của gói được cộng thêm ${widget.plan.durationLabel.toLowerCase()}.',
      PlanChangeKind.upgrade =>
        'Gói mới có hiệu lực ngay. Phần $remaining của gói hiện tại được cộng dồn vào gói mới.',
      _ =>
        'Gói mới thay thế gói hiện tại ngay lập tức, quyền lợi theo gói mới. Phần $remaining được cộng dồn, không hoàn tiền chênh lệch.',
    };

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isWarning
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppPalette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hạn dùng mới: $expiry',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final changeNotice = _buildChangeNotice();
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppPalette.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Thời hạn: ${widget.plan.durationLabel}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppPalette.textSecondary,
                          ),
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
            ?changeNotice,
            const SizedBox(height: 20),
            Text(
              'Phương thức thanh toán',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildPaymentMethodOption(
              value: 'MOCK',
              title: 'Mô phỏng tức thì (Mock Payment)',
              subtitle: 'Thử nghiệm môi trường DEV/Demo - Kích hoạt ngay',
              icon: Icons.flash_on_rounded,
              iconColor: AppPalette.warning,
              enabled: true,
            ),
            _buildPaymentMethodOption(
              value: 'VNPAY',
              title: 'Cổng thanh toán VNPAY (Sandbox)',
              subtitle: 'Tạm khóa: máy chủ chưa cấu hình VNPay',
              icon: Icons.account_balance_rounded,
              iconColor: AppColors.primary,
              enabled: false,
            ),
            if (_selectedMethod == 'VNPAY')
              Container(
                margin: const EdgeInsets.only(top: 4, bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppPalette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 16,
                          color: AppPalette.accent,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Đường link thanh toán VNPAY Sandbox:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textPrimary,
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
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppPalette.accent,
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
              iconColor: AppPalette.like,
              enabled: false,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tổng thanh toán:',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppPalette.textSecondary,
                  ),
                ),
                Text(
                  widget.plan.formattedPrice,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.accent,
                  foregroundColor: AppPalette.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _handlePayment,
                child: _isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppPalette.textPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Xác nhận & Thanh toán ngay',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
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
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppPalette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 1.6,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          enabled: enabled,
          dense: true,
          onTap: enabled ? () => setState(() => _selectedMethod = value) : null,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: enabled
                  ? iconColor.withValues(alpha: 0.1)
                  : AppPalette.border,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: enabled ? iconColor : AppPalette.textSecondary,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: enabled
                  ? AppPalette.textPrimary
                  : AppPalette.textSecondary,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 11.5,
              color: enabled
                  ? AppPalette.textSecondary
                  : AppPalette.textSecondary,
            ),
          ),
          trailing: Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: isSelected ? AppColors.primary : AppPalette.border,
            size: 20,
          ),
        ),
      ),
    );
  }
}
