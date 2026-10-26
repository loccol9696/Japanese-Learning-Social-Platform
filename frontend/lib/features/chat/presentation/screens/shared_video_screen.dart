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
class SharedVideoScreen extends StatefulWidget {
  final int videoId;
  final int? startMs;

  const SharedVideoScreen({super.key, required this.videoId, this.startMs});

  @override
  State<SharedVideoScreen> createState() => _SharedVideoScreenState();
}

class _SharedVideoScreenState extends State<SharedVideoScreen> {
  final _dataSource = HomeRemoteDataSourceImpl();

  VideoPost? _post;
  bool _loading = true;
  String? _error;

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
      if (mounted) setState(() => _post = _dataSource.toVideoPost(json));
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
      await _dataSource.toggleLike(post.id);
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
    _update((p) => p.copyWith(isSaved: !p.isSaved));
    try {
      await _dataSource.toggleSave(post.id);
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
              onCommentTap: () => showCommentsSheet(
                context,
                videoId: post.id,
                initialCount: post.commentCount,
              ),
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
