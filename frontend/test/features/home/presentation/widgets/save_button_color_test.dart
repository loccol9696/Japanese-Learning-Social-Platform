import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_palette.dart';
import 'package:frontend/features/home/domain/models/video_post.dart';
import 'package:frontend/features/home/presentation/widgets/interaction_sidebar.dart';

VideoPost _post({required bool isSaved}) => VideoPost(
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
  isSaved: isSaved,
);

void main() {
  Future<void> pumpSidebar(
    WidgetTester tester, {
    required bool isSaved,
    VoidCallback? onSaveToggle,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InteractionSidebar(
              post: _post(isSaved: isSaved),
              onSaveToggle: onSaveToggle,
            ),
          ),
        ),
      ),
    );
  }

  Color? iconColor(WidgetTester tester, IconData icon) =>
      tester.widget<Icon>(find.byIcon(icon)).color;

  Color? labelColor(WidgetTester tester) =>
      tester.widget<Text>(find.text('Lưu')).style?.color;

  testWidgets('chưa lưu: biểu tượng viền và nhãn màu trắng như các nút khác', (tester) async {
    await pumpSidebar(tester, isSaved: false);

    expect(iconColor(tester, Icons.bookmark_border_rounded), AppPalette.onVideo);
    expect(labelColor(tester), AppPalette.onVideo);
  });

  testWidgets('đã lưu: biểu tượng đặc và nhãn màu vàng', (tester) async {
    await pumpSidebar(tester, isSaved: true);

    expect(iconColor(tester, Icons.bookmark_rounded), AppPalette.gold);
    expect(labelColor(tester), AppPalette.gold);
  });

  testWidgets('bấm Lưu chuyển sang màu vàng và báo lại cho video', (tester) async {
    var toggles = 0;
    await pumpSidebar(tester, isSaved: false, onSaveToggle: () => toggles++);

    await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
    await tester.pump();

    expect(toggles, 1);
    expect(iconColor(tester, Icons.bookmark_rounded), AppPalette.gold);
    expect(labelColor(tester), AppPalette.gold);
  });
}
