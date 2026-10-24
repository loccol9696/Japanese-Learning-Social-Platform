import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../models/subscription_model.dart';
import 'url_helper.dart';
import '../../../core/theme/app_palette.dart';

class VNPayInstructionDialog extends StatelessWidget {
  final PaymentResponse payment;
  final SubscriptionPlan plan;
  final String? paymentUrl;
  final VoidCallback onPaymentFinished;

  const VNPayInstructionDialog({
    super.key,
    required this.payment,
    required this.plan,
    this.paymentUrl,
    required this.onPaymentFinished,
  });

  String get _effectiveUrl =>
      paymentUrl ??
      payment.paymentUrl ??
      'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html?vnp_TmnCode=CGXZLS0Z&vnp_TxnRef=${payment.transactionRef}';

  void _openVnpayGatewayModal(BuildContext context) {
    launchPaymentUrl(_effectiveUrl);
    showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (gatewayCtx) => _VNPaySandboxWebPortalDialog(
        url: _effectiveUrl,
        plan: plan,
        transactionRef: payment.transactionRef,
        onPaidSuccess: () {
          Navigator.of(gatewayCtx).pop(true);
          onPaymentFinished();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _effectiveUrl;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      backgroundColor: AppPalette.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 24.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cổng Thanh Toán VNPay',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppPalette.textPrimary,
                          ),
                        ),
                        Text(
                          'Môi trường Thử nghiệm Sandbox',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, size: 20, color: AppPalette.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Đường link thanh toán VNPay rõ ràng, bấm vào mở cổng hoặc copy
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppPalette.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.link_rounded, size: 16, color: AppPalette.accent),
                            SizedBox(width: 6),
                            Text(
                              'Đường link thanh toán VNPay:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppPalette.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: url));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép đường link thanh toán VNPay!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.copy, size: 13, color: AppPalette.accent),
                              SizedBox(width: 3),
                              Text(
                                'Copy link',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppPalette.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _openVnpayGatewayModal(context),
                      child: Text(
                        url,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.accent,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0x26FFC107),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x66FFC107)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFFFCD34D)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Thông tin thẻ Demo (Thử nghiệm miễn phí)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: Color(0xFFFCD34D),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildCopyableRow(context, 'Ngân hàng:', 'NCB'),
                    const SizedBox(height: 6),
                    _buildCopyableRow(context, 'Số thẻ:', '9704198526191432198'),
                    const SizedBox(height: 6),
                    _buildCopyableRow(context, 'Tên chủ thẻ:', 'NGUYEN VAN A'),
                    const SizedBox(height: 6),
                    _buildCopyableRow(context, 'Ngày phát hành:', '07/15'),
                    const SizedBox(height: 6),
                    _buildCopyableRow(context, 'Mã OTP:', '123456'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _openVnpayGatewayModal(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Mở trang thanh toán VNPay Sandbox'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppPalette.accent,
                  side: const BorderSide(color: AppPalette.accent, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: onPaymentFinished,
                child: const Text(
                  'Tôi đã hoàn tất thanh toán',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCopyableRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppPalette.textSecondary),
        ),
        Row(
          children: [
            SelectableText(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: AppPalette.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã sao chép $value'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: const Icon(Icons.copy, size: 14, color: AppPalette.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _VNPaySandboxWebPortalDialog extends StatefulWidget {
  final String url;
  final SubscriptionPlan plan;
  final String transactionRef;
  final VoidCallback onPaidSuccess;

  const _VNPaySandboxWebPortalDialog({
    required this.url,
    required this.plan,
    required this.transactionRef,
    required this.onPaidSuccess,
  });

  @override
  State<_VNPaySandboxWebPortalDialog> createState() =>
      _VNPaySandboxWebPortalDialogState();
}

class _VNPaySandboxWebPortalDialogState
    extends State<_VNPaySandboxWebPortalDialog> {
  final _cardController = TextEditingController(text: '9704198526191432198');
  final _holderController = TextEditingController(text: 'NGUYEN VAN A');
  final _dateController = TextEditingController(text: '07/15');
  final _otpController = TextEditingController(text: '123456');
  bool _isProcessing = false;

  @override
  void dispose() {
    _cardController.dispose();
    _holderController.dispose();
    _dateController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      widget.onPaidSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        color: Colors.white,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Browser Address Bar showing VNPay URL
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: const Color(0xFFF1F5F9),
                child: Row(
                  children: [
                    const Icon(Icons.lock_rounded, size: 15, color: Color(0xFF10B981)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(false),
                      child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              // VNPay Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF005BAA), Color(0xFF0072CE)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VNPAY PAYMENT GATEWAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Thẻ nội địa và tài khoản ngân hàng (NCB)',
                          style: TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SANDBOX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Đơn hàng: ${widget.plan.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Mã GD: ${widget.transactionRef}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            widget.plan.formattedPrice,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF005BAA),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildInputField('Số thẻ ngân hàng NCB', _cardController),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildInputField('Tên chủ thẻ', _holderController),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _buildInputField('Ngày phát hành', _dateController),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildInputField('Mã xác thực OTP (Demo: 123456)', _otpController),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005BAA),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isProcessing ? null : _submitPayment,
                        child: _isProcessing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Xác nhận thanh toán VNPAY',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ],
    );
  }
}
