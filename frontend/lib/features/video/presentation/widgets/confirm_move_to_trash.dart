import 'package:flutter/material.dart';

/// Hỏi lại trước khi chuyển video vào thùng rác. Trả về true nếu người dùng đồng ý.
Future<bool> confirmMoveToTrash(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Xóa video?'),
      content: const Text(
        'Video cùng bình luận và lượt tương tác sẽ được giữ trong thùng rác '
        '30 ngày, sau đó bị xóa hẳn. Bạn có thể khôi phục trong thời gian này.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Xóa'),
        ),
      ],
    ),
  );
  return confirmed == true;
}
