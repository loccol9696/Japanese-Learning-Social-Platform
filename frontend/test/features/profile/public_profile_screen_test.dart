import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/home/domain/models/video_post.dart';
import 'package:frontend/features/profile/data/public_profile_service.dart';
import 'package:frontend/features/profile/domain/models/public_profile_model.dart';
import 'package:frontend/features/profile/presentation/screens/public_profile_screen.dart';

class _FakeService extends PublicProfileService {
  PublicProfile profile;
  List<VideoPost> videos;
  int followCalls = 0;

  _FakeService(this.profile, this.videos);

  @override
  Future<PublicProfile> getProfile(int userId) async => profile;

  @override
  Future<List<VideoPost>> getVideos(int userId) async => videos;

  @override
  Future<({bool following, int followersCount})> toggleFollow(int userId) async {
    followCalls++;
    return (following: true, followersCount: profile.followersCount + 1);
  }
}

VideoPost _post(String id, int views) => VideoPost(
  id: id,
  backgroundImageUrl: '',
  creatorName: 'Yuuka',
  creatorTag: '@yuukachan',
  creatorAvatarUrl: '',
  accentInfo: '',
  jlptLevel: 'JLPT N2',
  topicTag: 'Bài $id',
  audioTitle: '',
  audioDiscImageUrl: '',
  rubySegments: const [],
  translation: '',
  likeCount: 0,
  commentCount: 0,
  shareCount: views,
);

const _yuuka = PublicProfile(
  id: 2,
  username: 'yuukachan',
  displayName: 'Yuuka',
  jlptLevel: 'N2',
  followersCount: 1200,
  followingCount: 38,
  likesCount: 14000,
  videosCount: 3,
);

void main() {
  testWidgets('hiện tên, @username · cấp độ, số liệu rút gọn và lưới video', (tester) async {
    final service = _FakeService(_yuuka, [_post('1', 12000), _post('2', 8400), _post('3', 952)]);
    await tester.pumpWidget(MaterialApp(home: PublicProfileScreen(userId: 2, service: service)));
    await tester.pumpAndSettle();

    expect(find.text('Yuuka'), findsOneWidget);
    expect(find.text('@yuukachan · N2'), findsOneWidget);
    expect(find.textContaining('38'), findsWidgets);
    expect(find.textContaining('1,2K'), findsOneWidget);
    expect(find.textContaining('14K'), findsOneWidget);
    expect(find.text('12K'), findsOneWidget);
    expect(find.text('8,4K'), findsOneWidget);
    expect(find.text('952'), findsOneWidget);
    expect(find.text('Theo dõi'), findsOneWidget);
    expect(find.text('Nhắn tin'), findsOneWidget);
  });

  testWidgets('hồ sơ của chính mình không có nút Theo dõi / Nhắn tin', (tester) async {
    final self = PublicProfile.fromJson({
      'id': 2,
      'username': 'me',
      'displayName': 'Tôi',
      'self': true,
    });
    await tester.pumpWidget(MaterialApp(home: PublicProfileScreen(userId: 2, service: _FakeService(self, const []))));
    await tester.pumpAndSettle();

    expect(find.text('Theo dõi'), findsNothing);
    expect(find.text('Nhắn tin'), findsNothing);
    expect(find.text('Chưa có video nào'), findsOneWidget);
  });

  test('PublicProfile đọc cờ isFollowing / isSelf từ JSON', () {
    final p = PublicProfile.fromJson({'id': 1, 'username': 'a', 'following': true, 'self': false});
    expect(p.isFollowing, isTrue);
    expect(p.isSelf, isFalse);
    expect(p.copyWith(isFollowing: false, followersCount: 5).followersCount, 5);
  });
}
