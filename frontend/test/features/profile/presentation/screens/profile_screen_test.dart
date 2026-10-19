import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/profile/domain/models/topic_model.dart';
import 'package:frontend/features/profile/domain/models/user_profile_model.dart';
import 'package:frontend/features/profile/domain/repositories/profile_repository.dart';
import 'package:frontend/features/profile/presentation/screens/profile_screen.dart';
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

  testWidgets('ProfileScreen renders profile header and 4 tabs correctly', (tester) async {
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
    expect(find.text('@yamada_san'), findsOneWidget);

    // Verify "Quản lý upload" button is NOT in main profile body (moved to 3-line menu)
    expect(find.text('Quản lý upload (1)'), findsNothing);

    // Verify 4 tabs
    expect(find.text('Video public'), findsOneWidget);
    expect(find.text('Video riêng tư'), findsOneWidget);
    expect(find.text('Video đã lưu'), findsOneWidget);
    expect(find.text('Video đăng lại'), findsOneWidget);

    // Tab switching test
    await tester.tap(find.text('Video riêng tư'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Video đã lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có video đã lưu'), findsOneWidget);

    await tester.tap(find.text('Video đăng lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có video đăng lại'), findsOneWidget);
  });

  testWidgets('ProfileScreen 3-line hamburger menu opens and shows subscription & coming soon items', (tester) async {
    final mockRepo = _MockProfileRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(repository: mockRepo),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap 3-line menu button
    final menuButton = find.byTooltip('Tùy chọn & Cài đặt');
    expect(menuButton, findsOneWidget);
    await tester.tap(menuButton);
    await tester.pumpAndSettle();

    // Verify menu header and content
    expect(find.text('Cài đặt & Tùy chọn'), findsOneWidget);
    expect(find.text('Gói VIP: Gói VIP 1 Tháng'), findsOneWidget);
    expect(find.text('Xem các gói Subscription'), findsOneWidget);
    expect(find.text('Quản lý upload'), findsOneWidget);
    expect(find.text('Cài đặt tài khoản'), findsOneWidget);
    expect(find.text('Cá nhân hóa'), findsOneWidget);
    expect(find.text('Chỉnh sửa hồ sơ'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);

    // Tap "Cài đặt tài khoản" to test placeholder SnackBar notification
    await tester.tap(find.text('Cài đặt tài khoản'));
    await tester.pumpAndSettle();

    // Verify SnackBar appears
    expect(
      find.text('Cài đặt tài khoản: Tính năng sẽ được hoàn thiện trong thời gian tới'),
      findsOneWidget,
    );
  });
}
