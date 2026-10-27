import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/domain/models/video_post.dart';
import 'package:frontend/features/home/presentation/widgets/bottom_nav_dock.dart';
import 'package:frontend/features/home/presentation/widgets/interaction_sidebar.dart';
import 'package:frontend/features/home/presentation/widgets/video_player_item.dart';

VideoPost _post() => VideoPost(
  id: '1',
  backgroundImageUrl: '',
  creatorId: 7,
  creatorName: 'Bob',
  creatorTag: '@bob',
  creatorAvatarUrl: '',
  accentInfo: '',
  jlptLevel: 'N3',
  topicTag: 'Chủ đề',
  audioTitle: '',
  audioDiscImageUrl: '',
  rubySegments: const [],
  translation: '',
  likeCount: 0,
  commentCount: 0,
  shareCount: 0,
);

void main() {
  testWidgets('cột tương tác neo sát đáy, không căn giữa theo chiều dọc', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 900,
          child: VideoPlayerItem(post: _post()),
        ),
      ),
    ));
    await tester.pump();

    final rect = tester.getRect(find.byType(InteractionSidebar));
    final expectedBottom = 900 - BottomNavDock.contentHeight - 28.0;

    expect(rect.bottom, closeTo(expectedBottom, 0.5));
    // Nếu bị căn giữa thì tâm cột sẽ ở khoảng giữa màn hình (450); neo đáy thì lệch hẳn xuống dưới.
    expect(rect.center.dy, greaterThan(900 / 2 + 20));
  });
}
