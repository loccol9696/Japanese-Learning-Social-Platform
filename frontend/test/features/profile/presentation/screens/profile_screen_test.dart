import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_language.dart';
import 'package:frontend/core/localization/locale_manager.dart';
import 'package:frontend/features/profile/domain/models/topic_model.dart';
import 'package:frontend/features/profile/domain/models/user_profile_model.dart';
import 'package:frontend/features/profile/domain/repositories/profile_repository.dart';
import 'package:frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:frontend/features/profile/presentation/screens/profile_update_screen.dart';
import 'package:frontend/features/profile/presentation/widgets/profile_video_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repository giả: trả về hồ sơ hiện tại, đếm số lần nạp.
class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(this.profile);

  UserProfileModel profile;
  int loads = 0;

  @override
  Future<UserProfileModel> getProfile() async {
    loads++;
    return profile;
  }

  @override
  Future<UserProfileModel> updateProfile(UserProfileModel p) async => profile = p;

  @override
  Future<List<TopicModel>> getTopics() async => const [];
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
    repository = _FakeProfileRepository(_alice);
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
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('hiển thị hồ sơ thật từ repository (tên, username, trình độ)', (tester) async {
    await pumpProfile(tester);

    expect(find.text('Alice Tanaka'), findsOneWidget);
    expect(find.text('@alice'), findsOneWidget);
    expect(find.text('JLPT N2'), findsOneWidget);
  });

  testWidgets('3 tab: video, đã lưu (bookmark), đã thích; không còn Bản nháp',
      (tester) async {
    await pumpProfile(tester);

    expect(find.byType(Tab), findsNWidgets(3));
    expect(find.widgetWithIcon(Tab, Icons.grid_on_rounded), findsOneWidget);
    expect(find.widgetWithIcon(Tab, Icons.bookmark_rounded), findsOneWidget);
    expect(find.widgetWithIcon(Tab, Icons.favorite_rounded), findsOneWidget);
    expect(find.textContaining('Bản nháp'), findsNothing);
  });

  testWidgets('video ghim đứng đầu lưới và có badge Đã ghim', (tester) async {
    await pumpProfile(tester);

    final tiles = tester.widgetList<ProfileVideoTile>(find.byType(ProfileVideoTile));
    expect(tiles.first.video['isPinned'], isTrue);
    expect(find.byType(PinnedBadge), findsOneWidget);
    expect(
      find.descendant(
          of: find.byWidget(tiles.first), matching: find.byType(PinnedBadge)),
      findsOneWidget,
    );
  });

  testWidgets('tab đã lưu hiển thị lưới video đã lưu', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.byIcon(Icons.bookmark_rounded));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final tiles = tester.widgetList<ProfileVideoTile>(find.byType(ProfileVideoTile));
    expect(tiles.map((t) => t.snackPrefix).toSet(), {'Video đã lưu'});
    expect(tiles.first.video['id'], 'save_01');
  });

  group('đa ngôn ngữ', () {
    tearDown(() => localeManager.changeLanguage(AppLanguage.vi));

    testWidgets('tiếng Anh: nút, thống kê và sheet cài đặt theo ngôn ngữ', (tester) async {
      localeManager.changeLanguage(AppLanguage.en);
      await pumpProfile(tester);

      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('7-day streak'), findsOneWidget);
      expect(find.text('Sửa hồ sơ'), findsNothing);

      await tester.tap(find.byTooltip('Settings and privacy'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('App language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget); // ngôn ngữ hiện tại
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('tiếng Nhật: nút sửa hồ sơ và badge ghim', (tester) async {
      localeManager.changeLanguage(AppLanguage.ja);
      await pumpProfile(tester);

      expect(find.text('プロフィールを編集'), findsOneWidget);
      expect(find.text('固定済み'), findsOneWidget); // badge video ghim
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
}
