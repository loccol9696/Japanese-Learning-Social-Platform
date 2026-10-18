import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_language.dart';
import 'package:frontend/core/localization/locale_manager.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/profile/domain/models/profile_video.dart';
import 'package:frontend/features/profile/domain/models/topic_model.dart';
import 'package:frontend/features/profile/domain/models/user_profile_model.dart';
import 'package:frontend/features/profile/domain/repositories/profile_repository.dart';
import 'package:frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:frontend/features/profile/presentation/screens/profile_update_screen.dart';
import 'package:frontend/features/profile/presentation/screens/profile_video_player_screen.dart';
import 'package:frontend/features/profile/presentation/widgets/profile_video_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository giả: dữ liệu cấu hình được, đếm số lần nạp, có thể ném lỗi.
class _FakeProfileRepository implements ProfileRepository {
  UserProfileModel profile = _alice;
  ProfileStats stats = const ProfileStats(followingCount: 9778, followerCount: 170, likeCount: 15234);
  List<ProfileVideo> myVideos = const [
    ProfileVideo(id: 1, title: 'Kính ngữ N3', viewCount: 1203, jlptLevel: 'N3', modStatus: 'APPROVED'),
    ProfileVideo(id: 2, title: 'Trợ từ は và が', modStatus: 'PENDING'),
    ProfileVideo(id: 3, title: 'Video vi phạm', modStatus: 'REJECTED', rejectionReason: 'Sai nội dung'),
  ];
  List<ProfileVideo> saved = const [];
  List<ProfileVideo> liked = const [ProfileVideo(id: 7, title: 'Anime slang', likeCount: 152000)];
  Object? likedError;
  int loads = 0;
  int likedLoads = 0;

  @override
  Future<UserProfileModel> getProfile() async {
    loads++;
    return profile;
  }

  @override
  Future<UserProfileModel> updateProfile(UserProfileModel p) async => profile = p;

  @override
  Future<List<TopicModel>> getTopics() async => const [];

  @override
  Future<ProfileStats> getStats() async => stats;

  @override
  Future<List<ProfileVideo>> getMyVideos() async => myVideos;

  @override
  Future<List<ProfileVideo>> getSavedVideos() async => saved;

  @override
  Future<List<ProfileVideo>> getLikedVideos() async {
    likedLoads++;
    final error = likedError;
    if (error != null) throw error;
    return liked;
  }
}

const _alice = UserProfileModel(
  id: 42,
  username: 'alice',
  displayName: 'Alice Tanaka',
  currentLevel: 'N2',
);

void main() {
  late _FakeProfileRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = _FakeProfileRepository();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(repository: repository)));
    await settle(tester);
  }

  Future<void> openTab(WidgetTester tester, IconData icon) async {
    await tester.tap(find.widgetWithIcon(Tab, icon));
    await settle(tester);
  }

  testWidgets('hồ sơ và thống kê lấy từ repository, số được định dạng', (tester) async {
    await pumpProfile(tester);

    expect(find.text('Alice Tanaka'), findsOneWidget);
    expect(find.text('@alice'), findsOneWidget);
    expect(find.text('JLPT N2'), findsOneWidget);
    expect(find.text('9.778'), findsOneWidget);
    expect(find.text('170'), findsOneWidget);
    expect(find.text('15,2K'), findsOneWidget);
    // Backend chưa có chuỗi ngày học -> không hiện số giả
    expect(find.textContaining('ngày học'), findsNothing);
  });

  testWidgets('3 tab: video, đã lưu (bookmark), đã thích', (tester) async {
    await pumpProfile(tester);

    expect(find.byType(Tab), findsNWidgets(3));
    expect(find.widgetWithIcon(Tab, Icons.grid_on_rounded), findsOneWidget);
    expect(find.widgetWithIcon(Tab, Icons.bookmark_rounded), findsOneWidget);
    expect(find.widgetWithIcon(Tab, Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('tab video: video của mình kèm badge trạng thái duyệt', (tester) async {
    await pumpProfile(tester);

    final tiles = tester.widgetList<ProfileVideoTile>(find.byType(ProfileVideoTile)).toList();
    expect(tiles.map((t) => t.video.id), [1, 2, 3]);
    expect(find.text('1.203'), findsOneWidget); // lượt xem
    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(find.text('Bị từ chối'), findsOneWidget);
    expect(find.byTooltip('Sai nội dung'), findsOneWidget); // lý do từ chối
    expect(find.byType(ModStatusBadge), findsNWidgets(2)); // video đã duyệt không có badge
  });

  testWidgets('tab đã lưu rỗng hiển thị trạng thái trống', (tester) async {
    await pumpProfile(tester);
    await openTab(tester, Icons.bookmark_rounded);

    expect(find.text('Chưa có video đã lưu'), findsOneWidget);
    expect(find.byType(ProfileVideoTile), findsNothing);
  });

  testWidgets('tab đã thích lỗi -> báo lỗi, "Thử lại" tải lại thành công', (tester) async {
    repository.likedError = ApiException(statusCode: 500, message: 'Máy chủ lỗi');
    await pumpProfile(tester);
    await openTab(tester, Icons.favorite_rounded);

    expect(find.text('Không tải được dữ liệu'), findsOneWidget);
    expect(find.text('Máy chủ lỗi'), findsOneWidget);

    repository.likedError = null;
    await tester.tap(find.text('Thử lại'));
    await settle(tester);

    expect(repository.likedLoads, 2);
    expect(find.text('Không tải được dữ liệu'), findsNothing);
    expect(find.text('152K'), findsOneWidget); // lượt thích của video đã thích
  });

  testWidgets('bấm vào video mở trình phát tại đúng video', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.byType(ProfileVideoTile).at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final player = tester.widget<ProfileVideoPlayerScreen>(find.byType(ProfileVideoPlayerScreen));
    expect(player.initialIndex, 1);
    expect(player.videos.map((v) => v.id), [1, 2, 3]);
  });

  group('đa ngôn ngữ', () {
    tearDown(() => localeManager.changeLanguage(AppLanguage.vi));

    testWidgets('tiếng Anh: nút, thống kê và sheet cài đặt theo ngôn ngữ', (tester) async {
      localeManager.changeLanguage(AppLanguage.en);
      await pumpProfile(tester);

      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Sửa hồ sơ'), findsNothing);

      await tester.tap(find.byTooltip('Settings and privacy'));
      await settle(tester);
      expect(find.text('App language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget); // ngôn ngữ hiện tại
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('tiếng Nhật: nút sửa hồ sơ và badge trạng thái', (tester) async {
      localeManager.changeLanguage(AppLanguage.ja);
      await pumpProfile(tester);

      expect(find.text('プロフィールを編集'), findsOneWidget);
      expect(find.text('審査中'), findsOneWidget);
    });
  });

  testWidgets('"Sửa hồ sơ" mở ProfileUpdateScreen và nạp lại hồ sơ khi quay về', (tester) async {
    await pumpProfile(tester);
    expect(repository.loads, 1);

    await tester.tap(find.text('Sửa hồ sơ'));
    await settle(tester);
    expect(find.byType(ProfileUpdateScreen), findsOneWidget);

    repository.profile = _alice.copyWith(displayName: 'Alice Mới');
    Navigator.of(tester.element(find.byType(ProfileUpdateScreen))).pop();
    await settle(tester);

    expect(repository.loads, greaterThanOrEqualTo(2));
    expect(find.text('Alice Mới'), findsOneWidget);
  });

  test('formatCount', () {
    expect(formatCount(0), '0');
    expect(formatCount(170), '170');
    expect(formatCount(9778), '9.778');
    expect(formatCount(15234), '15,2K');
    expect(formatCount(152000), '152K');
    expect(formatCount(1300000), '1,3M');
  });
}
