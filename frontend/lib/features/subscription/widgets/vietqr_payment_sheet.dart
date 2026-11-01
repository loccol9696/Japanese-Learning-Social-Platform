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

  double _countdownProgress(PaymentOrder order) {
    final createdAt = order.createdAt;
    final expiresAt = order.expiresAt;
    if (createdAt == null || expiresAt == null) return 0;
    final totalSeconds = expiresAt.difference(createdAt).inSeconds;
    if (totalSeconds <= 0) return 0;
    return (_remaining.inSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Material(
      color: AppPalette.background,
      child: Container(
        constraints: const BoxConstraints.expand(),
        decoration: BoxDecoration(
          color: AppPalette.background,
          border: Border.all(color: AppPalette.border),
        ),
        child: SafeArea(
          top: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildPaymentProgress(order),
                const SizedBox(height: 20),
                if (!order.isExpired && !order.isCancelled) ...[
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                    decoration: BoxDecoration(
                      color: AppPalette.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        _buildQr(order),
                        const SizedBox(height: 14),
                        _buildDetails(order),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 10),
                  child: _buildActions(order),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const ValueKey('payment-close'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppPalette.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          Text(
            'Thanh toán',
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentProgress(PaymentOrder order) {
    if (order.isExpired || order.isCancelled || order.needsReview) {
      return _buildStatusBanner(order);
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time_rounded, color: AppPalette.info, size: 17),
            const SizedBox(width: 5),
            Text(
              _countdown,
              key: const ValueKey('payment-status'),
              semanticsLabel: 'Đang chờ thanh toán. Còn $_countdown',
              style: TextStyle(
                color: AppPalette.info,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 3,
          decoration: BoxDecoration(
            color: AppPalette.border,
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: _countdownProgress(order),
            child: Container(
              decoration: BoxDecoration(
                color: AppPalette.info,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
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
        width: 224,
        height: 224,
        padding: const EdgeInsets.all(10),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: Column(
        children: [
          _row('Ngân hàng', order.bankName),
          _detailDivider(),
          _row('Số tài khoản', order.accountNo, copyLabel: 'số tài khoản'),
          _detailDivider(),
          _row('Chủ tài khoản', order.accountName),
          _detailDivider(),
          _row(
            'Số tiền',
            _money(order.amount),
            copyValue: order.amount.round().toString(),
            copyLabel: 'số tiền',
          ),
          _detailDivider(),
          _row(
            'Nội dung',
            order.transferMemo,
            copyLabel: 'nội dung chuyển khoản',
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _detailDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppPalette.border.withValues(alpha: 0.18),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 14.5,
                height: 1.35,
              ),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
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
                  size: 20,
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
      child: FilledButton.icon(
        key: const ValueKey('payment-check'),
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.accent,
          foregroundColor: AppPalette.onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => _refresh(manual: true),
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text(
          'Kiểm tra thanh toán',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
