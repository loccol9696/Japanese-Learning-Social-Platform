import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_toast.dart';
import '../models/subscription_model.dart';
import '../models/token_usage_model.dart';
import '../services/subscription_service.dart';

/// Người dùng chọn gì ở trang thanh toán thành công.
enum SubscriptionSuccessAction { viewProfile, startLearning }

/// Mở trang thanh toán thành công và trả về nút người dùng đã bấm (null nếu thoát bằng nút quay lại).
Future<SubscriptionSuccessAction?> showSubscriptionSuccess(
  BuildContext context, {
  required PaymentOrder order,
  required SubscriptionPlan plan,
}) {
  return Navigator.of(context).push<SubscriptionSuccessAction>(
    MaterialPageRoute(
      builder: (_) => SubscriptionSuccessScreen(order: order, plan: plan),
    ),
  );
}

/// Trang xác nhận sau khi gói được kích hoạt: dấu tick, tóm tắt gói, hạn dùng, số tiền và mã giao dịch.
class SubscriptionSuccessScreen extends StatefulWidget {
  final PaymentOrder order;
  final SubscriptionPlan plan;

  const SubscriptionSuccessScreen({super.key, required this.order, required this.plan});

  @override
  State<SubscriptionSuccessScreen> createState() => _SubscriptionSuccessScreenState();
}

class _SubscriptionSuccessScreenState extends State<SubscriptionSuccessScreen> {
  /// Ngày hết hạn thật từ server (đã cộng dồn nếu đang có gói); trong lúc chờ dùng ước tính từ thời hạn của gói.
  SubscriptionStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await SubscriptionService.instance.getMyStatus();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      // Giữ ngày ước tính.
    }
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String get _validUntil {
    final status = _status;
    if (status != null && status.isLifetime) return 'Trọn đời';
    if (status != null && status.endDate != null) return _date(status.endDate!);
    if (widget.plan.durationDays >= 3650) return 'Trọn đời';
    return _date(DateTime.now().add(Duration(days: widget.plan.durationDays)));
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.order.orderCode));
    if (mounted) AppToast.showSuccess('Đã sao chép mã giao dịch', context: context);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final order = widget.order;
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 56),
                          _CheckBadge(),
                          const SizedBox(height: 28),
                          Text(
                            'Thanh toán thành công',
                            key: const ValueKey('success-title'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppPalette.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Bạn đã là hội viên Kotoba Premium.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: AppPalette.textSecondary),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            key: const ValueKey('success-card'),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppPalette.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppPalette.border),
                            ),
                            child: Column(
                              children: [
                                _Row(
                                  label: 'Gói',
                                  value: '${plan.name} · ${plan.durationLabel.toLowerCase()}',
                                  valueKey: const ValueKey('success-plan'),
                                ),
                                _Row(
                                  label: 'Hiệu lực đến',
                                  value: _validUntil,
                                  valueKey: const ValueKey('success-until'),
                                ),
                                _Row(
                                  label: 'Số tiền',
                                  value: '${formatTokenCount(order.amount.round())} đ',
                                  valueKey: const ValueKey('success-amount'),
                                ),
                                _Row(
                                  label: 'Mã giao dịch',
                                  value: order.orderCode,
                                  valueKey: const ValueKey('success-code'),
                                  valueColor: AppPalette.accent,
                                  trailing: IconButton(
                                    key: const ValueKey('success-copy'),
                                    tooltip: 'Sao chép mã',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                    icon: Icon(Icons.copy_rounded, size: 16, color: AppPalette.accent),
                                    onPressed: _copyCode,
                                  ),
                                  last: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      key: const ValueKey('success-view-profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.accent,
                        foregroundColor: AppPalette.onAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.of(context).pop(SubscriptionSuccessAction.viewProfile),
                      child: const Text('Xem hồ sơ của tôi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    key: const ValueKey('success-start-learning'),
                    onPressed: () => Navigator.of(context).pop(SubscriptionSuccessAction.startLearning),
                    style: TextButton.styleFrom(
                      foregroundColor: AppPalette.textPrimary,
                      minimumSize: const Size(double.infinity, 44),
                    ),
                    child: const Text('Bắt đầu học', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dấu tick trong vòng tròn có quầng sáng.
class _CheckBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final accent = AppPalette.accent;
    return Container(
      key: const ValueKey('success-badge'),
      width: 116,
      height: 116,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.12),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 36, spreadRadius: 2)],
      ),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent,
          border: Border.all(color: AppPalette.info, width: 2.5),
        ),
        child: Icon(Icons.check_rounded, size: 46, color: AppPalette.onAccent),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Key valueKey;
  final Color? valueColor;
  final Widget? trailing;
  final bool last;

  const _Row({
    required this.label,
    required this.value,
    required this.valueKey,
    this.valueColor,
    this.trailing,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: AppPalette.border.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13.5, color: AppPalette.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              key: valueKey,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: valueColor ?? AppPalette.textPrimary),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}
