import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../core/auth/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../auth/data/auth_session.dart';
import '../../../chat/presentation/screens/shared_video_screen.dart';
import '../../../follow/presentation/screens/follow_manage_screen.dart';
import '../../../video/domain/models/user_video_model.dart';
import '../../../video/presentation/screens/moderation_queue_screen.dart';
import '../../../video/presentation/screens/my_videos_status_screen.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../../subscription/models/subscription_model.dart';
import '../../../subscription/services/subscription_service.dart';
import 'profile_update_screen.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/theme_manager.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileRepository? repository;

  const ProfileScreen({super.key, this.repository});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Xanh dương nhạt cho liên kết "Nâng cấp Premium" và gạch chân tab đang chọn.
  static Color get _linkBlue => AppPalette.info;

  late final ProfileRepository _repository;
  UserProfileModel _profile = const UserProfileModel();
  SubscriptionStatus? _membershipStatus;
  List<UserVideoModel> _videos = [];
  List<UserVideoModel> _likedVideos = [];
  List<UserVideoModel> _savedVideos = [];
  bool _isLoading = true;
  // Chỉ true ở lần tải đầu; tải lại sau đó vẫn giữ lưới video cũ trên màn hình.
  bool _videoListsLoading = true;
  // Vai trò lấy từ dữ liệu đăng nhập, dự phòng khi hồ sơ chưa tải được.
  bool _hasModeratorRole = false;
  int _selectedTab = 0; // 0: Video của tôi, 1: Video đã lưu, 2: Video đã thích

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        ProfileRepositoryImpl(remoteDataSource: ProfileRemoteDataSourceImpl());
    AuthSession.instance.addListener(_onAuthChanged);
    _checkRole();
    if (AuthSession.instance.isAuthenticated || widget.repository != null) {
      _loadProfile();
    }
  }

  Future<void> _checkRole() async {
    try {
      final userData = await TokenStorage.instance.getUserData();
      final role = userData?['role']?.toString().toUpperCase();
      final isModerator = role == 'MODERATOR' || role == 'ADMIN';
      if (mounted && isModerator != _hasModeratorRole) {
        setState(() => _hasModeratorRole = isModerator);
      }
    } catch (_) {}
  }

  bool get _canModerate => _profile.isModerator || _hasModeratorRole;

  @override
  void dispose() {
    AuthSession.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    if (AuthSession.instance.isAuthenticated) {
      _loadProfile();
    } else {
      setState(() {
        _profile = const UserProfileModel();
        _videos = [];
        _likedVideos = [];
        _savedVideos = [];
        _membershipStatus = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMembershipStatus() async {
    try {
      final status = await SubscriptionService.instance.getMySubscriptionStatus(
        _profile.id,
      );
      if (mounted) {
        setState(() {
          _membershipStatus = status;
        });
      }
    } catch (_) {}
  }

  /// Hồ sơ (nhẹ) hiện ngay khi về; ba danh sách video tải song song và tự điền
  /// vào khi xong, không bắt cả màn hình chờ request chậm nhất. Một danh sách lỗi
  /// cũng không làm mất các phần còn lại.
  Future<void> _loadProfile() async {
    final videoLists = _loadVideoLists();
    try {
      final profile = await _repository.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
      await Future.wait([videoLists, _loadMembershipStatus()]);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
      await videoLists;
    }
  }

  Future<void> _loadVideoLists() async {
    await Future.wait([
      _loadVideoList(_repository.getMyVideosStatus, (v) => _videos = v),
      _loadVideoList(_repository.getLikedVideos, (v) => _likedVideos = v),
      _loadVideoList(_repository.getSavedVideos, (v) => _savedVideos = v),
    ]);
    if (mounted) setState(() => _videoListsLoading = false);
  }

  Future<void> _loadVideoList(
    Future<List<UserVideoModel>> Function() fetch,
    void Function(List<UserVideoModel>) assign,
  ) async {
    try {
      final videos = await fetch();
      if (mounted) setState(() => assign(videos));
    } catch (_) {
      // Giữ danh sách đang hiển thị; kéo xuống để thử lại.
    }
  }

  void _openEditProfile() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfileUpdateScreen()))
        .then((_) => _loadProfile());
  }

  /// [initialTab]: 0 = người theo dõi bạn, 1 = người bạn đang theo dõi.
  void _openFollowManage({int initialTab = 0}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => FollowManageScreen(initialTab: initialTab),
          ),
        )
        .then((_) => _loadProfile());
  }

  void _openMyVideosStatus() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyVideosStatusScreen()))
        .then((_) => _loadProfile());
  }

  /// Mở thẳng video được bấm (cùng màn hình dùng khi mở video chia sẻ trong chat).
  void _openVideo(UserVideoModel video) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => SharedVideoScreen(videoId: video.id),
          ),
        )
        .then((_) => _loadProfile());
  }

  void _openModerationQueue() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ModerationQueueScreen()))
        .then((_) => _loadProfile());
  }

  void _showFeatureComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.softSkyBlue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$featureName: Tính năng sẽ được hoàn thiện trong thời gian tới',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Đỏ cho nút đăng xuất.
  static Color get _dangerRed => AppPalette.error;

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: _buildSettingsSheet,
    );
  }

  Widget _buildSettingsSheet(BuildContext sheetContext) {
    final rows = <_SettingsRowData>[
      _SettingsRowData(
        icon: Icons.cloud_upload_outlined,
        title: 'Quản lý đăng tải',
        value: _pendingCount > 0 ? '$_pendingCount chờ duyệt' : null,
        onTap: () {
          Navigator.of(sheetContext).pop();
          _openMyVideosStatus();
        },
      ),
      // Chỉ hiện với Moderator / Admin.
      if (_canModerate)
        _SettingsRowData(
          icon: Icons.fact_check_outlined,
          title: 'Quản lý duyệt nội dung',
          onTap: () {
            Navigator.of(sheetContext).pop();
            _openModerationQueue();
          },
        ),
      _SettingsRowData(
        icon: Icons.person_outline_rounded,
        title: 'Tài khoản',
        onTap: () {
          Navigator.of(sheetContext).pop();
          _openEditProfile();
        },
      ),
      _SettingsRowData(
        icon: Icons.notifications_none_rounded,
        title: 'Thông báo',
        onTap: () {
          Navigator.of(sheetContext).pop();
          Navigator.of(context).pushNamed(AppRoutes.notifications);
        },
      ),
      _SettingsRowData(
        icon: Icons.language_rounded,
        title: 'Ngôn ngữ',
        value: localeManager.currentLanguage.name,
        onTap: () => _showLanguagePicker(sheetContext),
      ),
      _SettingsRowData(
        icon: Icons.brightness_6_outlined,
        title: 'Giao diện',
        value: _themeModeLabel(themeManager.mode),
        onTap: () => _showThemePicker(sheetContext),
      ),
      _SettingsRowData(
        icon: Icons.lock_outline_rounded,
        title: 'Quyền riêng tư',
        onTap: () {
          Navigator.of(sheetContext).pop();
          _showFeatureComingSoon('Quyền riêng tư');
        },
      ),
      _SettingsRowData(
        icon: Icons.help_outline_rounded,
        title: 'Trợ giúp và phản hồi',
        onTap: () {
          Navigator.of(sheetContext).pop();
          _showFeatureComingSoon('Trợ giúp và phản hồi');
        },
      ),
    ];

    // Material (không phải Container tô màu) để hiệu ứng chạm của InkWell hiển thị.
    return Material(
      color: AppPalette.navBar,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppPalette.textSecondary.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cài đặt',
                        style: TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      tooltip: 'Đóng',
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < rows.length; i++)
                  _buildSettingsRow(rows[i], showDivider: i < rows.length - 1),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: _dangerRed.withValues(alpha: 0.16),
                      foregroundColor: _dangerRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await AuthSession.instance.logout();
                      if (!mounted) return;
                      await navigateToGuestHome(context);
                    },
                    child: const Text(
                      'Đăng xuất',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsRow(_SettingsRowData row, {required bool showDivider}) {
    return Column(
      children: [
        InkWell(
          onTap: row.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                Icon(row.icon, size: 22, color: AppPalette.textPrimary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    row.title,
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (row.value != null) ...[
                  Text(
                    row.value!,
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppPalette.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: AppPalette.border),
      ],
    );
  }

  static String _themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Theo hệ thống',
    ThemeMode.light => 'Sáng',
    ThemeMode.dark => 'Tối',
  };

  /// Chọn giao diện sáng / tối / theo hệ thống; đổi xong đóng cả hai bảng.
  void _showThemePicker(BuildContext settingsSheetContext) {
    const options = [
      (ThemeMode.system, Icons.brightness_auto_outlined),
      (ThemeMode.light, Icons.light_mode_outlined),
      (ThemeMode.dark, Icons.dark_mode_outlined),
    ];
    showModalBottomSheet(
      context: settingsSheetContext,
      backgroundColor: Colors.transparent,
      builder: (pickerContext) {
        return Material(
          color: AppPalette.navBar,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Giao diện',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  for (final (mode, icon) in options)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(icon, color: AppPalette.textPrimary),
                      title: Text(
                        _themeModeLabel(mode),
                        style: TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      trailing: mode == themeManager.mode
                          ? Icon(Icons.check_rounded, color: AppPalette.accent)
                          : null,
                      onTap: () {
                        themeManager.setMode(mode);
                        Navigator.of(pickerContext).pop();
                        Navigator.of(settingsSheetContext).pop();
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Chọn ngôn ngữ giao diện; chọn xong đóng cả hai bảng.
  void _showLanguagePicker(BuildContext settingsSheetContext) {
    showModalBottomSheet(
      context: settingsSheetContext,
      backgroundColor: Colors.transparent,
      builder: (pickerContext) {
        return Material(
          color: AppPalette.navBar,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Ngôn ngữ',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  for (final language in AppLanguage.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(
                        language.flag,
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(
                        language.name,
                        style: TextStyle(
                          color: AppPalette.textPrimary,
                          fontSize: 16,
                        ),
                      ),
                      trailing: language == localeManager.currentLanguage
                          ? Icon(
                              Icons.check_rounded,
                              color: AppPalette.accent,
                            )
                          : null,
                      onTap: () {
                        localeManager.changeLanguage(language);
                        Navigator.of(pickerContext).pop();
                        Navigator.of(settingsSheetContext).pop();
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: Text(appStrings.languageChanged),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 0: video của tôi đã được duyệt và đang đăng công khai (video chờ duyệt / bị từ chối /
  /// riêng tư xem ở "Quản lý bài đăng"), 1: video đã lưu, 2: video đã thích.
  List<UserVideoModel> get _tabVideos {
    return switch (_selectedTab) {
      0 => _videos.where((v) => v.isApproved && v.isPublic).toList(),
      1 => _savedVideos,
      _ => _likedVideos,
    };
  }

  int get _pendingCount => _videos.where((v) => v.isPending).length;

  @override
  Widget build(BuildContext context) {
    if (!AuthSession.instance.isAuthenticated && widget.repository == null) {
      return _buildAuthenticationRequired();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: AppColors.periwinkle),
              )
            : RefreshIndicator(
                onRefresh: _loadProfile,
                color: AppColors.periwinkle,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(child: _buildProfileHeader()),
                    SliverToBoxAdapter(child: _buildTabBar()),
                    _buildVideoContent(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAuthenticationRequired() {
    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: AppColors.textSecondary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'Đăng nhập để xem hồ sơ',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Thông tin hồ sơ chỉ hiển thị cho tài khoản đã đăng nhập.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  await requireAuthentication(context);
                },
                child: const Text('Đăng nhập ngay'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final displayName = _profile.displayName.isNotEmpty
        ? _profile.displayName
        : (_profile.username.isNotEmpty ? _profile.username : 'Học viên JLSP');
    final username = _profile.username.isNotEmpty
        ? '@${_profile.username}'
        : '@learner';
    final handle = _profile.currentLevel.isNotEmpty
        ? '$username · ${_profile.currentLevel}'
        : username;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + name/handle + menu icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(displayName),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_profile.isModerator) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.accentSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _profile.isAdmin ? 'ADMIN' : 'MOD',
                              style: TextStyle(
                                color: AppPalette.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        _buildPlanTag(),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openFollowManage,
                icon: Icon(
                  Icons.people_alt_outlined,
                  size: 26,
                  color: AppPalette.textPrimary,
                ),
                tooltip: 'Quản lý theo dõi',
              ),
              // Menu icon at top right
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: _showMoreMenu,
                    icon: Icon(
                      Icons.menu_rounded,
                      size: 26,
                      color: AppPalette.textPrimary,
                    ),
                    tooltip: 'Tùy chọn & Cài đặt',
                  ),
                  if (_pendingCount > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppPalette.warning,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppPalette.background,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Stats row
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Wrap(
              spacing: 20,
              runSpacing: 6,
              children: [
                _stat(
                  '${_profile.followingCount}',
                  'đang follow',
                  onTap: () => _openFollowManage(initialTab: 1),
                ),
                _stat(
                  '${_profile.followersCount}',
                  'follower',
                  onTap: () => _openFollowManage(),
                ),
                _stat('${_profile.likesCount}', 'thích'),
              ],
            ),
          ),

          // Bio
          if (_profile.bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                _profile.bio,
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Tag gói cạnh tên: vàng cho Premium, xanh cho Free.
  /// Ưu tiên trạng thái gói tải từ subscription; nếu chưa tải được thì dựa vào hồ sơ.
  Widget _buildPlanTag() {
    final isPremium = _isPremium;
    final color = isPremium ? AppPalette.gold : AppPalette.info;

    return GestureDetector(
      onTap: _showPlanSheet,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isPremium) ...[
              Icon(Icons.workspace_premium_rounded, size: 12, color: color),
              const SizedBox(width: 3),
            ],
            Text(
              isPremium ? 'PREMIUM' : 'FREE',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isPremium =>
      _membershipStatus?.hasActiveSubscription ?? _profile.isVip;

  Future<void> _openSubscription() async {
    await Navigator.of(context).pushNamed(AppRoutes.subscription);
    await _loadMembershipStatus();
  }

  /// Bảng mô tả gói hiện tại; gói Free có thêm nút nâng cấp.
  void _showPlanSheet() {
    final isPremium = _isPremium;
    final status = _membershipStatus;
    final color = isPremium ? AppPalette.gold : AppPalette.info;
    final planName = isPremium
        ? (status?.planName ?? _profile.subscriptionPlanName ?? 'Premium')
        : 'Gói Miễn phí';
    // Premium mà chưa biết mã gói thì không có gì để tra mô tả.
    final planFuture = (!isPremium || status?.planId != null)
        ? SubscriptionService.instance.getPlanDetail(
            planId: isPremium ? status?.planId : null,
          )
        : Future<SubscriptionPlan?>.value(null);
    final expiryText = !isPremium || status == null
        ? null
        : status.isLifetime
        ? 'Thời hạn: Vĩnh viễn (Trọn đời)'
        : 'Hết hạn: ${status.formattedExpiryDate} (Còn ${status.daysRemaining} ngày)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Material(
          color: AppPalette.navBar,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: AppPalette.textSecondary.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          isPremium
                              ? Icons.workspace_premium_rounded
                              : Icons.spa_outlined,
                          color: color,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            planName,
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (expiryText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        expiryText,
                        style: TextStyle(
                          color: AppPalette.warning,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    FutureBuilder<SubscriptionPlan?>(
                      future: planFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        return _buildPlanDetails(snapshot.data, isPremium);
                      },
                    ),
                    if (!isPremium) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _openSubscription();
                          },
                          icon: const Icon(Icons.workspace_premium_rounded),
                          label: const Text('Nâng cấp Premium'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppPalette.accent,
                            foregroundColor: AppPalette.onAccent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanDetails(SubscriptionPlan? plan, bool isPremium) {
    final description = plan?.description.trim() ?? '';
    final features = plan?.features ?? const <String>[];

    if (description.isEmpty && features.isEmpty) {
      return Text(
        isPremium
            ? 'Bạn đang sử dụng gói Premium với đầy đủ đặc quyền.'
            : 'Gói mặc định cho học viên mới, học tập cơ bản.',
        style: TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description.isNotEmpty)
          Text(
            description,
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        if (features.isNotEmpty) ...[
          if (description.isNotEmpty) const SizedBox(height: 12),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppPalette.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildAvatar(String displayName) {
    final hasImage = _profile.avatarUrl.isNotEmpty;
    final initial = displayName.trim().isEmpty
        ? '?'
        : String.fromCharCode(displayName.trim().runes.first).toUpperCase();

    return GestureDetector(
      onTap: _openEditProfile,
      child: CircleAvatar(
        radius: 36,
        backgroundColor: AppPalette.surface,
        backgroundImage: hasImage ? NetworkImage(_profile.avatarUrl) : null,
        child: hasImage
            ? null
            : Text(
                initial,
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  /// Số in đậm màu chính theo sau là nhãn màu phụ, cùng một dòng.
  Widget _stat(String value, String label, {VoidCallback? onTap}) {
    final text = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: value,
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return text;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: text,
    );
  }

  Widget _buildTabBar() {
    const tabs = [
      (icon: Icons.grid_view_outlined, label: 'Video của tôi'),
      (icon: Icons.bookmark_border_rounded, label: 'Video đã lưu'),
      (icon: Icons.favorite_border_rounded, label: 'Video đã thích'),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppPalette.surface),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = index == _selectedTab;
          final tab = tabs[index];

          return Expanded(
            child: Tooltip(
              message: tab.label,
              child: InkWell(
                onTap: () => setState(() => _selectedTab = index),
                child: SizedBox(
                  height: 48,
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          tab.icon,
                          size: 22,
                          color: selected
                              ? AppPalette.textPrimary
                              : AppPalette.textSecondary,
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 2,
                          color: selected ? _linkBlue : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildVideoContent() {
    final videos = _tabVideos;

    if (videos.isEmpty && _videoListsLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.periwinkle),
          ),
        ),
      );
    }

    if (videos.isEmpty) {
      final emptyTitle = switch (_selectedTab) {
        0 => 'Chưa có video nào',
        1 => 'Chưa có video đã lưu',
        _ => 'Chưa có video đã thích',
      };

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPalette.textSecondary, width: 2),
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 28,
                  color: AppPalette.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: TextStyle(
                  color: AppPalette.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Giải mã ảnh bìa đúng cỡ ô lưới (1/3 bề ngang) thay vì ảnh gốc độ phân giải cao:
    // nhẹ bộ nhớ và cuộn mượt hơn.
    final thumbnailCacheWidth =
        (MediaQuery.sizeOf(context).width /
                3 *
                MediaQuery.devicePixelRatioOf(context))
            .round();

    return SliverPadding(
      padding: const EdgeInsets.all(3),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) =>
              _buildVideoTile(videos[index], thumbnailCacheWidth),
          childCount: videos.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 3,
          mainAxisSpacing: 3,
          childAspectRatio: 0.72,
        ),
      ),
    );
  }

  Widget _buildVideoTile(UserVideoModel video, int thumbnailCacheWidth) {
    Color? badgeColor;
    String? badgeText;

    if (video.isPending) {
      badgeColor = AppPalette.warning;
      badgeText = 'Chờ duyệt';
    } else if (video.isRejected) {
      badgeColor = AppPalette.error;
      badgeText = 'Từ chối';
    } else if (!video.isPublic) {
      badgeColor = AppPalette.textSecondary;
      badgeText = 'Riêng tư';
    }

    return GestureDetector(
      onTap: () => _openVideo(video),
      child: Container(
        color: AppColors.surfaceCard,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty)
              Image.network(
                video.thumbnailUrl!,
                fit: BoxFit.cover,
                cacheWidth: thumbnailCacheWidth,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: AppPalette.border,
                    size: 36,
                  ),
                ),
              )
            else
              Center(
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  color: AppPalette.border,
                  size: 36,
                ),
              ),

            // Top Status Badge (if not approved or private)
            if (badgeText != null)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor!.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: AppPalette.onVideo,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

            // JLPT Level Tag
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppPalette.videoScrim.withValues(alpha: 0.54),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  video.jlptLevel,
                  style: TextStyle(
                    color: AppPalette.onVideo,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Bottom Views & Likes
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Row(
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: AppPalette.onVideo,
                    size: 16,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${video.viewCount}',
                    style: TextStyle(
                      color: AppPalette.onVideo,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRowData {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  const _SettingsRowData({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });
}
