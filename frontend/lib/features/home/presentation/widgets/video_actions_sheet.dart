import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Thao tác người dùng chọn trong menu nâng cao của video.
enum VideoAction { toggleDoubleSpeed, openCreator, report }

/// Mở menu nâng cao của video (nhấn giữ trên video). Trả về thao tác đã chọn,
/// null nếu người dùng đóng menu.
Future<VideoAction?> showVideoActionsSheet(
  BuildContext context, {
  required bool isDoubleSpeed,
  required bool canChangeSpeed,
  required bool canOpenCreator,
  required bool canReport,
  String creatorName = '',
}) {
  return showModalBottomSheet<VideoAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => VideoActionsSheet(
      isDoubleSpeed: isDoubleSpeed,
      canChangeSpeed: canChangeSpeed,
      canOpenCreator: canOpenCreator,
      canReport: canReport,
      creatorName: creatorName,
    ),
  );
}

/// Nội dung menu. Dùng qua [showVideoActionsSheet]; để public chỉ để test được riêng.
class VideoActionsSheet extends StatelessWidget {
  final bool isDoubleSpeed;
  final bool canChangeSpeed;
  final bool canOpenCreator;
  final bool canReport;
  final String creatorName;

  const VideoActionsSheet({
    super.key,
    required this.isDoubleSpeed,
    required this.canChangeSpeed,
    required this.canOpenCreator,
    required this.canReport,
    this.creatorName = '',
  });

  @override
  Widget build(BuildContext context) {
    final name = creatorName.trim();
    return Material(
      color: AppPalette.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppPalette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.speed_rounded,
              label: isDoubleSpeed ? 'Về tốc độ thường' : 'Phát tốc độ x2',
              // Video chưa tải xong thì chưa đổi được tốc độ.
              onTap: canChangeSpeed
                  ? () => Navigator.of(context).pop(VideoAction.toggleDoubleSpeed)
                  : null,
            ),
            if (canOpenCreator)
              _ActionTile(
                icon: Icons.person_outline_rounded,
                label: name.isEmpty ? 'Xem trang người đăng' : 'Xem trang của $name',
                onTap: () => Navigator.of(context).pop(VideoAction.openCreator),
              ),
            if (canReport)
              _ActionTile(
                icon: Icons.flag_outlined,
                label: 'Báo cáo video',
                color: AppPalette.error,
                onTap: () => Navigator.of(context).pop(VideoAction.report),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = onTap == null
        ? AppPalette.textSecondary
        : color ?? AppPalette.textPrimary;
    return ListTile(
      leading: Icon(icon, color: foreground),
      title: Text(label, style: TextStyle(color: foreground, fontSize: 15)),
      onTap: onTap,
    );
  }
}
