import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_toast.dart';
import '../models/subscription_model.dart';
import '../services/subscription_service.dart';

/// Bảng thanh toán chuyển khoản VietQR cho một đơn đã tạo ở server.
///
/// App chỉ hiển thị QR và thông tin chuyển khoản rồi hỏi lại trạng thái đơn (chỉ đọc). Đơn chỉ thành công khi server nhận
/// được tiền từ ngân hàng; không có nút "tôi đã chuyển khoản" nào tự xác nhận. Đóng bảng trả `true` khi đơn đã thành
/// công, ngược lại `false` / null.
class VietQrPaymentSheet extends StatefulWidget {
  final PaymentOrder order;
  final SubscriptionPlan? plan;
  final SubscriptionService service;

  /// Chu kỳ hỏi trạng thái; sau [slowDownAfter] chuyển sang [slowPollInterval] để đỡ tốn pin và máy chủ.
  final Duration pollInterval;
  final Duration slowPollInterval;
  final Duration slowDownAfter;

  /// Dựng ảnh mã QR từ link; mặc định tải SVG qua mạng. Truyền hàm khác khi cần thay (vd. trong test không có mạng).
  final Widget Function(BuildContext context, String url)? qrBuilder;

  VietQrPaymentSheet({
    super.key,
    required this.order,
    this.plan,
    SubscriptionService? service,
    this.pollInterval = const Duration(seconds: 3),
    this.slowPollInterval = const Duration(seconds: 6),
    this.slowDownAfter = const Duration(minutes: 1),
    this.qrBuilder,
  }) : service = service ?? SubscriptionService.instance;

  @override
  State<VietQrPaymentSheet> createState() => _VietQrPaymentSheetState();
}

class _VietQrPaymentSheetState extends State<VietQrPaymentSheet> {
  late PaymentOrder _order = widget.order;
  Timer? _pollTimer;
  Timer? _clockTimer;
  late final DateTime _startedAt = DateTime.now();
  bool _polling = false;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRemaining(),
    );
    _schedulePoll();
    if (_order.isPaid) _finishPaid();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final expiresAt = _order.expiresAt;
    final left = expiresAt == null
        ? Duration.zero
        : expiresAt.difference(DateTime.now());
    if (mounted) {
      setState(() => _remaining = left.isNegative ? Duration.zero : left);
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    final slow = DateTime.now().difference(_startedAt) >= widget.slowDownAfter;
    _pollTimer = Timer(
      slow ? widget.slowPollInterval : widget.pollInterval,
      () async {
        await _refresh();
        if (mounted && !_order.isFinished) _schedulePoll();
      },
    );
  }

  /// Hỏi lại trạng thái đơn. Lỗi mạng tạm thời thì bỏ qua và thử lại ở lần sau.
  Future<void> _refresh({bool manual = false}) async {
    if (_polling) return;
    _polling = true;
    try {
      final latest = await widget.service.getOrder(_order.orderCode);
      if (!mounted) return;
      setState(() => _order = latest);
      if (latest.isPaid) {
        _finishPaid();
      } else if (manual && !latest.isFinished) {
        AppToast.showError(
          'Chưa nhận được tiền. Vui lòng chờ ít giây sau khi chuyển khoản.',
          context: context,
        );
      }
    } on ApiException catch (error) {
      if (mounted && manual) {
        AppToast.showError(error.message, context: context);
      }
    } catch (_) {
      // Mất mạng thoáng qua: lần hỏi sau sẽ thử lại.
    } finally {
      _polling = false;
    }
  }

  void _finishPaid() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) AppToast.showSuccess('Đã sao chép $label', context: context);
  }

  String _money(double amount) {
    final text = amount.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) buffer.write('.');
      buffer.write(text[i]);
    }
    return '$buffer đ';
  }

  String get _countdown {
    final minutes = _remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Thanh toán chuyển khoản',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('payment-close'),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppPalette.textSecondary,
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              if ((order.planName ?? widget.plan?.name) != null)
                Text(
                  order.planName ?? widget.plan!.name,
                  style: TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 14,
                  ),
                ),
              const SizedBox(height: 14),
              _buildStatusBanner(order),
              const SizedBox(height: 14),
              if (!order.isExpired && !order.isCancelled) ...[
                _buildQr(order),
                const SizedBox(height: 14),
                _buildDetails(order),
              ],
              const SizedBox(height: 14),
              _buildActions(order),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(PaymentOrder order) {
    late final IconData icon;
    late final Color color;
    late final String text;
    if (order.isExpired) {
      icon = Icons.timer_off_rounded;
      color = AppPalette.error;
      text =
          'Đơn đã hết hạn. Nếu bạn đã chuyển khoản, hệ thống vẫn ghi nhận trong vòng 24 giờ; '
          'hoặc tạo đơn mới để thanh toán lại.';
    } else if (order.isCancelled) {
      icon = Icons.cancel_rounded;
      color = AppPalette.error;
      text = 'Đơn đã bị hủy.';
    } else if (order.needsReview) {
      icon = Icons.info_outline_rounded;
      color = AppPalette.warning;
      final paid = order.paidAmount ?? 0;
      text = paid > 0 && order.remainingAmount > 0
          ? 'Đã nhận ${_money(paid)}, còn thiếu ${_money(order.remainingAmount)}. Chuyển bù đúng nội dung để kích hoạt.'
          : 'Đã nhận tiền nhưng cần quản trị viên xác nhận. Vui lòng liên hệ hỗ trợ kèm mã ${order.transferMemo}.';
    } else {
      icon = Icons.hourglass_top_rounded;
      color = AppPalette.accent;
      text = 'Đang chờ thanh toán. Còn $_countdown để hoàn tất.';
    }
    return Container(
      key: const ValueKey('payment-status'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQr(PaymentOrder order) {
    final url = order.qrUrl;
    return Center(
      child: Container(
        width: 232,
        height: 232,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: url == null || url.isEmpty
            ? _qrFallback()
            : widget.qrBuilder != null
            ? widget.qrBuilder!(context, url)
            // img.vietqr.io chỉ trả ảnh SVG (png/jpg chuyển hướng sang svg) nên phải vẽ bằng flutter_svg.
            : SvgPicture.network(
                url,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                errorBuilder: (context, error, stack) => _qrFallback(),
              ),
      ),
    );
  }

  Widget _qrFallback() => const Center(
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        'Không tải được mã QR.\nHãy chuyển khoản thủ công theo thông tin bên dưới.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black87, fontSize: 13),
      ),
    ),
  );

  Widget _buildDetails(PaymentOrder order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _row('Ngân hàng', order.bankName),
          _row('Số tài khoản', order.accountNo, copyLabel: 'số tài khoản'),
          _row('Chủ tài khoản', order.accountName),
          _row(
            'Số tiền',
            _money(order.amount),
            copyValue: order.amount.round().toString(),
            copyLabel: 'số tiền',
          ),
          _row(
            'Nội dung',
            order.transferMemo,
            copyLabel: 'nội dung chuyển khoản',
            emphasize: true,
            hint: 'Ghi đúng nội dung này để hệ thống tự kích hoạt',
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    String? copyLabel,
    String? copyValue,
    bool emphasize = false,
    String? hint,
  }) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: emphasize
                        ? AppPalette.accent
                        : AppPalette.textPrimary,
                    fontSize: emphasize ? 17 : 14.5,
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: emphasize ? 0.5 : 0,
                  ),
                ),
                if (hint != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      hint,
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (copyLabel != null)
            InkWell(
              key: ValueKey('copy-$label'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => _copy(copyValue ?? value, copyLabel),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.copy_rounded,
                  size: 18,
                  color: AppPalette.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(PaymentOrder order) {
    if (order.isExpired || order.isCancelled) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          key: const ValueKey('payment-new-order'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Đóng và tạo đơn mới'),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        key: const ValueKey('payment-check'),
        onPressed: () => _refresh(manual: true),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Kiểm tra lại'),
      ),
    );
  }
}
