import 'package:flutter/material.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/mock/profile_mock_videos.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_sheets.dart';
import '../widgets/profile_video_grid.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Profile User Info
  String _displayName = 'Nguyễn Hữu Lộc';
  String _username = '@locnh96';
  String _bio =
      'Học tiếng Nhật mỗi ngày 🇯🇵 | N3 Target 2026 🎯 | Luyện Kaiwa & chia sẻ Flashcard';
  String _avatarUrl =
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80';
  final int _streakDays = 7;

  final List<Map<String, dynamic>> _publicVideos = mockPublicVideos;
  final List<Map<String, dynamic>> _savedVideos = mockSavedVideos;
  final List<Map<String, dynamic>> _likedVideos = mockLikedVideos;

  @override
  void initState() {
    super.initState();
    // 3 Tabs: Video, Saved (Bookmark), Liked
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await TokenStorage.instance.getUserData();
    if (userData != null && mounted) {
      setState(() {
        if (userData['displayName'] != null &&
            userData['displayName'].toString().trim().isNotEmpty) {
          _displayName = userData['displayName'];
        }
        if (userData['username'] != null &&
            userData['username'].toString().trim().isNotEmpty) {
          _username = '@${userData['username'].toString().replaceAll('@', '')}';
        }
        if (userData['bio'] != null &&
            userData['bio'].toString().trim().isNotEmpty) {
          _bio = userData['bio'];
        }
        if (userData['avatarUrl'] != null &&
            userData['avatarUrl'].toString().trim().isNotEmpty) {
          _avatarUrl = userData['avatarUrl'];
        }
      });
    }
  }

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
              username: _username,
              onSwitchAccount: () => showAccountSwitcherSheet(
                context,
                avatarUrl: _avatarUrl,
                displayName: _displayName,
                username: _username,
              ),
              onAddFriends: () => showAddFriendsSheet(context),
              onOpenSettings: () => showSettingsSheet(context),
            ),

            // 2. Profile Info (Horizontal Layout) - Compact
            ProfileInfoSection(
              displayName: _displayName,
              avatarUrl: _avatarUrl,
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

  void _editProfile() {
    showEditProfileDialog(
      context,
      displayName: _displayName,
      bio: _bio,
      onSave: (edit) => setState(() {
        if (edit.displayName.isNotEmpty) {
          _displayName = edit.displayName;
        }
        _bio = edit.bio;
      }),
    );
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
        snackPrefix: 'Xem',
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
      return const ProfileEmptyTab(
        icon: Icons.bookmark_border_rounded,
        title: 'Chưa có video đã lưu',
        subtitle: 'Nhấn biểu tượng bookmark trên video để lưu lại và xem sau',
      );
    }

    return ProfileVideoGrid(
      videos: _savedVideos,
      tileBuilder: (video) => ProfileVideoTile(
        video: video,
        snackPrefix: 'Video đã lưu',
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
        snackPrefix: 'Video đã thích',
        bottomIcon: Icons.favorite_rounded,
        bottomIconColor: AppColors.socialRed,
        bottomText: video['likesText'] ?? '0',
      ),
    );
  }
}
