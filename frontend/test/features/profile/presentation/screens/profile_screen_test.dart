import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/notification/notification_sheet.dart';
import 'package:frontend/core/localization/app_language.dart';
import 'package:frontend/core/localization/locale_manager.dart';
import 'package:frontend/features/profile/domain/models/topic_model.dart';
import 'package:frontend/features/profile/domain/models/user_profile_model.dart';
import 'package:frontend/features/profile/domain/repositories/profile_repository.dart';
import 'package:frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:frontend/features/profile/presentation/screens/profile_update_screen.dart';
import 'package:frontend/features/video/domain/models/user_video_model.dart';

class _MockProfileRepository implements ProfileRepository {
  UserProfileModel profile = const UserProfileModel(
    id: 1,
    username: 'yamada_san',
    displayName: 'Yamada Kenji',
    currentLevel: 'N3',
    bio: 'Học tiếng Nhật mỗi ngày',
    subscriptionPlanName: 'Gói VIP 1 Tháng',
    vipExpiresAt: '2026-12-31T23:59:59',
    followersCount: 120,
    followingCount: 45,
    likesCount: 950,
  );

  List<UserVideoModel> videos = [
    const UserVideoModel(
      id: 101,
      title: 'Ngữ pháp N3 - Bài 1',
      videoUrl: 'https://example.com/v1.mp4',
      status: 'PUBLIC',
      modStatus: 'APPROVED',
      viewCount: 1500,
    ),
    const UserVideoModel(
      id: 102,
      title: 'Ghi chú cá nhân',
      videoUrl: 'https://example.com/v2.mp4',
      status: 'PRIVATE',
      modStatus: 'APPROVED',
      viewCount: 10,
    ),
    const UserVideoModel(
      id: 103,
      title: 'Kanji nâng cao',
      videoUrl: 'https://example.com/v3.mp4',
      status: 'PUBLIC',
      modStatus: 'PENDING',
      viewCount: 0,
    ),
  ];

  @override
  Future<UserProfileModel> getProfile({int? userId}) async => profile;

  @override
  Future<List<TopicModel>> getTopics() async => [];

  @override
  Future<UserProfileModel> updateProfile(UserProfileModel profile, {int? userId}) async => profile;

  @override
  Future<List<UserVideoModel>> getUserVideos({int? userId}) async => videos;

  @override
  Future<List<UserVideoModel>> getMyVideosStatus() async => videos;

  @override
  Future<List<UserVideoModel>> getLikedVideos() async => [];

  @override
  Future<List<UserVideoModel>> getSavedVideos() async => [];

  @override
  Future<List<UserVideoModel>> getModerationVideos({String status = 'PENDING'}) async => [];

  @override
  Future<void> approveVideo(int videoId) async {}

  @override
  Future<void> rejectVideo(int videoId, String reason) async {}
}

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _TestHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  testWidgets('ProfileScreen renders profile header and 3 icon tabs correctly', (tester) async {
    final mockRepo = _MockProfileRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(repository: mockRepo),
        ),
      ),
    );

    // Initial load
    await tester.pumpAndSettle();

    // Verify user info
    expect(find.text('Yamada Kenji'), findsOneWidget);
    // Dưới tên: tên đăng nhập kèm cấp độ JLPT trên cùng một dòng, cạnh thẻ gói.
    expect(find.text('@yamada_san · N3'), findsOneWidget);
    // Hồ sơ mẫu đang có gói VIP còn hạn nên hiện thẻ PREMIUM.
    expect(find.text('PREMIUM'), findsOneWidget);

    // Chỉ số: số in đậm + nhãn trên cùng một dòng
    expect(find.textContaining('đang follow'), findsOneWidget);
    expect(find.textContaining('follower'), findsOneWidget);
    expect(find.textContaining('thích'), findsOneWidget);

    // Header gọn: không có hàng nút "Chỉnh sửa" / "Đăng video" và thẻ "Gói Miễn phí" riêng
    // (sửa hồ sơ mở từ avatar hoặc Cài đặt, đăng video mở từ nút tạo ở thanh điều hướng)
    expect(find.text('Chỉnh sửa'), findsNothing);
    expect(find.text('Đăng video'), findsNothing);
    expect(find.text('Gói Miễn phí'), findsNothing);

    // Verify "Quản lý upload" button is NOT in main profile body (moved to 3-line menu)
    expect(find.text('Quản lý upload (1)'), findsNothing);

    // 3 tab chỉ có icon (nhãn nằm trong tooltip)
    expect(find.byTooltip('Video của tôi'), findsOneWidget);
    expect(find.byTooltip('Video đã lưu'), findsOneWidget);
    expect(find.byTooltip('Video đã thích'), findsOneWidget);
    expect(find.byTooltip('Video riêng tư'), findsNothing);
    expect(find.byTooltip('Video đăng lại'), findsNothing);

    // Tab đầu hiển thị toàn bộ video của tôi (3 video trong mock)
    expect(find.text('Chưa có video nào'), findsNothing);

    // Tab switching test
    await tester.tap(find.byTooltip('Video đã lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có video đã lưu'), findsOneWidget);

    await tester.tap(find.byTooltip('Video đã thích'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có video đã thích'), findsOneWidget);
  });

  testWidgets('ProfileScreen settings sheet lists the settings rows and logout', (tester) async {
    final mockRepo = _MockProfileRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(repository: mockRepo),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Lối vào Quản lý theo dõi chỉ còn qua số đang follow / follower, không có icon riêng trên đầu trang.
    expect(find.byTooltip('Quản lý theo dõi'), findsNothing);

    // Tap 3-line menu button
    final menuButton = find.byTooltip('Tùy chọn & Cài đặt');
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Tiêu đề và các hàng cài đặt
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Người đã chặn'), findsOneWidget);
    // Các mục chưa có tính năng và mục trùng với icon chuông đã được gỡ.
    expect(find.text('Quyền riêng tư'), findsNothing);
    expect(find.text('Trợ giúp và phản hồi'), findsNothing);
    expect(find.text('Thông báo'), findsNothing);
    expect(find.text('Đăng xuất'), findsOneWidget);

    // Lối vào quản lý đăng tải luôn hiện, kèm số video chờ duyệt (mock có 1)
    expect(find.text('Quản lý đăng tải'), findsOneWidget);
    expect(find.text('1 chờ duyệt'), findsOneWidget);
    // Người dùng thường không thấy mục duyệt video
    expect(find.text('Quản lý duyệt nội dung'), findsNothing);
  });

  testWidgets('ProfileScreen bell icon opens the notifications sheet', (tester) async {
    final mockRepo = _MockProfileRepository();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProfileScreen(repository: mockRepo))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(NotificationSheet), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
  });

  testWidgets('ProfileScreen settings "Tài khoản" opens the edit profile screen', (tester) async {
    final mockRepo = _MockProfileRepository();

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProfileScreen(repository: mockRepo))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tùy chọn & Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tài khoản'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ProfileUpdateScreen), findsOneWidget);

    // Màn chỉnh sửa gọi mạng thật (timeout 4s) — chờ hết timer trước khi kết thúc test.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('ProfileScreen settings shows content moderation row for moderators', (tester) async {
    final mockRepo = _MockProfileRepository()
      ..profile = const UserProfileModel(
        id: 2,
        username: 'mod_san',
        displayName: 'Mod San',
        role: 'MODERATOR',
      );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ProfileScreen(repository: mockRepo))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tùy chọn & Cài đặt'));
    await tester.pumpAndSettle();

    expect(find.text('Quản lý duyệt nội dung'), findsOneWidget);
  });

  testWidgets('ProfileScreen settings sheet changes the app language', (tester) async {
    addTearDown(() => localeManager.changeLanguage(AppLanguage.vi));
    final mockRepo = _MockProfileRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(repository: mockRepo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tùy chọn & Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ngôn ngữ'));
    await tester.pumpAndSettle();

    // Bảng chọn ngôn ngữ liệt kê cả 3 ngôn ngữ
    expect(find.text('English'), findsOneWidget);
    expect(find.text('日本語'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(localeManager.currentLanguage, AppLanguage.en);
    expect(find.text('Switched to English'), findsOneWidget);
  });
}
