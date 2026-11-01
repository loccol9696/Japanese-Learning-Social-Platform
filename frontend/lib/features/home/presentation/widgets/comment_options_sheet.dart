import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Lựa chọn trong menu mở bằng cách nhấn giữ một bình luận.
enum CommentOption { reply, copy, pin, report, delete }

/// Mở menu của một bình luận; trả về lựa chọn hoặc null nếu đóng menu.
///
/// [canPin]: chủ video đang nhấn giữ một bình luận gốc; [pinned] đổi nhãn thành "Bỏ ghim".
Future<CommentOption?> showCommentOptionsSheet(
  BuildContext context, {
  required bool canPin,
  required bool pinned,
  required bool canReport,
  required bool canDelete,
  required String pinLabel,
  required String unpinLabel,
}) {
  return showModalBottomSheet<CommentOption>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Material(
      color: AppPalette.navBar,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppPalette.textPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const _OptionRow(
                icon: Icons.reply_rounded,
                label: 'Trả lời',
                option: CommentOption.reply,
              ),
              const _OptionRow(
                icon: Icons.copy_rounded,
                label: 'Sao chép',
                option: CommentOption.copy,
              ),
              if (canPin)
                _OptionRow(
                  icon: pinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                  label: pinned ? unpinLabel : pinLabel,
                  option: CommentOption.pin,
                ),
              if (canReport)
                const _OptionRow(
                  icon: Icons.flag_outlined,
                  label: 'Báo cáo',
                  option: CommentOption.report,
                ),
              if (canDelete)
                const _OptionRow(
                  icon: Icons.delete_outline_rounded,
                  label: 'Xóa',
                  option: CommentOption.delete,
                  destructive: true,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.option,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final CommentOption option;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppPalette.error : AppPalette.textPrimary;
    return InkWell(
      onTap: () => Navigator.of(context).pop(option),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
