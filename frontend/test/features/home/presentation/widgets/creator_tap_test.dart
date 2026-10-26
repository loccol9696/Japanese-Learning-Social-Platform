import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/domain/models/video_post.dart';
import 'package:frontend/features/home/presentation/widgets/interaction_sidebar.dart';
import 'package:frontend/features/home/presentation/widgets/video_info_overlay.dart';

const _post = VideoPost(
  id: '1',
  backgroundImageUrl: '',
  creatorName: 'Bob',
  creatorTag: '@bob',
  creatorAvatarUrl: '',
  accentInfo: '',
  jlptLevel: 'N3',
  topicTag: 'Chủ đề',
  audioTitle: '',
  audioDiscImageUrl: '',
  rubySegments: [],
  translation: '',
  likeCount: 0,
  commentCount: 0,
  shareCount: 0,
);

void main() {
  testWidgets('bấm @username của người đăng gọi onCreatorTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoInfoOverlay(post: _post, onCreatorTap: () => taps++),
        ),
      ),
    );

    await tester.tap(find.text('@bob'));

    expect(taps, 1);
  });

  testWidgets('bấm avatar mở trang cá nhân, còn dấu + chỉ theo dõi', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var creatorTaps = 0;
    var followTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractionSidebar(
              post: _post,
              allowAccountActions: false,
              onCreatorTap: () => creatorTaps++,
              onFollowToggle: () => followTaps++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ClipOval));
    expect((creatorTaps, followTaps), (1, 0));

    await tester.tap(find.byIcon(Icons.add_rounded));
    expect((creatorTaps, followTaps), (1, 1));
  });
}
