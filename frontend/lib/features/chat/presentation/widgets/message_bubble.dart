import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../data/models/chat_models.dart';
import '../chat_format.dart';
import 'video_share_card.dart';

/// Một tin nhắn trong khung chat. Tin của mình nằm bên phải (màu nhấn), của đối
/// phương bên trái. Tin gửi lỗi có thể bấm để gửi lại.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  /// Hiển thị "Đã xem" dưới tin này.
  final bool showSeen;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenVideo;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showSeen = false,
    this.onRetry,
    this.onOpenVideo,
  });

  @override
  Widget build(BuildContext context) {
    final isShare =
        message.type == MessageType.videoShare && message.video != null;
    final failed = message.status == MessageStatus.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (failed && isMine)
                IconButton(
                  onPressed: onRetry,
                  tooltip: 'Gửi lại',
                  icon: Icon(
                    Icons.error_outline_rounded,
                    color: AppPalette.like,
                  ),
                ),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMine
                          ? AppPalette.accent
                          : AppPalette.surfaceHigh,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    // Cột căn trái, rộng vừa nội dung: không bọc Align vì Align giãn hết bề ngang tối đa
                    // và làm bong bóng dài ra dù tin ngắn.
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isShare)
                          VideoShareCard(
                            video: message.video!,
                            startMs: message.videoStartMs,
                            onTap: message.video!.available ? onOpenVideo : null,
                          ),
                        if (message.content.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: isShare ? 8 : 0),
                            child: Text(
                              message.content,
                              style: TextStyle(
                                color: AppPalette.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (failed && isMine)
            Padding(
              padding: EdgeInsets.only(top: 2, right: 4),
              child: Text(
                'Chưa gửi được • bấm để gửi lại',
                style: TextStyle(color: AppPalette.like, fontSize: 11),
              ),
            ),
          _buildMeta(),
        ],
      ),
    );
  }

  /// Giờ gửi dưới bong bóng, kèm "· Đã xem" cho tin cuối của mình mà đối phương đã đọc.
  Widget _buildMeta() {
    final sending = message.status == MessageStatus.sending;
    final label = showSeen
        ? '${formatClock(message.createdAt)} · Đã xem'
        : formatClock(message.createdAt);
    final color = AppPalette.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, right: 4, bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 11)),
          if (isMine && sending)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.schedule_rounded, size: 11, color: color),
            ),
        ],
      ),
    );
  }
}
