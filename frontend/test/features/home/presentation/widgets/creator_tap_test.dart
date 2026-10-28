import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/domain/models/video_post.dart';
import 'package:frontend/features/home/presentation/widgets/interaction_sidebar.dart';
import 'package:frontend/features/home/presentation/widgets/video_info_overlay.dart';

const _post = VideoPost(
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
  rubySegments: [],
  translation: '',
  likeCount: 0,
  commentCount: 0,
  shareCount: 0,
);

void main() {
  infoOverlayLayoutTests();

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

void infoOverlayLayoutTests() {
  testWidgets('thông tin video: @username dòng trên, tên video kèm huy hiệu JLPT ở dòng dưới', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: VideoInfoOverlay(post: _post))),
    );

    final creator = tester.getTopLeft(find.text('@bob'));
    final title = tester.getTopLeft(find.text('Chủ đề'));
    final badge = tester.getTopLeft(find.text('N3'));
    expect(title.dy, greaterThan(creator.dy));
    expect((badge.dy - title.dy).abs(), lessThan(8)); // cùng một hàng
    expect(badge.dx, greaterThan(title.dx));
    expect(find.byIcon(Icons.smart_display_outlined), findsNothing);
  });
}
