import 'package:flutter/material.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_session.dart';
import '../../data/models/video_comment.dart';
import '../../data/services/comment_service.dart';

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
          decoration: const BoxDecoration(
            color: Color(0xFF17181C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 28,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
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
                          '${_comments.length} bình luận',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
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
        child: Text(_error!, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (_comments.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có bình luận. Hãy là người đầu tiên!',
          style: TextStyle(color: Colors.white60),
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
                radius: 16,
                backgroundColor: AppColors.primary,
                backgroundImage: comment.avatarUrl.isNotEmpty
                    ? NetworkImage(comment.avatarUrl)
                    : null,
                child: comment.avatarUrl.isEmpty
                    ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${comment.username}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      comment.content,
                      style: const TextStyle(color: Colors.white, height: 1.3),
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
                          child: const Text(
                            'Trả lời',
                            style: TextStyle(
                              color: Colors.white54,
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
                            child: const Text(
                              'Xóa',
                              style: TextStyle(
                                color: Colors.white54,
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
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _replyTo == null
                    ? 'Thêm bình luận hoặc câu hỏi...'
                    : 'Đang trả lời bình luận',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
