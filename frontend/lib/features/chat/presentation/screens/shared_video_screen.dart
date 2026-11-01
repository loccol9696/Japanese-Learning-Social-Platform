import 'package:flutter/material.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/data/auth_session.dart';
import '../../../home/data/datasources/home_remote_datasource.dart';
import '../../../home/domain/models/video_post.dart';
import '../../../home/presentation/widgets/comments_sheet.dart';
import '../../../home/presentation/widgets/video_player_item.dart';

/// Mở một video được bạn bè chia sẻ trong chat, bắt đầu từ [startMs] (nếu có).
/// [openComments] tự mở khung bình luận ngay khi video tải xong (từ thông báo về bình luận);
/// [highlightCommentId] cuộn tới và tô nổi bình luận đó trong khung.
class SharedVideoScreen extends StatefulWidget {
  final int videoId;
  final int? startMs;
  final bool openComments;
  final int? highlightCommentId;

  const SharedVideoScreen({
    super.key,
    required this.videoId,
    this.startMs,
    this.openComments = false,
    this.highlightCommentId,
  });

  @override
  State<SharedVideoScreen> createState() => _SharedVideoScreenState();
}

class _SharedVideoScreenState extends State<SharedVideoScreen> {
  final _dataSource = HomeRemoteDataSourceImpl();

  VideoPost? _post;
  bool _loading = true;
  String? _error;

  /// Khung bình luận tự mở tối đa một lần, kể cả khi người dùng bấm "Thử lại" tải video.
  bool _commentsAutoOpened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await ApiClient.instance.get(
        ApiConstants.videoDetailUrl('${widget.videoId}'),
      );
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Dữ liệu video không hợp lệ.');
      }
      if (mounted) {
        setState(() => _post = _dataSource.toVideoPost(json));
        if (widget.openComments && !_commentsAutoOpened) {
          _commentsAutoOpened = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openComments();
          });
        }
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.statusCode == 404 || error.statusCode == 403
              ? 'Video không còn khả dụng.'
              : error.message,
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openComments() {
    final post = _post;
    if (post == null) return;
    showCommentsSheet(
      context,
      videoId: post.id,
      videoOwnerId: post.creatorId,
      initialCount: post.commentCount,
      highlightCommentId: widget.highlightCommentId,
    );
  }

  void _update(VideoPost Function(VideoPost) change) {
    final post = _post;
    if (post != null) setState(() => _post = change(post));
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null || !await requireAuthentication(context)) return;
    final liked = !post.isLiked;
    _update(
      (p) => p.copyWith(
        isLiked: liked,
        likeCount: liked
            ? p.likeCount + 1
            : (p.likeCount > 0 ? p.likeCount - 1 : 0),
      ),
    );
    try {
      await _dataSource.setLiked(post.id, liked: liked);
    } catch (error) {
      _update((_) => post);
      if (mounted) {
        AppToast.showError(
          'Không thể cập nhật lượt thích: $error',
          context: context,
        );
      }
    }
  }

  Future<void> _toggleSave() async {
    final post = _post;
    if (post == null || !await requireAuthentication(context)) return;
    final saved = !post.isSaved;
    _update((p) => p.copyWith(isSaved: saved));
    try {
      await _dataSource.setSaved(post.id, saved: saved);
    } catch (error) {
      _update((_) => post);
      if (mounted) {
        AppToast.showError(
          'Không thể cập nhật video đã lưu: $error',
          context: context,
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    final post = _post;
    final creatorId = post?.creatorId;
    if (post == null ||
        creatorId == null ||
        !await requireAuthentication(context)) {
      return;
    }
    final follow = !post.isFollowing;
    _update((p) => p.copyWith(isFollowing: follow));
    try {
      final confirmed = await _dataSource.setFollow(creatorId, follow: follow);
      _update((p) => p.copyWith(isFollowing: confirmed));
    } catch (error) {
      _update((p) => p.copyWith(isFollowing: !follow));
      if (mounted) {
        AppToast.showError(
          'Không thể cập nhật theo dõi: $error',
          context: context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (post != null)
            VideoPlayerItem(
              key: ValueKey(post.id),
              post: post,
              // Màn này không có thanh menu dưới.
              reserveBottomBar: false,
              initialPosition: widget.startMs == null
                  ? null
                  : Duration(milliseconds: widget.startMs!),
              allowAccountActions: AuthSession.instance.isAuthenticated,
              onLikeToggle: _toggleLike,
              onSaveToggle: _toggleSave,
              onFollowToggle: _toggleFollow,
              // Đã theo dõi / bỏ theo dõi ngay trên trang cá nhân của người đăng.
              onCreatorFollowChanged: (following) {
                if (mounted) _update((p) => p.copyWith(isFollowing: following));
              },
              onCommentTap: _openComments,
              // Màn này chỉ có một video nên xóa xong thì quay lại màn trước.
              onDeleted: () {
                if (mounted) Navigator.of(context).maybePop();
              },
            )
          else if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            _buildError(),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: 'Quay lại',
                  style: IconButton.styleFrom(
                    backgroundColor: AppPalette.videoScrim.withValues(alpha: 0.38),
                    foregroundColor: AppPalette.onAccent,
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 48,
            color: AppPalette.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Không tải được video.',
            style: TextStyle(color: AppPalette.textSecondary),
          ),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}
