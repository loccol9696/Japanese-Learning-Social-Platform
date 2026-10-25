import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Bảng chọn cách đổi ảnh đại diện: chụp ảnh mới, chọn từ thư viện, hoặc xoá ảnh hiện tại.
/// Bảng tự đóng rồi mới gọi hành động tương ứng.
class AvatarPickerSheet extends StatelessWidget {
  static const Color _dangerRed = Color(0xFFFF5C6C);

  final bool hasAvatar;
  final VoidCallback onTakePhoto;
  final VoidCallback onPickFromLibrary;
  final VoidCallback onRemove;

  const AvatarPickerSheet({
    super.key,
    required this.hasAvatar,
    required this.onTakePhoto,
    required this.onPickFromLibrary,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      // Material (không phải Container tô màu) để hiệu ứng chạm hiển thị.
      color: AppPalette.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              decoration: BoxDecoration(
                color: AppPalette.textSecondary.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _row(
              context,
              icon: Icons.photo_camera_outlined,
              title: 'Chụp ảnh mới',
              onTap: onTakePhoto,
            ),
            _divider(),
            _row(
              context,
              icon: Icons.image_outlined,
              title: 'Chọn từ thư viện',
              onTap: onPickFromLibrary,
            ),
            if (hasAvatar) ...[
              _divider(),
              _row(
                context,
                icon: Icons.delete_outline_rounded,
                title: 'Xóa ảnh hiện tại',
                color: _dangerRed,
                onTap: onRemove,
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 28),
    child: Divider(height: 1, color: AppPalette.border),
  );

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = AppPalette.textPrimary,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
