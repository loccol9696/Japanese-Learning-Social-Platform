import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../core/auth/auth_guard.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/data/auth_session.dart';
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
  int _selectedTab = 0; // 0: Video của tôi, 1: Video đã lưu, 2: Video đã thích

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        ProfileRepositoryImpl(remoteDataSource: ProfileRemoteDataSourceImpl());
    AuthSession.instance.addListener(_onAuthChanged);
    if (AuthSession.instance.isAuthenticated || widget.repository != null) {
      _loadProfile();
    }
  }

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

  Future<void> _navigateToSubscription() async {
    await Navigator.of(context).pushNamed(AppRoutes.subscription);
    await _loadMembershipStatus();
  }

  Future<void> _loadProfile() async {
    try {
      final results = await Future.wait([
        _repository.getProfile(),
        _repository.getMyVideosStatus(),
        _repository.getLikedVideos(),
        _repository.getSavedVideos(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as UserProfileModel;
        _videos = results[1] as List<UserVideoModel>;
        _likedVideos = results[2] as List<UserVideoModel>;
        _savedVideos = results[3] as List<UserVideoModel>;
        _isLoading = false;
      });
      await _loadMembershipStatus();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _openEditProfile() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfileUpdateScreen()))
        .then((_) => _loadProfile());
  }

  void _openMyVideosStatus() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyVideosStatusScreen()))
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
      // Chỉ hiện khi có video đã đăng.
      if (_videos.isNotEmpty)
        _SettingsRowData(
          icon: Icons.cloud_upload_outlined,
          title: 'Quản lý bài đăng',
          value: _pendingCount > 0 ? '$_pendingCount chờ duyệt' : null,
          onTap: () {
            Navigator.of(sheetContext).pop();
            _openMyVideosStatus();
          },
        ),
      // Chỉ hiện với Moderator / Admin.
      if (_profile.isModerator)
        _SettingsRowData(
          icon: Icons.fact_check_outlined,
          title: 'Duyệt video',
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
          _showFeatureComingSoon('Tài khoản');
        },
      ),
      _SettingsRowData(
        icon: Icons.notifications_none_rounded,
        title: 'Thông báo',
        onTap: () {
          Navigator.of(sheetContext).pop();
          _showFeatureComingSoon('Thông báo');
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

  /// 0: tất cả video của tôi (huy hiệu trên ô cho biết riêng tư / chờ duyệt / bị từ chối),
  /// 1: video đã lưu, 2: video đã thích.
  List<UserVideoModel> get _tabVideos {
    return switch (_selectedTab) {
      0 => _videos,
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
                onRefresh: () async {
                  await Future.wait([_loadProfile(), _loadMembershipStatus()]);
                },
                color: AppColors.periwinkle,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(child: _buildProfileHeader()),
                    SliverToBoxAdapter(child: _buildActionRow()),
                    SliverToBoxAdapter(child: _buildMembershipCard()),
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
                _stat('${_profile.followingCount}', 'đang follow'),
                _stat('${_profile.followersCount}', 'follower'),
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

  Widget _buildActionRow() {
    const radius = BorderRadius.all(Radius.circular(10));
    const labelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _openEditProfile,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: AppPalette.textPrimary,
                backgroundColor: AppPalette.background,
                side: BorderSide(color: AppPalette.surface),
                shape: const RoundedRectangleBorder(borderRadius: radius),
                textStyle: labelStyle,
              ),
              child: const Text('Chỉnh sửa'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.upload),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: AppPalette.accent,
                foregroundColor: AppPalette.onAccent,
                elevation: 0,
                shape: const RoundedRectangleBorder(borderRadius: radius),
                textStyle: labelStyle,
              ),
              child: const Text('Đăng video'),
            ),
          ),
        ],
      ),
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
  Widget _stat(String value, String label) {
    return Text.rich(
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
  }

  Widget _buildMembershipCard() {
    final status = _membershipStatus;
    final isVip = status?.hasActiveSubscription == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: isVip ? _buildVipCard(status!) : _buildFreeCard(),
    );
  }

  Widget _buildVipCard(SubscriptionStatus status) {
    final isLifetime = status.isLifetime;
    final planName = status.planName ?? 'Gói VIP';
    final expiryText = isLifetime
        ? 'Thời hạn: Vĩnh viễn (Trọn đời)'
        : 'Hết hạn: ${status.formattedExpiryDate} (Còn ${status.daysRemaining} ngày)';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.surfaceCardSubtle, AppColors.surfaceCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppPalette.gold.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.gold.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppPalette.gold, AppPalette.warning],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: AppPalette.background,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'KOTOBA VIP',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: AppPalette.gold,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.success
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppPalette.success,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: AppPalette.success,
                                size: 7,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'ĐANG DÙNG',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppPalette.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      planName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppPalette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppPalette.background.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppPalette.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  color: AppPalette.warning,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    expiryText,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppPalette.warning, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: AppPalette.warning
                    .withValues(alpha: 0.12),
              ),
              onPressed: _navigateToSubscription,
              icon: Icon(
                isLifetime
                    ? Icons.workspace_premium_rounded
                    : Icons.upgrade_rounded,
                size: 16,
                color: AppPalette.gold,
              ),
              label: Text(
                isLifetime
                    ? 'Xem chi tiết đặc quyền VIP'
                    : 'Nâng cấp lên Gói Trọn Đời',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppPalette.gold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeCard() {
    return Material(
      color: AppPalette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _navigateToSubscription,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppPalette.textSecondary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Gói Miễn phí',
                  style: TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                'Nâng cấp Premium',
                style: TextStyle(
                  color: _linkBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, color: _linkBlue, size: 22),
            ],
          ),
        ),
      ),
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

    return SliverPadding(
      padding: const EdgeInsets.all(3),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildVideoTile(videos[index]),
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

  Widget _buildVideoTile(UserVideoModel video) {
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
      onTap: _openMyVideosStatus,
      child: Container(
        color: AppColors.surfaceCard,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty)
              Image.network(
                video.thumbnailUrl!,
                fit: BoxFit.cover,
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
