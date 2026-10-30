import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../chat/data/models/chat_models.dart';
import '../../../chat/presentation/widgets/chat_avatar.dart';
import '../../data/models/notification_models.dart';
import '../notification_format.dart';

/// Một dòng trong danh sách thông báo. Thông báo chưa đọc có nền nhấn nhẹ và chấm tròn.
class NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final detail = notificationDetail(notification);
    return Material(
      color: notification.isRead ? Colors.transparent : AppPalette.accentSoft,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeading(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSentence(),
                    if (detail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      formatNotificationTime(notification.createdAt),
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.videoAvailable &&
                  notification.videoThumbnailUrl.isNotEmpty) ...[
                const SizedBox(width: 12),
                _buildThumbnail(),
              ],
              if (!notification.isRead) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    key: const ValueKey('unread-dot'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppPalette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading() {
    final n = notification;
    if (n.isSystem) {
      final approved = n.type == NotificationType.videoApproved;
      return CircleAvatar(
        radius: 22,
        backgroundColor: approved
            ? AppPalette.successContainer
            : AppPalette.errorContainer,
        child: Icon(
          approved ? Icons.check_circle_outline_rounded : Icons.block_rounded,
          color: approved ? AppPalette.success : AppPalette.error,
        ),
      );
    }
    return ChatAvatar(
      radius: 22,
      user: ChatUser(
        id: n.actorId ?? 0,
        username: '',
        displayName: notificationActorName(n),
        avatarUrl: n.actorAvatarUrl,
      ),
    );
  }

  /// Câu chính, in đậm phần tên người thực hiện.
  Widget _buildSentence() {
    final sentence = notificationSentence(notification);
    final name = notification.isSystem
        ? ''
        : notificationActorName(notification);
    final style = TextStyle(
      color: AppPalette.textPrimary,
      fontSize: 14.5,
      height: 1.3,
    );
    final start = name.isEmpty ? -1 : sentence.indexOf(name);
    if (start < 0) return Text(sentence, style: style);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: sentence.substring(0, start)),
          TextSpan(
            text: name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: sentence.substring(start + name.length)),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        notification.videoThumbnailUrl,
        width: 46,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 46,
          height: 58,
          color: AppPalette.surfaceHigh,
          child: Icon(
            Icons.play_arrow_rounded,
            color: AppPalette.textSecondary,
          ),
        ),
      ),
    );
  }
}
