import 'package:flutter/material.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../auth/data/auth_session.dart';
import '../../../follow/presentation/screens/user_profile_screen.dart';
import '../../../report/report_service.dart';
import '../../../report/report_sheet.dart';
import '../../data/models/video_comment.dart';
import '../../data/services/comment_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';

Future<void> showCommentsSheet(
  BuildContext context, {
  required String videoId,
  required int initialCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _CommentsSheet(videoId: videoId, initialCount: initialCount),
  );
}

class _CommentsSheet extends StatefulWidget {
  final String videoId;
  final int initialCount;

  const _CommentsSheet({required this.videoId, required this.initialCount});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  /// Lề trái của phản hồi so với bình luận gốc.
  static const double _replyIndent = 46;

  final _service = CommentService();
  final _controller = TextEditingController();
  final _inputFocus = FocusNode();
  List<VideoComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  /// Bình luận đang được trả lời (được tô nổi bật và hiện ở thanh "Đang trả lời").
  VideoComment? _replyTarget;

  /// Tổng số bình luận bao gồm cả reply lồng nhau.
  int get _totalCommentCount =>
      _comments.fold(0, (sum, c) => sum + 1 + c.replies.length);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await _service.fetchComments(widget.videoId);
      if (mounted) setState(() => _comments = comments);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startReply(VideoComment comment) {
    setState(() => _replyTarget = comment);
    _inputFocus.requestFocus();
  }

  void _cancelReply() => setState(() => _replyTarget = null);

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    if (!await requireAuthentication(
      context,
      message: 'Vui lòng đăng nhập để bình luận video này.',
    )) {
      return;
    }

    setState(() => _sending = true);
    try {
      // Phản hồi luôn gắn vào bình luận gốc: máy chủ chỉ hiển thị một cấp trả lời.
      final target = _replyTarget;
      final comment = await _service.createComment(
        widget.videoId,
        content,
        parentId: target == null ? null : (target.parentId ?? target.id),
        replyToId: target?.id,
      );
      if (!mounted) return;
      setState(() {
        _controller.clear();
        _replyTarget = null;
        _sending = false;
        if (comment.parentId == null) {
          _comments = [comment, ..._comments];
        } else {
          _load();
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        AppToast.showError('Không thể đăng bình luận: $error', context: context);
      }
    }
  }

  bool _canDelete(VideoComment comment) {
    final user = AuthSession.instance.user;
    return user?.id == comment.userId || user?.role == 'ADMIN';
  }

  Future<void> _deleteComment(VideoComment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bình luận?'),
        content: const Text('Bình luận và các câu trả lời sẽ bị xóa.'),
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
    if (confirmed != true || !mounted) return;
    try {
      await _service.deleteComment(widget.videoId, comment.id);
      if (_replyTarget?.id == comment.id) _replyTarget = null;
      await _load();
    } catch (error) {
      if (!mounted) return;
      AppToast.showError('Không thể xóa bình luận: $error', context: context);
    }
  }

  static String _displayName(VideoComment comment) =>
      comment.displayName.isNotEmpty ? comment.displayName : comment.username;

  /// "Vừa xong", "5 phút trước", "2 giờ trước"... như ảnh mẫu.
  static String _timeAgo(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.72,
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppPalette.textPrimary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          '${_loading ? widget.initialCount : _totalCommentCount} bình luận',
                          style: TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: AppPalette.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody()),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: AppPalette.textSecondary)),
      );
    }
    if (_comments.isEmpty) {
      return Center(
        child: Text(
          'Chưa có bình luận. Hãy là người đầu tiên!',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: _comments.length,
      itemBuilder: (_, index) {
        final comment = _comments[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildComment(comment, isReply: false),
            for (final reply in comment.replies)
              _buildComment(reply, isReply: true),
          ],
        );
      },
    );
  }

  /// Một dòng bình luận; dòng đang được trả lời được tô nền nổi bật trải hết chiều ngang.
  Widget _buildComment(VideoComment comment, {required bool isReply}) {
    final name = _displayName(comment);
    final highlighted = _replyTarget?.id == comment.id;
    final avatarRadius = isReply ? 14.0 : 18.0;

    return Container(
      color: highlighted ? AppPalette.accentSoft : null,
      padding: EdgeInsets.fromLTRB(16 + (isReply ? _replyIndent : 0), 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UserProfileScreen(
                    userId: comment.userId,
                    initialName: name,
                  ),
                ),
              );
            },
            child: CircleAvatar(
              radius: avatarRadius,
              backgroundColor: AppPalette.surfaceHigh,
              backgroundImage: comment.avatarUrl.isNotEmpty
                  ? NetworkImage(comment.avatarUrl)
                  : null,
              child: comment.avatarUrl.isEmpty
                  ? Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: isReply ? 12 : 14,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => UserProfileScreen(
                                        userId: comment.userId,
                                        initialName: name,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    color: AppPalette.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            // Phản hồi: ghi rõ đang trả lời ai, để biết ai trả lời ai.
                            if (isReply && (comment.replyToName ?? '').isNotEmpty)
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: comment.replyToUserId == null
                                      ? null
                                      : () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => UserProfileScreen(
                                                userId: comment.replyToUserId!,
                                                initialName: comment.replyToName,
                                              ),
                                            ),
                                          );
                                        },
                                  child: Text(
                                    '  ▸  ${comment.replyToName}',
                                    style: TextStyle(
                                      color: AppPalette.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(
                        color: AppPalette.textSecondary.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _actionButton('Trả lời', () => _startReply(comment)),
                    if (AuthSession.instance.user?.id != comment.userId)
                      _actionButton(
                        'Báo cáo',
                        () => showReportSheet(
                          context,
                          target: ReportTarget.comment,
                          targetId: comment.id,
                          subject: 'bình luận này',
                        ),
                      ),
                    if (_canDelete(comment))
                      _actionButton('Xóa', () => _deleteComment(comment)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final target = _replyTarget;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (target != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Đang trả lời ',
                            style: TextStyle(color: AppPalette.textSecondary),
                          ),
                          TextSpan(
                            text: _displayName(target),
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hủy trả lời',
                    onPressed: _cancelReply,
                    icon: Icon(Icons.close, size: 20, color: AppPalette.textSecondary),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _inputFocus,
                    minLines: 1,
                    maxLines: 3,
                    style: TextStyle(color: AppPalette.textPrimary),
                    decoration: InputDecoration(
                      hintText: target == null
                          ? 'Thêm bình luận...'
                          : 'Thêm phản hồi...',
                      hintStyle: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: AppPalette.surfaceHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26),
                        borderSide: BorderSide(
                          color: AppPalette.accent.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppPalette.accent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    tooltip: 'Gửi',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppPalette.onAccent,
                            ),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: AppPalette.onAccent,
                            size: 22,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
