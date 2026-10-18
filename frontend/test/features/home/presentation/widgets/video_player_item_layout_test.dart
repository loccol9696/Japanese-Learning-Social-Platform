import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/domain/models/ruby_segment.dart';
import 'package:frontend/features/home/domain/models/video_post.dart';
import 'package:frontend/features/home/presentation/widgets/interaction_sidebar.dart';
import 'package:frontend/features/home/presentation/widgets/video_info_overlay.dart';
import 'package:frontend/features/home/presentation/widgets/video_player_item.dart';

const _post = VideoPost(
  id: '4',
  backgroundImageUrl: '',
  creatorName: 'Nguyễn Xài Chung',
  creatorTag: '@xaichung123',
  creatorAvatarUrl: '',
  accentInfo: '',
  jlptLevel: 'JLPT N3',
  topicTag: 'アニメ『うまゆる ふるげ～と！』第4話「ハロウィンのお支度！」',
  rubySegments: [RubySegment(kanji: 'スマイル プレゼント！', furigana: '')],
  translation: 'Tặng Smile!',
  likeCount: 1,
  commentCount: 0,
  shareCount: 0,
);

void main() {
  Future<void> pumpItem(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: VideoPlayerItem(post: _post))));
    await tester.pump();
  }

  testWidgets('khối thông tin dùng hết chiều ngang (không chừa chỗ cho cột nút)', (tester) async {
    await pumpItem(tester, const Size(412, 892));

    final info = tester.getRect(find.byType(VideoInfoOverlay));
    expect(info.left, 16.0);
    expect(info.right, 412.0 - 16.0);
  });

  testWidgets('cột nút căn giữa phía trên khối thông tin, không chồng lên nhau', (tester) async {
    for (final size in const [Size(412, 892), Size(360, 640)]) {
      await pumpItem(tester, size);

      final sidebar = tester.getRect(find.byType(InteractionSidebar));
      final info = tester.getRect(find.byType(VideoInfoOverlay));
      expect(sidebar.bottom, lessThanOrEqualTo(info.top), reason: 'màn $size');
      expect(sidebar.right, size.width - 12.0, reason: 'màn $size');
    }
  });
}
