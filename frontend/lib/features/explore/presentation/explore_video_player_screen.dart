import 'package:flutter/material.dart';

import '../../home/domain/models/video_post.dart';
import '../../home/presentation/widgets/video_player_item.dart';

/// Phát 1 video được chọn từ màn Khám phá.
class ExploreVideoPlayerScreen extends StatelessWidget {
  final VideoPost post;

  const ExploreVideoPlayerScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: VideoPlayerItem(post: post)),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
