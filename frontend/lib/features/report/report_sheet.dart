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
    builder: (_) => _ReportSheet(
      target: target,
      targetId: targetId,
      subject: subject,
      service: service ?? ReportService(),
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final ReportTarget target;
  final int targetId;
  final String subject;
  final ReportService service;

  const _ReportSheet({
    required this.target,
    required this.targetId,
    required this.subject,
    required this.service,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
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
      AppToast.showSuccess('Đã gửi báo cáo. Cảm ơn bạn!');
    } on ApiException catch (e) {
      if (mounted) AppToast.showError(e.message, context: context);
    } catch (_) {
      if (mounted) {
        AppToast.showError('Không thể gửi báo cáo. Vui lòng thử lại.', context: context);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                RadioGroup<ReportReason>(
                  groupValue: _reason,
                  onChanged: (value) => setState(() => _reason = value),
                  child: Column(
                    children: [
                      for (final reason in ReportReason.values)
                        RadioListTile<ReportReason>(
                          value: reason,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppPalette.accent,
                          title: Text(
                            reason.label,
                            style: TextStyle(color: AppPalette.textPrimary),
                          ),
                        ),
                    ],
                  ),
                ),
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
                const SizedBox(height: 8),
                SizedBox(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
