import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../home/data/datasources/home_remote_datasource.dart';
import '../../../home/data/mappers/video_post_mapper.dart';
import '../../../home/data/repositories/home_repository_impl.dart';
import '../../../home/domain/models/video_post.dart';
import '../../../home/domain/repositories/home_repository.dart';
import '../../../home/presentation/widgets/video_player_item.dart';
import '../../domain/models/profile_video.dart';

/// Phát video từ lưới Profile: toàn màn hình, vuốt dọc qua các video cùng tab
/// (dùng lại trình phát của Home).
class ProfileVideoPlayerScreen extends StatefulWidget {
  final List<ProfileVideo> videos;
  final int initialIndex;
  final HomeRepository? repository;

  const ProfileVideoPlayerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
    this.repository,
  });

  @override
  State<ProfileVideoPlayerScreen> createState() =>
      _ProfileVideoPlayerScreenState();
}

class _ProfileVideoPlayerScreenState extends State<ProfileVideoPlayerScreen> {
  late final PageController _pageController;
  late final HomeRepository _repository;
  late final List<VideoPost> _posts;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _repository =
        widget.repository ??
        HomeRepositoryImpl(remoteDataSource: HomeRemoteDataSourceImpl());
    _posts = widget.videos.map((v) => videoPostFromJson(v.raw)).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _setLiked(String postId, bool liked) async {
    try {
      await _repository.setLiked(postId, liked);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              final post = _posts[index];
              return VideoPlayerItem(
                key: ValueKey(post.id),
                post: post,
                onLikeChanged: (liked) => _setLiked(post.id, liked),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
