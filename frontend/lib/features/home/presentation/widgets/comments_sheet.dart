import 'package:flutter/material.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../auth/data/auth_session.dart';
import '../../data/models/video_comment.dart';
import '../../data/services/comment_service.dart';
import '../../../../core/theme/app_palette.dart';

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
  final _service = CommentService();
  final _controller = TextEditingController();
  List<VideoComment> _comments = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  int? _replyTo;

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
      final comment = await _service.createComment(
        widget.videoId,
        content,
        parentId: _replyTo,
      );
      if (!mounted) return;
      setState(() {
        _controller.clear();
        _replyTo = null;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể đăng bình luận: $error')),
        );
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
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể xóa bình luận: $error')),
      );
    }
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      itemCount: _comments.length,
      itemBuilder: (_, index) => _buildComment(_comments[index], false),
    );
  }

  Widget _buildComment(VideoComment comment, bool isReply) {
    final name = comment.displayName.isNotEmpty
        ? comment.displayName
        : comment.username;
    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 38 : 0,
        top: isReply ? 6 : 0,
        bottom: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
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
                          fontSize: 14,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comment.content,
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              setState(() => _replyTo = comment.id),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Trả lời',
                            style: TextStyle(
                              color: AppPalette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (_canDelete(comment)) ...[
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => _deleteComment(comment),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Xóa',
                              style: TextStyle(
                                color: AppPalette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (final reply in comment.replies) _buildComment(reply, true),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              style: TextStyle(color: AppPalette.textPrimary),
              decoration: InputDecoration(
                hintText: _replyTo == null
                    ? 'Thêm bình luận hoặc câu hỏi...'
                    : 'Đang trả lời bình luận',
                hintStyle: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppPalette.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppPalette.accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppPalette.accent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
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
                      color: AppPalette.textPrimary,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
