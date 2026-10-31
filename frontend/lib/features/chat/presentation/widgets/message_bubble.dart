import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../data/models/chat_models.dart';
import '../chat_format.dart';
import 'deck_share_card.dart';
import 'video_share_card.dart';

/// Một tin nhắn trong khung chat. Tin của mình nằm bên phải (màu nhấn), của đối
/// phương bên trái. Các tin liên tiếp của một người gộp thành nhóm, chỉ tin cuối nhóm
/// có góc nhọn. Bong bóng chỉ hiện nội dung; chạm vào tin để xem giờ gửi và nút tra
/// từ, dịch (với tin có chữ Nhật). Tin gửi lỗi chạm để gửi lại.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  /// Tin cuối của một nhóm tin liên tiếp.
  final bool isLastInGroup;

  /// Đang hiện giờ gửi và các nút thao tác dưới tin.
  final bool showDetails;

  /// Hiển thị "Đã xem" dưới tin này.
  final bool showSeen;
  final VoidCallback? onTap;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenVideo;
  final VoidCallback? onOpenDeck;
  final VoidCallback? onOpenImage;
  final VoidCallback? onLongPress;
  final VoidCallback? onStudy;
  final VoidCallback? onTranslate;

  /// Tên người gửi tin được trích dẫn.
  final String replyAuthor;

  /// Chạm vào trích dẫn để tới tin gốc.
  final VoidCallback? onOpenReply;

  /// Bản dịch đang hiển thị dưới tin (null nếu chưa dịch hoặc đã ẩn).
  final String? translation;
  final bool translating;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.isLastInGroup = true,
    this.showDetails = false,
    this.showSeen = false,
    this.onTap,
    this.onRetry,
    this.onOpenVideo,
    this.onOpenDeck,
    this.onOpenImage,
    this.onLongPress,
    this.onStudy,
    this.onTranslate,
    this.replyAuthor = '',
    this.onOpenReply,
    this.translation,
    this.translating = false,
  });

  bool get _failed => message.status == MessageStatus.failed;
  bool get _sending => message.status == MessageStatus.sending;
  bool get _isDeckShare =>
      !message.recalled && message.type == MessageType.deckShare && message.deck != null;
  bool get _isImage => !message.recalled && message.type == MessageType.image;
  bool get _isShare =>
      !message.recalled &&
      message.type == MessageType.videoShare &&
      message.video != null;

  bool get _canStudy =>
      !message.recalled &&
      message.id != null &&
      containsJapanese(message.content);

  Color get _textColor => isMine ? AppPalette.onAccent : AppPalette.textPrimary;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            if (_failed && isMine)
              IconButton(
                onPressed: onRetry,
                tooltip: 'Gửi lại',
                icon: Icon(Icons.error_outline_rounded, color: AppPalette.like),
              ),
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _failed ? onRetry : onTap,
                onLongPress: onLongPress,
                child: _buildBubble(context),
              ),
            ),
          ],
        ),
        if (showDetails || _sending) _buildMeta(),
        if (_canStudy && (showDetails || translation != null))
          _buildStudyActions(),
        if (translation != null) _buildTranslation(context),
        if (_failed && isMine)
          _caption('Chưa gửi được • bấm để gửi lại', AppPalette.like),
        if (showSeen) _caption('Đã xem', AppPalette.textSecondary),
      ],
    );
  }

  Widget _caption(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
      child: Text(text, style: TextStyle(color: color, fontSize: 11)),
    );
  }

  Widget _buildBubble(BuildContext context) {
    const round = Radius.circular(20);
    final tail = isLastInGroup ? const Radius.circular(4) : round;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      child: Container(
        padding: _isImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
            topLeft: round,
            topRight: round,
            bottomLeft: isMine ? round : tail,
            bottomRight: isMine ? tail : round,
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (message.recalled) {
      return Text(
        'Tin nhắn đã được thu hồi',
        style: TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 14,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.replyTo != null) _buildQuote(message.replyTo!),
        if (_isShare)
          VideoShareCard(
            video: message.video!,
            startMs: message.videoStartMs,
            onTap: message.video!.available ? onOpenVideo : null,
          ),
        if (_isDeckShare)
          DeckShareCard(
            deck: message.deck!,
            onTap: message.deck!.available ? onOpenDeck : null,
          ),
        if (_isImage) _buildImage(),
        if (message.content.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: _isShare || _isDeckShare ? 8 : 0),
            child: Text(
              message.content,
              style: TextStyle(color: _textColor, fontSize: 15, height: 1.3),
            ),
          ),
      ],
    );
  }

  Widget _buildQuote(MessageReply reply) {
    final bar = isMine ? AppPalette.onAccent : AppPalette.accent;
    final muted = isMine
        ? AppPalette.onAccent.withValues(alpha: 0.8)
        : AppPalette.textSecondary;

    return GestureDetector(
      onTap: onOpenReply,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: bar, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              replyAuthor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: bar,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              reply.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 13, height: 1.25),
            ),
          ],
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
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: image,
        ),
      ),
    );
  }

  Widget _buildMeta() {
    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatClock(message.createdAt),
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 11),
          ),
          if (isMine && _sending)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.schedule_rounded,
                size: 11,
                color: AppPalette.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStudyActions() {
    Widget action(String label, VoidCallback? onPressed) => InkWell(
      onTap: onPressed,
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
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
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
}
