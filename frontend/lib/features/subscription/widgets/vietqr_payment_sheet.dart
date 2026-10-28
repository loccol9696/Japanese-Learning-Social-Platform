import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';

class VietQrPaymentSheet extends StatefulWidget {
  final SubscriptionPlan plan;
  final PaymentResponse payment;
  final int userId;
  final Function(PaymentResponse) onSuccess;

  const VietQrPaymentSheet({
    super.key,
    required this.plan,
    required this.payment,
    required this.userId,
    required this.onSuccess,
  });

  @override
  State<VietQrPaymentSheet> createState() => _VietQrPaymentSheetState();
}

class _VietQrPaymentSheetState extends State<VietQrPaymentSheet> {
  final SubscriptionService _service = SubscriptionService();
  bool _isConfirming = false;
  int _secondsLeft = 15 * 60; // 15 phút đếm ngược
  Timer? _countdownTimer;
  Timer? _pollingTimer;

  bool _isAutoConfirmed = false;
  bool _isPollingRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _startPolling();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 0) {
        timer.cancel();
      } else {
        setState(() {
          _secondsLeft--;
        });
      }
    });
  }

  void _startPolling() {
    final orderCode = widget.payment.orderCode ?? widget.payment.transactionRef;
    if (orderCode.isEmpty) return;

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _isConfirming || _isAutoConfirmed || _isPollingRequestInFlight) return;

      _isPollingRequestInFlight = true;
      try {
        final status = await _service.getOrderStatus(orderCode);
        if (!mounted || _isAutoConfirmed) return;
        if (status == 'SUCCESS') {
          _isAutoConfirmed = true;
          timer.cancel();
          await _service.confirmPayment(
            userId: widget.userId,
            planId: widget.plan.id,
            orderCode: orderCode,
            verificationCode: widget.payment.verificationCode,
            planName: widget.plan.name,
            durationDays: widget.plan.durationDays,
          );
          if (mounted) {
            _handleSuccess();
          }
        }
      } finally {
        _isPollingRequestInFlight = false;
      }
    });
  }

  String get _formattedTime {
    final minutes = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép $label: $text'),
        backgroundColor: const Color(0xFF0284C7),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleConfirmPayment() async {
    if (!mounted) return;
    setState(() => _isConfirming = true);

    final orderCode = widget.payment.orderCode ?? widget.payment.transactionRef;

    try {
      // Kiểm tra thực tế trạng thái đơn hàng từ ngân hàng/hệ thống
      final status = await _service.getOrderStatus(orderCode);

      if (!mounted) return;
      setState(() => _isConfirming = false);

      if (status == 'SUCCESS') {
        _isAutoConfirmed = true;
        _pollingTimer?.cancel();
        await _service.confirmPayment(
          userId: widget.userId,
          planId: widget.plan.id,
          orderCode: orderCode,
          verificationCode: widget.payment.verificationCode,
          planName: widget.plan.name,
          durationDays: widget.plan.durationDays,
        );
        if (mounted) {
          _handleSuccess();
        }
      } else {
        // Chưa nhận được tiền từ ngân hàng
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Thanh toán chưa thành công! Ngân hàng chưa ghi nhận biến động số dư cho đơn #$orderCode. Vui lòng chuyển khoản đúng nội dung và thử lại sau ít giây.',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isConfirming = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kiểm tra thanh toán: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleSuccess() {
    Navigator.of(context).pop();
    widget.onSuccess(widget.payment);
  }

  @override
  Widget build(BuildContext context) {
    final orderCode = widget.payment.orderCode ?? widget.payment.transactionRef;
    final bankName = widget.payment.bankName ?? 'ACB - Ngân hàng TMCP Á Châu';
    final accountNo = widget.payment.accountNo ?? '28442991';
    final accountName = widget.payment.accountName ?? 'PHAM CONG NGUYEN';
    final int amount = widget.payment.amount.round();
    final qrUrl = widget.payment.qrUrl ??
        'https://img.vietqr.io/image/970416-$accountNo-compact2.png?amount=$amount&addInfo=JLSP%20$orderCode&accountName=${accountName.replaceAll(' ', '%20')}';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF0284C7),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thanh toán VietQR Napas 24/7',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Quét bằng mọi ứng dụng ngân hàng & ví điện tử',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Timer box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 6),
                        Text(
                          'Đơn hàng hết hạn sau: $_formattedTime',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // VietQR Image Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            qrUrl,
                            width: 250,
                            height: 250,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 250,
                                height: 250,
                                color: const Color(0xFFF8FAFC),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (ctx, err, stack) {
                              return Container(
                                width: 250,
                                height: 250,
                                color: const Color(0xFFF8FAFC),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.qr_code_2_rounded, size: 72, color: Color(0xFF94A3B8)),
                                    SizedBox(height: 8),
                                    Text(
                                      'Vui lòng chuyển khoản theo thông tin dưới',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                            SizedBox(width: 4),
                            Text(
                              'VietQR Napas 24/7 bảo mật đa tầng',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bank details card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0284C7)),
                            SizedBox(width: 6),
                            Text(
                              'Thông tin chuyển khoản chính xác',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Ngân hàng thụ hưởng', bankName, null),
                        const Divider(height: 16, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          'Số tài khoản',
                          accountNo,
                          () => _copyToClipboard(accountNo, 'Số tài khoản'),
                          isHighlight: true,
                        ),
                        const Divider(height: 16, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          'Tên người nhận',
                          accountName.toUpperCase(),
                          () => _copyToClipboard(accountName.toUpperCase(), 'Tên người nhận'),
                        ),
                        const Divider(height: 16, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          'Số tiền thanh toán',
                          widget.plan.formattedPrice,
                          () => _copyToClipboard(amount.toString(), 'Số tiền'),
                          isHighlightPrice: true,
                        ),
                        const Divider(height: 16, color: Color(0xFFE2E8F0)),
                        _buildDetailRow(
                          'Nội dung chuyển khoản',
                          'JLSP $orderCode',
                          () => _copyToClipboard('JLSP $orderCode', 'Nội dung chuyển khoản'),
                          isHighlightContent: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Note box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lưu ý quan trọng: Vui lòng nhập đúng nội dung chuyển khoản để hệ thống nhận diện và kích hoạt VIP ngay lập tức.',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF991B1B), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom Action Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF0284C7)),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Hệ thống tự động kích hoạt sau 1-3 giây khi nhận được chuyển khoản',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isConfirming ? null : _handleConfirmPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isConfirming
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Tôi đã chuyển khoản thành công',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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

  Widget _buildDetailRow(
    String label,
    String value,
    VoidCallback? onCopy, {
    bool isHighlight = false,
    bool isHighlightPrice = false,
    bool isHighlightContent = false,
  }) {
    Color valueColor = const Color(0xFF1E293B);
    FontWeight fontWeight = FontWeight.w600;
    double fontSize = 13;

    if (isHighlightPrice) {
      valueColor = const Color(0xFF0284C7);
      fontWeight = FontWeight.bold;
      fontSize = 15;
    } else if (isHighlightContent) {
      valueColor = const Color(0xFFDC2626);
      fontWeight = FontWeight.bold;
    } else if (isHighlight) {
      valueColor = const Color(0xFF0F172A);
      fontWeight = FontWeight.bold;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          flex: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    color: valueColor,
                  ),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onCopy != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onCopy,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded, size: 12, color: Color(0xFF0284C7)),
                        SizedBox(width: 3),
                        Text(
                          'Chép',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
