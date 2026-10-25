import 'package:flutter/material.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../auth/data/auth_session.dart';
import '../../../home/data/datasources/home_remote_datasource.dart';
import '../../../home/domain/models/video_post.dart';
import '../../../home/presentation/widgets/video_player_item.dart';

/// Xem các video của một người dùng, vuốt dọc để chuyển video, bắt đầu từ video được chọn.
class UserVideoViewerScreen extends StatefulWidget {
  final List<VideoPost> posts;
  final int initialIndex;

  const UserVideoViewerScreen({super.key, required this.posts, this.initialIndex = 0});

  @override
  State<UserVideoViewerScreen> createState() => _UserVideoViewerScreenState();
}

class _UserVideoViewerScreenState extends State<UserVideoViewerScreen> {
  final HomeRemoteDataSourceImpl _dataSource = HomeRemoteDataSourceImpl();
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late List<VideoPost> _posts = List.of(widget.posts);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _ensureLoggedIn(String message) async {
    if (AuthSession.instance.isAuthenticated) return true;
    return requireAuthentication(context, message: message);
  }

  Future<void> _toggleLike(VideoPost post) async {
    if (!await _ensureLoggedIn('Vui lòng đăng nhập để thả tim video này.')) return;
    try {
      final liked = await _dataSource.toggleLike(post.id);
      _replace(post.id, (p) => p.copyWith(isLiked: liked));
    } catch (_) {}
  }

  Future<void> _toggleSave(VideoPost post) async {
    if (!await _ensureLoggedIn('Vui lòng đăng nhập để lưu video này.')) return;
    try {
      final saved = await _dataSource.toggleSave(post.id);
      _replace(post.id, (p) => p.copyWith(isSaved: saved));
    } catch (_) {}
  }

  void _replace(String id, VideoPost Function(VideoPost) update) {
    if (!mounted) return;
    setState(() {
      _posts = [for (final p in _posts) p.id == id ? update(p) : p];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            scrollDirection: Axis.vertical,
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              final post = _posts[index];
              return VideoPlayerItem(
                key: ValueKey(post.id),
                post: post,
                onLikeToggle: () => _toggleLike(post),
                onSaveToggle: () => _toggleSave(post),
                allowAccountActions: AuthSession.instance.isAuthenticated,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 4, top: 4),
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppPalette.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
