import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// Bottom sheet & dialog của màn DeckOverviewScreen.

/// Snackbar nổi dùng chung của màn bộ thẻ ([isError] → nền coral).
void showDeckSnackBar(BuildContext context, String message,
    {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.flashCoral : AppColors.flashSnackBar,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Menu của tác giả: chỉnh sửa / xóa bộ thẻ. Sheet tự đóng trước khi gọi callback.
void showDeckActionsSheet(
  BuildContext context, {
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  ListTile action(BuildContext ctx, IconData icon, Color color, String title,
      VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  // Màu nền đặt trên chính sheet (Material) để ListTile hiện được hiệu ứng chạm.
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.socialSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thanh kéo drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            action(ctx, Icons.edit_outlined, Colors.white, 'Chỉnh sửa bộ thẻ',
                onEdit),
            const SizedBox(height: 4),
            action(ctx, Icons.delete_outline_rounded, AppColors.flashDanger,
                'Xóa bộ thẻ', onDelete),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Hộp thoại xác nhận xóa vĩnh viễn. Dialog tự đóng trước khi gọi [onConfirm].
void showDeleteDeckDialog(
  BuildContext context, {
  required String deckTitle,
  required VoidCallback onConfirm,
}) {
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AppColors.socialSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Xóa bộ thẻ vĩnh viễn?',
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: Text(
        'Bạn có chắc chắn muốn xóa bộ thẻ "$deckTitle"? Hành động này không thể hoàn tác.',
        style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.flashDanger,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () {
            Navigator.pop(dialogCtx);
            onConfirm();
          },
          child: const Text('Xóa vĩnh viễn',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
