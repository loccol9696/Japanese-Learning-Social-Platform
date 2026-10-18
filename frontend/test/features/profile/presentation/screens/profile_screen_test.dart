import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization/app_language.dart';
import 'package:frontend/core/localization/locale_manager.dart';
import 'package:frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:frontend/features/profile/presentation/widgets/profile_video_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpProfile(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pump(const Duration(milliseconds: 500));
  }

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

  testWidgets('sửa hồ sơ cập nhật tên hiển thị, bỏ qua tên rỗng', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Sửa hồ sơ'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).first, '  Tên Mới  ');
    await tester.tap(find.text('Lưu'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tên Mới'), findsOneWidget);
    expect(find.text('Đã cập nhật hồ sơ thành công'), findsOneWidget);

    await tester.tap(find.text('Sửa hồ sơ'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.tap(find.text('Lưu'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tên Mới'), findsOneWidget);
  });
}
