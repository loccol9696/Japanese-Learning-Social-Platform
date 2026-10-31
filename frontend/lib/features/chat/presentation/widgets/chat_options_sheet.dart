import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Lựa chọn trong bảng tuỳ chọn của khung chat.
enum ChatOption { report, block, deleteConversation }

/// Mở bảng tuỳ chọn (báo cáo, chặn, xoá cuộc trò chuyện); trả về lựa chọn hoặc null nếu đóng bảng.
Future<ChatOption?> showChatOptionsSheet(BuildContext context, {bool blocked = false}) {
  return showModalBottomSheet<ChatOption>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => ChatOptionsSheet(blocked: blocked),
  );
}

class ChatOptionsSheet extends StatelessWidget {
  const ChatOptionsSheet({super.key, this.blocked = false});

  /// Đã chặn người này thì dòng chặn đổi thành "Bỏ chặn".
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    return Material(
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
              _OptionRow(
                key: const ValueKey('chat-option-report'),
                icon: Icons.flag_outlined,
                label: 'Báo cáo',
                color: AppPalette.textPrimary,
                option: ChatOption.report,
              ),
              const _OptionDivider(),
              _OptionRow(
                key: const ValueKey('chat-option-block'),
                icon: Icons.block_rounded,
                label: blocked ? 'Bỏ chặn người dùng' : 'Chặn người dùng',
                color: AppPalette.error,
                option: ChatOption.block,
              ),
              const _OptionDivider(),
              _OptionRow(
                key: const ValueKey('chat-option-delete'),
                icon: Icons.delete_outline_rounded,
                label: 'Xóa cuộc trò chuyện',
                color: AppPalette.error,
                option: ChatOption.deleteConversation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionDivider extends StatelessWidget {
  const _OptionDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Divider(height: 1, color: AppPalette.textPrimary.withValues(alpha: 0.08)),
  );
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.option,
  });

  final IconData icon;
  final String label;
  final Color color;
  final ChatOption option;

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
