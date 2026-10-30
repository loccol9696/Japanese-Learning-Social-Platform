import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/services/notification_hub.dart';

/// Icon chuông ở góc trái header Home, kèm số thông báo chưa đọc.
class NotificationBell extends StatelessWidget {
  final AdaptiveVideoTheme theme;
  final VoidCallback onTap;
  final ValueListenable<int>? unread;

  const NotificationBell({
    super.key,
    required this.theme,
    required this.onTap,
    this.unread,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: unread ?? NotificationHub.instance.unreadCount,
      builder: (context, count, _) {
        return IconButton(
          tooltip: appStrings.notificationsTitle,
          onPressed: onTap,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 28,
                color: theme.headerSelectedText,
                shadows: theme.textShadows,
              ),
              if (count > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    key: const ValueKey('notification-badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(minWidth: 15),
                    decoration: BoxDecoration(
                      color: AppPalette.like,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.onAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
