import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/models/profile_video.dart';
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
  ProfileStats? _stats; // null: đang tải / lỗi -> "–"

  // Ba tab nạp song song từ API; gán Future mới để tải lại.
  late Future<List<ProfileVideo>> _myVideos;
  late Future<List<ProfileVideo>> _savedVideos;
  late Future<List<ProfileVideo>> _likedVideos;

  @override
  void initState() {
    super.initState();
    // 3 Tabs: Video, Saved (Bookmark), Liked
    _tabController = TabController(length: 3, vsync: this);
    _repository =
        widget.repository ??
        ProfileRepositoryImpl(remoteDataSource: ProfileRemoteDataSourceImpl());
    _loadProfile();
    _loadStats();
    _myVideos = _observed(_repository.getMyVideos());
    _savedVideos = _observed(_repository.getSavedVideos());
    _likedVideos = _observed(_repository.getLikedVideos());
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

  /// Tab chưa mở thì chưa có FutureBuilder lắng nghe: đánh dấu lỗi đã được xử lý để không
  /// thành "Unhandled Exception"; FutureBuilder gắn vào sau vẫn nhận lỗi để hiển thị.
  Future<List<ProfileVideo>> _observed(Future<List<ProfileVideo>> future) {
    future.ignore();
    return future;
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _repository.getStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // Giữ "–"; lỗi chi tiết hiển thị ở các tab
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
              onCreateContent: () => showCreateContentSheet(context),
            ),

            // 3. Social Stats + Single Wide Action Button
            ProfileStatsSection(stats: _stats, onEditProfile: _editProfile),

            // 4. Icon-based Tab Bar (Sticky above Grid)
            _buildIconTabBar(),

            // 5. Grid/List Content wrapped inside Expanded (No overflow, independent scroll)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Video của mình (mọi trạng thái duyệt)
                  _buildMyVideoGrid(),

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
          Tab(icon: Icon(Icons.grid_on_rounded, size: 21)),
          // Tab 2: Video đã lưu (Bookmark)
          Tab(icon: Icon(Icons.bookmark_rounded, size: 21)),
          // Tab 3: Trái tim (Liked)
          Tab(icon: Icon(Icons.favorite_rounded, size: 21)),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. LƯỚI NỘI DUNG (TIKTOK VIDEO GRID)
  // ===========================================================================

  /// Một tab: đang tải / lỗi (thử lại) / rỗng / lưới video; kéo xuống để làm mới.
  Widget _buildVideoTab({
    required Future<List<ProfileVideo>> future,
    required Future<List<ProfileVideo>> Function() reload,
    required Widget empty,
    required ProfileVideoTile Function(ProfileVideo video) tile,
  }) {
    Future<void> refresh() async {
      final next = reload();
      _loadStats();
      try {
        await next;
      } catch (_) {
        // Lỗi hiển thị trong tab
      }
    }

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: AppColors.socialSurface,
      onRefresh: refresh,
      child: FutureBuilder<List<ProfileVideo>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.socialTextMuted,
              ),
            );
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return ProfileTabError(
              message: error is ApiException ? error.message : '$error',
              onRetry: refresh,
            );
          }
          final videos = snapshot.data ?? const [];
          if (videos.isEmpty) return empty;
          return ProfileVideoGrid(videos: videos, tileBuilder: tile);
        },
      ),
    );
  }

  // TAB 1: VIDEO CỦA MÌNH (kèm badge Chờ duyệt / Bị từ chối)
  Widget _buildMyVideoGrid() {
    return _buildVideoTab(
      future: _myVideos,
      reload: () {
        final next = _observed(_repository.getMyVideos());
        setState(() {
          _myVideos = next;
        });
        return next;
      },
      empty: ProfileEmptyTab(
        icon: Icons.video_library_outlined,
        title: appStrings.profileNoVideosTitle,
        subtitle: appStrings.profileNoVideosHint,
      ),
      tile: (video) => ProfileVideoTile(
        video: video,
        snackPrefix: appStrings.profileWatchVideo,
        topLeftBadge: ModStatusBadge.maybe(video),
        topRightBadge: video.jlptLevel != null
            ? JlptBadge(label: video.jlptLevel!)
            : null,
        bottomIcon: Icons.play_arrow_rounded,
        bottomIconColor: Colors.white,
        bottomText: formatCount(video.viewCount),
      ),
    );
  }

  // TAB 2: VIDEO ĐÃ LƯU (BOOKMARK)
  Widget _buildSavedVideoGrid() {
    return _buildVideoTab(
      future: _savedVideos,
      reload: () {
        final next = _observed(_repository.getSavedVideos());
        setState(() {
          _savedVideos = next;
        });
        return next;
      },
      empty: ProfileEmptyTab(
        icon: Icons.bookmark_border_rounded,
        title: appStrings.profileNoSavedTitle,
        subtitle: appStrings.profileNoSavedHint,
      ),
      tile: (video) => ProfileVideoTile(
        video: video,
        snackPrefix: appStrings.profileSavedVideo,
        topRightBadge: video.jlptLevel != null
            ? JlptBadge(label: video.jlptLevel!)
            : null,
        bottomIcon: Icons.play_arrow_rounded,
        bottomIconColor: Colors.white,
        bottomText: formatCount(video.viewCount),
      ),
    );
  }

  // TAB 3: TRÁI TIM (VIDEO ĐÃ THÍCH)
  Widget _buildLikedVideoGrid() {
    return _buildVideoTab(
      future: _likedVideos,
      reload: () {
        final next = _observed(_repository.getLikedVideos());
        setState(() {
          _likedVideos = next;
        });
        return next;
      },
      empty: ProfileEmptyTab(
        icon: Icons.favorite_border_rounded,
        title: appStrings.profileNoLikedTitle,
        subtitle: appStrings.profileNoLikedHint,
      ),
      tile: (video) => ProfileVideoTile(
        video: video,
        snackPrefix: appStrings.profileLikedVideo,
        bottomIcon: Icons.favorite_rounded,
        bottomIconColor: AppColors.socialRed,
        bottomText: formatCount(video.likeCount),
      ),
    );
  }
}
