import 'package:flutter/material.dart';

import '../../data/models/chat_models.dart';

/// Hỏi lại trước khi chặn; trả về true nếu người dùng đồng ý.
Future<bool> confirmBlockUser(BuildContext context, ChatUser user) {
  return _confirm(
    context,
    title: 'Chặn ${user.name}?',
    content:
        'Hai bạn sẽ không nhắn tin cho nhau được nữa. '
        'Lịch sử trò chuyện vẫn được giữ lại.',
    action: 'Chặn',
  );
}

/// Hỏi lại trước khi xoá đoạn chat; trả về true nếu người dùng đồng ý.
Future<bool> confirmDeleteConversation(BuildContext context, ChatUser user) {
  return _confirm(
    context,
    title: 'Xóa đoạn chat với ${user.name}?',
    content:
        'Toàn bộ tin nhắn sẽ bị xóa ở phía bạn và không khôi phục được. '
        '${user.name} vẫn giữ lịch sử của họ.',
    action: 'Xóa',
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String content,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed == true;
}
