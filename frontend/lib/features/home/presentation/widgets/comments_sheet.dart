import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/data/auth_session.dart';
import '../../../follow/presentation/screens/user_profile_screen.dart';
import '../../../report/report_service.dart';
import '../../../report/report_sheet.dart';
import '../../data/models/video_comment.dart';
import '../../data/services/comment_service.dart';
import 'comment_like_button.dart';
import 'comment_options_sheet.dart';
import 'comment_sort_bar.dart';
import 'ruby_subtitle_widget.dart';

Future<void> showCommentsSheet(
  BuildContext context, {
  required String videoId,
  required int initialCount,
  int? videoOwnerId,
  int? highlightCommentId,
}) {
  // Popup tra từ/flashcard dùng OverlayEntry nên phải đóng trước khi mở
  // bottom sheet, nếu không nó sẽ tiếp tục nổi phía trên phần bình luận.
  RubySubtitleWidget.dismissLookups();
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CommentsSheet(
      videoId: videoId,
      initialCount: initialCount,
      videoOwnerId: videoOwnerId,
      highlightCommentId: highlightCommentId,
    ),
  );
}

class _CommentsSheet extends StatefulWidget {
  final String videoId;
  final int initialCount;

  /// Chủ video: chỉ người này mới ghim và thả tim được bình luận.
  final int? videoOwnerId;

  /// Bình luận (gốc hoặc phản hồi) cần cuộn tới và tô nổi khi mở, ví dụ từ thông báo "bình luận được thích".
  final int? highlightCommentId;

  const _CommentsSheet({
    required this.videoId,
    required this.initialCount,
    this.videoOwnerId,
    this.highlightCommentId,
  });

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
  CommentSort _sort = CommentSort.helpful;

  /// Bình luận đang được tô nổi; tự tắt sau [_highlightDuration].
  int? _highlightId;
  static const Duration _highlightDuration = Duration(seconds: 3);
  final _scrollController = ScrollController();
  final _highlightKey = GlobalKey();
  Timer? _highlightTimer;
  bool _highlightRevealed = false;

  /// Lần tải mới nhất; kết quả của các lần cũ hơn bị bỏ qua khi đổi sort liên tiếp.
  int _loadId = 0;

  /// Bình luận đang chờ backend xác nhận lượt đánh giá.
  final Set<int> _likesInFlight = {};

  /// Id các bình luận gốc đang mở danh sách phản hồi; mặc định phản hồi được ẩn.
  final Set<int> _expandedThreads = {};

  /// Tổng số bình luận bao gồm cả reply lồng nhau.
  int get _totalCommentCount =>
      _comments.fold(0, (sum, c) => sum + 1 + c.replies.length);

  @override
  void initState() {
    super.initState();
    _highlightId = widget.highlightCommentId;
    _load();
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loadId = ++_loadId;
    try {
      final comments = await _service.fetchComments(
        widget.videoId,
        sort: _sort,
      );
      if (mounted && loadId == _loadId) {
        setState(() {
          _comments = comments;
          _error = null;
        });
        _revealHighlight();
      }
    } catch (error) {
      if (mounted && loadId == _loadId) setState(() => _error = '$error');
    } finally {
      if (mounted && loadId == _loadId) setState(() => _loading = false);
    }
  }

  /// Cuộn tới bình luận cần tô nổi, một lần sau lần tải đầu tiên có bình luận đó.
  void _revealHighlight() {
    final id = _highlightId;
    if (id == null || _highlightRevealed) return;
    final exists = _comments.any(
      (c) => c.id == id || c.replies.any((r) => r.id == id),
    );
    if (!exists) {
      // Đã bị xóa hoặc bị ẩn (chặn): không có gì để tô nổi.
      setState(() => _highlightId = null);
      return;
    }
    _highlightRevealed = true;
    // Phản hồi đang bị ẩn thì mở luồng của nó ra để có chỗ cuộn tới.
    for (final comment in _comments) {
      if (comment.replies.any((r) => r.id == id)) {
        setState(() => _expandedThreads.add(comment.id));
      }
    }
    _highlightTimer = Timer(_highlightDuration, () {
      if (mounted) setState(() => _highlightId = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _highlightKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.15,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _changeSort(CommentSort sort) {
    setState(() => _sort = sort);
    _load();
  }

  bool _isOwnComment(VideoComment comment) =>
      AuthSession.instance.user?.id == comment.userId;

  bool get _isVideoOwner {
    final me = AuthSession.instance.user?.id;
    return me != null && me == widget.videoOwnerId;
  }

  void _updateComment(int id, VideoComment Function(VideoComment) update) {
    VideoComment apply(VideoComment comment) {
      if (comment.id == id) return update(comment);
      return comment.copyWith(replies: comment.replies.map(apply).toList());
    }

    setState(() => _comments = _comments.map(apply).toList());
  }

  /// Cập nhật ngay trên màn hình rồi lấy số thật từ backend. Danh sách không đổi
  /// thứ tự tại đây để bình luận không nhảy khỏi vị trí người dùng vừa nhấn.
  Future<void> _toggleLike(VideoComment comment) async {
    if (_likesInFlight.contains(comment.id)) return;
    final wasGuest = !AuthSession.instance.isAuthenticated;
    if (!await requireAuthentication(
      context,
      message: 'Vui lòng đăng nhập để đánh giá bình luận.',
    )) {
      return;
    }
    if (!mounted || _isOwnComment(comment)) return;

    final liked = !comment.isLiked;
    _likesInFlight.add(comment.id);
    _updateComment(
      comment.id,
      (current) => current.copyWith(
        isLiked: liked,
        likeCount: liked ? current.likeCount + 1 : current.likeCount - 1,
      ),
    );
    try {
      final result = liked
          ? await _service.likeComment(widget.videoId, comment.id)
          : await _service.unlikeComment(widget.videoId, comment.id);
      if (!mounted) return;
      _updateComment(
        comment.id,
        (current) => current.copyWith(
          isLiked: result.isLiked,
          likeCount: result.likeCount,
        ),
      );
      // Danh sách được tải khi còn là khách nên chưa biết các lượt đánh giá trước đó.
      if (wasGuest) await _load();
    } catch (error) {
      if (!mounted) return;
      _updateComment(
        comment.id,
        (current) => current.copyWith(
          isLiked: comment.isLiked,
          likeCount: comment.likeCount,
        ),
      );
      AppToast.showError(
        'Không thể cập nhật đánh giá: $error',
        context: context,
      );
    } finally {
      _likesInFlight.remove(comment.id);
    }
  }

  /// Ghim đổi thứ tự (bình luận được ghim lên đầu, bình luận ghim cũ bị bỏ) nên tải lại danh sách.
  Future<void> _togglePin(VideoComment comment) async {
    try {
      if (comment.pinned) {
        await _service.unpinComment(widget.videoId, comment.id);
      } else {
        await _service.pinComment(widget.videoId, comment.id);
      }
      if (mounted) await _load();
    } catch (error) {
      if (!mounted) return;
      AppToast.showError('Không thể ghim bình luận: $error', context: context);
    }
  }

  /// Nhấn giữ một bình luận: menu Trả lời / Sao chép / Ghim / Báo cáo / Xóa theo quyền của người đang xem.
  Future<void> _showCommentMenu(
    VideoComment comment, {
    required bool isReply,
  }) async {
    final option = await showCommentOptionsSheet(
      context,
      canPin: _isVideoOwner && !isReply,
      pinned: comment.pinned,
      canReport: !_isOwnComment(comment),
      canDelete: _canDelete(comment),
      pinLabel: appStrings.commentPin,
      unpinLabel: appStrings.commentUnpin,
    );
    if (option == null || !mounted) return;
    switch (option) {
      case CommentOption.reply:
        _startReply(comment);
      case CommentOption.copy:
        await Clipboard.setData(ClipboardData(text: comment.content));
        if (mounted) AppToast.showSuccess('Đã sao chép', context: context);
      case CommentOption.pin:
        await _togglePin(comment);
      case CommentOption.report:
        await showReportSheet(
          context,
          target: ReportTarget.comment,
          targetId: comment.id,
          subject: 'bình luận này',
        );
      case CommentOption.delete:
        await _deleteComment(comment);
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
          // Mở luồng để người dùng thấy ngay phản hồi vừa đăng.
          _expandedThreads.add(comment.parentId!);
          _load();
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        AppToast.showError(
          'Không thể đăng bình luận: $error',
          context: context,
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
              CommentSortBar(selected: _sort, onChanged: _changeSort),
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
    final thread = _buildThread;

    // Cuộn tới một bình luận cần widget của nó đã được dựng; ListView.builder chỉ dựng phần đang hiện nên khi
    // mở từ thông báo dùng danh sách dựng đủ (danh sách vốn đã tải đủ một lần, không phân trang).
    if (widget.highlightCommentId != null) {
      return SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final comment in _comments) thread(comment)],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: _comments.length,
      itemBuilder: (_, index) => thread(_comments[index]),
    );
  }

  /// Bình luận gốc kèm phản hồi: phản hồi chỉ hiện khi bấm "Xem N câu trả lời" và có nút "Ẩn" để thu lại.
  Widget _buildThread(VideoComment comment) {
    final replyCount = comment.replies.length;
    final expanded = _expandedThreads.contains(comment.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildComment(comment, isReply: false),
        if (replyCount > 0 && expanded) ...[
          for (final reply in comment.replies)
            _buildComment(reply, isReply: true),
          _repliesToggle(
            'Ẩn',
            Icons.keyboard_arrow_up_rounded,
            () => setState(() => _expandedThreads.remove(comment.id)),
          ),
        ] else if (replyCount > 0)
          _repliesToggle(
            'Xem $replyCount câu trả lời',
            Icons.keyboard_arrow_down_rounded,
            () => setState(() => _expandedThreads.add(comment.id)),
          ),
      ],
    );
  }

  /// Dòng "—— Xem N câu trả lời ⌄" thẳng hàng với nội dung bình luận gốc.
  Widget _repliesToggle(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16 + _replyIndent, 4, 16, 8),
        child: Row(
          children: [
            Container(width: 24, height: 1, color: AppPalette.border),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 2),
            Icon(icon, size: 18, color: AppPalette.textSecondary),
          ],
        ),
      ),
    );
  }

  /// Một dòng bình luận; dòng đang được trả lời được tô nền nổi bật trải hết chiều ngang.
  Widget _buildComment(VideoComment comment, {required bool isReply}) {
    final name = _displayName(comment);
    final isHighlightTarget = _highlightId == comment.id;
    final highlighted = _replyTarget?.id == comment.id || isHighlightTarget;
    final avatarRadius = isReply ? 14.0 : 18.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showCommentMenu(comment, isReply: isReply),
      child: Container(
        key: isHighlightTarget ? _highlightKey : null,
        color: highlighted ? AppPalette.accentSoft : null,
        padding: EdgeInsets.fromLTRB(
          16 + (isReply ? _replyIndent : 0),
          8,
          16,
          8,
        ),
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
                              if (isReply &&
                                  (comment.replyToName ?? '').isNotEmpty)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: comment.replyToUserId == null
                                        ? null
                                        : () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    UserProfileScreen(
                                                      userId: comment
                                                          .replyToUserId!,
                                                      initialName:
                                                          comment.replyToName,
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
                    ],
                  ),
                  if (comment.pinned) ...[
                    const SizedBox(height: 2),
                    _badge(Icons.push_pin_rounded, appStrings.commentPinned),
                  ],
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
                  // Như TikTok: thời gian rồi "Trả lời" cùng một dòng dưới nội dung.
                  Row(
                    children: [
                      Text(
                        _timeAgo(comment.createdAt),
                        style: TextStyle(
                          color: AppPalette.textSecondary.withValues(
                            alpha: 0.8,
                          ),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _actionButton('Trả lời', () => _startReply(comment)),
                    ],
                  ),
                ],
              ),
            ),
            // Nút "Hữu ích" nằm bên phải dòng bình luận.
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: CommentLikeButton(
                likeCount: comment.likeCount,
                isLiked: comment.isLiked,
                onTap: _isOwnComment(comment)
                    ? null
                    : () => _toggleLike(comment),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String label, {Color? color}) {
    final tint = color ?? AppPalette.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: tint),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: tint,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: AppPalette.textSecondary,
                    ),
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
