import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/mock/profile_mock_videos.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/profile_repository.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_sheets.dart';
import '../widgets/profile_video_grid.dart';
import 'profile_update_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ProfileRepository? repository;

  const ProfileScreen({super.key, this.repository});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late final ProfileRepository _repository;

  // Hồ sơ thật từ API (/api/v1/profile); datasource tự dùng bản lưu cục bộ khi offline
  UserProfileModel _profile = const UserProfileModel();
  final int _streakDays = 7; // Backend chưa có API chuỗi ngày học

  final List<Map<String, dynamic>> _publicVideos = mockPublicVideos;
  final List<Map<String, dynamic>> _savedVideos = mockSavedVideos;
  final List<Map<String, dynamic>> _likedVideos = mockLikedVideos;

  @override
  void initState() {
    super.initState();
    // 3 Tabs: Video, Saved (Bookmark), Liked
    _tabController = TabController(length: 3, vsync: this);
    _repository = widget.repository ??
        ProfileRepositoryImpl(remoteDataSource: ProfileRemoteDataSourceImpl());
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _repository.getProfile();
      if (mounted) setState(() => _profile = profile);
    } catch (_) {
      // Giữ hồ sơ đang hiển thị; datasource đã tự xử lý offline
    }
  }

  String get _usernameLabel => '@${_profile.username.replaceAll('@', '')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.socialBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Bar Header
            ProfileTopBar(
              username: _usernameLabel,
              onSwitchAccount: () => showAccountSwitcherSheet(
                context,
                avatarUrl: _profile.avatarUrl,
                displayName: _profile.displayName,
                username: _usernameLabel,
              ),
              onAddFriends: () => showAddFriendsSheet(context),
              onOpenSettings: () => showSettingsSheet(context),
            ),

            // 2. Profile Info (Horizontal Layout) - Compact
            ProfileInfoSection(
              displayName: _profile.displayName,
              avatarUrl: _profile.avatarUrl,
              jlptLevel: _profile.currentLevel,
              streakDays: _streakDays,
              onCreateContent: () => showCreateContentSheet(context),
            ),

            // 3. Social Stats + Single Wide Action Button
            ProfileStatsSection(onEditProfile: _editProfile),

            // 4. Icon-based Tab Bar (Sticky above Grid)
            _buildIconTabBar(),

            // 5. Grid/List Content wrapped inside Expanded (No overflow, independent scroll)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Video Public (3-Column Grid)
                  _buildPublicVideoGrid(),

                  // Tab 2: Video đã lưu (Bookmark)
                  _buildSavedVideoGrid(),

                  // Tab 3: Video đã thích (Trái tim)
                  _buildLikedVideoGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sửa hồ sơ ở màn ProfileUpdateScreen (lưu lên backend) rồi nạp lại.
  Future<void> _editProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileUpdateScreen(repository: _repository),
      ),
    );
    if (mounted) await _loadProfile();
  }

  // ===========================================================================
  // 4. THANH TABS (3 TABS CHÍNH: VIDEO, ĐÃ LƯU, TRÁI TIM)
  // - Căn giữa icon, indicator rõ nét (weight 2.5)
  // ===========================================================================
  Widget _buildIconTabBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.socialBackground,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 2.5, // Đường kẻ dưới rõ nét
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.socialTextMuted,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          // Tab 1: Video Public
          Tab(
            icon: Icon(Icons.grid_on_rounded, size: 21),
          ),
          // Tab 2: Video đã lưu (Bookmark)
          Tab(
            icon: Icon(Icons.bookmark_rounded, size: 21),
          ),
          // Tab 3: Trái tim (Liked)
          Tab(
            icon: Icon(Icons.favorite_rounded, size: 21),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. LƯỚI NỘI DUNG (TIKTOK VIDEO GRID)
  // ===========================================================================

  /// Video ghim luôn đứng đầu lưới, giữ nguyên thứ tự các video còn lại.
  List<Map<String, dynamic>> get _sortedPublicVideos {
    final pinned = _publicVideos.where((v) => v['isPinned'] == true);
    final others = _publicVideos.where((v) => v['isPinned'] != true);
    return [...pinned, ...others];
  }

  Widget _buildPublicVideoGrid() {
    return ProfileVideoGrid(
      videos: _sortedPublicVideos,
      tileBuilder: (video) => ProfileVideoTile(
        video: video,
        snackPrefix: appStrings.profileWatchVideo,
        topLeftBadge: video['isPinned'] == true ? const PinnedBadge() : null,
        topRightBadge: video['jlpt'] != null
            ? JlptBadge(label: video['jlpt'] as String)
            : null,
        bottomIcon: Icons.play_arrow_rounded,
        bottomIconColor: Colors.white,
        bottomText: video['viewsText'] ?? '0',
      ),
    );
  }

  // TAB 2: VIDEO ĐÃ LƯU (BOOKMARK)
  Widget _buildSavedVideoGrid() {
    if (_savedVideos.isEmpty) {
      return ProfileEmptyTab(
        icon: Icons.bookmark_border_rounded,
        title: appStrings.profileNoSavedTitle,
        subtitle: appStrings.profileNoSavedHint,
      );
    }

    return ProfileVideoGrid(
      videos: _savedVideos,
      tileBuilder: (video) => ProfileVideoTile(
        video: video,
        snackPrefix: appStrings.profileSavedVideo,
        topRightBadge: video['jlpt'] != null
            ? JlptBadge(label: video['jlpt'] as String)
            : null,
        bottomIcon: Icons.play_arrow_rounded,
        bottomIconColor: Colors.white,
        bottomText: video['viewsText'] ?? '0',
      ),
    );
  }

  // TAB 3: TRÁI TIM (VIDEO ĐÃ THÍCH)
  Widget _buildLikedVideoGrid() {
    return ProfileVideoGrid(
      videos: _likedVideos,
      tileBuilder: (video) => ProfileVideoTile(
        video: video,
        snackPrefix: appStrings.profileLikedVideo,
        bottomIcon: Icons.favorite_rounded,
        bottomIconColor: AppColors.socialRed,
        bottomText: video['likesText'] ?? '0',
      ),
    );
  }
}
