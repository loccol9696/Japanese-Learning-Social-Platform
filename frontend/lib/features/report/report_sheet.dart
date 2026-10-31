import 'package:flutter/material.dart';

import '../../core/auth/auth_guard.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_toast.dart';
import 'report_service.dart';

/// Mở bảng chọn lý do báo cáo; yêu cầu đăng nhập trước. [subject] là mô tả ngắn
/// đối tượng bị báo cáo (ví dụ "video này", "bình luận này").
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTarget target,
  required int targetId,
  required String subject,
  ReportService? service,
}) async {
  if (!await requireAuthentication(
    context,
    message: 'Vui lòng đăng nhập để báo cáo.',
  )) {
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReportSheet(
      target: target,
      targetId: targetId,
      subject: subject,
      service: service ?? ReportService(),
    ),
  );
}

/// Nội dung bảng báo cáo. Dùng qua [showReportSheet]; để public chỉ để test được riêng.
class ReportSheet extends StatefulWidget {
  final ReportTarget target;
  final int targetId;
  final String subject;
  final ReportService service;

  const ReportSheet({
    super.key,
    required this.target,
    required this.targetId,
    required this.subject,
    required this.service,
  });

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  /// Đợi hiệu ứng đóng sheet (~250ms) xong rồi mới hiện toast, tránh hai animation chồng nhau.
  static const Duration _toastDelay = Duration(milliseconds: 300);

  final _detailController = TextEditingController();
  ReportReason? _reason;
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.service.submit(
        target: widget.target,
        targetId: widget.targetId,
        reason: reason,
        detail: _detailController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Future<void>.delayed(
        _toastDelay,
        () => AppToast.showSuccess('Đã gửi báo cáo. Cảm ơn bạn!'),
      );
      // Cố ý không đặt lại _submitting: sheet đang trượt xuống, dựng lại nó ở đây gây giật.
      return;
    } on ApiException catch (e) {
      if (mounted) AppToast.showError(e.message, context: context);
    } catch (_) {
      if (mounted) {
        AppToast.showError('Không thể gửi báo cáo. Vui lòng thử lại.', context: context);
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    // Chỉ phụ thuộc vào viewInsets (bàn phím), không dựng lại theo mọi thay đổi MediaQuery khác.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppPalette.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Báo cáo ${widget.subject}',
                        style: TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chọn lý do. Báo cáo của bạn được ẩn danh với người bị báo cáo.',
                        style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      for (final reason in ReportReason.values)
                        _ReasonTile(
                          reason: reason,
                          selected: reason == _reason,
                          onTap: () => setState(() => _reason = reason),
                        ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _detailController,
                        maxLength: 500,
                        maxLines: 3,
                        style: TextStyle(color: AppPalette.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Mô tả thêm (tuỳ chọn)',
                          hintStyle: TextStyle(color: AppPalette.textSecondary),
                          filled: true,
                          fillColor: AppPalette.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppPalette.border),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _reason == null || _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.accent,
                      foregroundColor: AppPalette.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _submitting
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppPalette.onAccent,
                            ),
                          )
                        : const Text('Gửi báo cáo'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Một lý do: vòng tròn chọn + nhãn. Tự vẽ nhẹ thay cho RadioListTile
/// (ListTile + InkWell + Radio) để khung hình đầu tiên khi mở sheet không bị nặng.
class _ReasonTile extends StatelessWidget {
  final ReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: reason.label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppPalette.accent : AppPalette.textSecondary,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppPalette.accent,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  reason.label,
                  style: TextStyle(color: AppPalette.textPrimary, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
