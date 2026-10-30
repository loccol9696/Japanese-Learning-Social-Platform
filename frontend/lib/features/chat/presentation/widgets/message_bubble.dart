import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../data/models/chat_models.dart';
import '../chat_format.dart';
import 'video_share_card.dart';

/// Một tin nhắn trong khung chat. Tin của mình nằm bên phải (màu nhấn), của đối
/// phương bên trái. Tin gửi lỗi có thể bấm để gửi lại; tin có chữ Nhật có thêm nút
/// tra từ và dịch.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  /// Hiển thị "Đã xem" dưới tin này.
  final bool showSeen;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenVideo;
  final VoidCallback? onOpenImage;
  final VoidCallback? onLongPress;
  final VoidCallback? onStudy;
  final VoidCallback? onTranslate;

  /// Bản dịch đang hiển thị dưới tin (null nếu chưa dịch hoặc đã ẩn).
  final String? translation;
  final bool translating;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showSeen = false,
    this.onRetry,
    this.onOpenVideo,
    this.onOpenImage,
    this.onLongPress,
    this.onStudy,
    this.onTranslate,
    this.translation,
    this.translating = false,
  });

  bool get _showsStudyActions =>
      !message.recalled &&
      message.id != null &&
      containsJapanese(message.content);

  @override
  Widget build(BuildContext context) {
    final isShare =
        !message.recalled &&
        message.type == MessageType.videoShare &&
        message.video != null;
    final isImage = !message.recalled && message.type == MessageType.image;
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
                child: GestureDetector(
                  onLongPress: onLongPress,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                    ),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                      decoration: BoxDecoration(
                        color: message.recalled
                            ? Colors.transparent
                            : isMine
                            ? AppPalette.accent
                            : AppPalette.surfaceHigh,
                        border: message.recalled
                            ? Border.all(color: AppPalette.border)
                            : null,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMine ? 18 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.recalled) _buildRecalled(),
                          if (isShare)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: VideoShareCard(
                                video: message.video!,
                                startMs: message.videoStartMs,
                                onTap: message.video!.available
                                    ? onOpenVideo
                                    : null,
                              ),
                            ),
                          if (isImage) _buildImage(),
                          if (!message.recalled && message.content.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: isShare ? 8 : 0),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  message.content,
                                  style: TextStyle(
                                    color: AppPalette.textPrimary,
                                    fontSize: 15,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 3),
                          _buildMeta(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showsStudyActions) _buildStudyActions(),
          if (translation != null) _buildTranslation(context),
          if (failed && isMine)
            Padding(
              padding: EdgeInsets.only(top: 2, right: 4),
              child: Text(
                'Chưa gửi được • bấm để gửi lại',
                style: TextStyle(color: AppPalette.like, fontSize: 11),
              ),
            ),
          if (showSeen)
            Padding(
              padding: EdgeInsets.only(top: 2, right: 4),
              child: Text(
                'Đã xem',
                style: TextStyle(color: AppPalette.textSecondary, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecalled() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Tin nhắn đã được thu hồi',
        style: TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildImage() {
    final local = message.localImage;
    final image = local != null
        ? Image.memory(local, fit: BoxFit.cover)
        : Image.network(
            message.imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Padding(
              padding: const EdgeInsets.all(24),
              child: Icon(
                Icons.broken_image_outlined,
                color: AppPalette.textSecondary,
              ),
            ),
          );

    return GestureDetector(
      onTap: message.imageUrl.isNotEmpty ? onOpenImage : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: image,
        ),
      ),
    );
  }

  Widget _buildStudyActions() {
    Widget action(String label, VoidCallback? onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: AppPalette.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        action('Tra từ', onStudy),
        action(
          translating
              ? 'Đang dịch...'
              : translation != null
              ? 'Ẩn bản dịch'
              : 'Dịch',
          translating ? null : onTranslate,
        ),
      ],
    );
  }

  Widget _buildTranslation(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          translation!,
          style: TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 13,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildMeta() {
    final sending = message.status == MessageStatus.sending;
    final metaColor = message.recalled
        ? AppPalette.textSecondary
        : AppPalette.textPrimary.withValues(alpha: 0.65);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatClock(message.createdAt),
          style: TextStyle(color: metaColor, fontSize: 10),
        ),
        if (isMine && sending)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.schedule_rounded, size: 11, color: metaColor),
          ),
      ],
    );
  }
}
