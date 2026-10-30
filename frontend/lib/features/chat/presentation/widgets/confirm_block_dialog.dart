import 'package:flutter/material.dart';

import '../../data/models/chat_models.dart';

/// Hỏi lại trước khi chặn; trả về true nếu người dùng đồng ý.
Future<bool> confirmBlockUser(BuildContext context, ChatUser user) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text('Chặn ${user.name}?'),
      content: const Text(
        'Hai bạn sẽ không nhắn tin cho nhau được nữa. '
        'Lịch sử trò chuyện vẫn được giữ lại.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(false),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialog).pop(true),
          child: const Text('Chặn'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
