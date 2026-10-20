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

class ProfileScreen extends StatefulWidget {
  final ProfileRepository? repository;

  const ProfileScreen({super.key, this.repository});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileRepository _repository;
  UserProfileModel _profile = const UserProfileModel();
  SubscriptionStatus? _membershipStatus;
  List<UserVideoModel> _videos = [];
  List<UserVideoModel> _likedVideos = [];
  List<UserVideoModel> _savedVideos = [];
  bool _isLoading = true;
  int _selectedTab = 0; // 0: Video public, 1: Video riêng tư, 2: Video đã lưu, 3: Video đăng lại

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        ProfileRepositoryImpl(remoteDataSource: ProfileRemoteDataSourceImpl());
    _loadProfile();
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
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? AppColors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              )
            : null,
        trailing:
            trailing ??
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }

  void _showMoreMenu() {
    final membership = _membershipStatus;
    final hasMembership = membership != null
        ? membership.hasActiveSubscription
        : _profile.isVip;
    final isLifetime = membership?.isLifetime == true;
    final planName =
        membership?.planName ?? _profile.subscriptionPlanName ?? 'Gói miễn phí';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.outlineVariant, width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cài đặt & Tùy chọn',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D2542),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: hasMembership
                              ? const Color(0xFFC99A3D)
                              : const Color(0xFF394568),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: hasMembership
                                      ? const Color(0xFF5B4720)
                                      : const Color(0xFF303A62),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  hasMembership
                                      ? Icons.workspace_premium_outlined
                                      : Icons.workspace_premium_rounded,
                                  color: hasMembership
                                      ? const Color(0xFFF0C866)
                                      : AppColors.periwinkle,
                                  size: 22,
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
                                          hasMembership
                                              ? planName
                                              : 'Gói miễn phí',
                                          style: const TextStyle(
                                            color: AppColors.onSurface,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (hasMembership) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFC99A3D),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'VIP',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      hasMembership
                                          ? (isLifetime
                                                ? 'Đã kích hoạt vĩnh viễn'
                                                : 'Đang hoạt động')
                                          : 'Truy cập các bài học và tính năng cơ bản',
                                      style: TextStyle(
                                        color: AppColors.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _navigateToSubscription();
                              },
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                              ),
                              label: Text(
                                hasMembership
                                    ? 'Xem quyền lợi gói'
                                    : 'Xem các gói hội viên',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasMembership
                                    ? const Color(0xFFC99A3D)
                                    : AppColors.periwinkle,
                                foregroundColor: hasMembership
                                    ? const Color(0xFF171B2E)
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Menu list items
                    _buildMenuTile(
                      icon: Icons.card_membership_outlined,
                      iconColor: const Color(0xFFF0C866),
                      title: hasMembership
                          ? 'Quản lý gói hội viên'
                          : 'Xem các gói hội viên',
                      subtitle: hasMembership
                          ? 'Xem quyền lợi và thông tin gói hiện tại'
                          : 'Bảng giá và quyền lợi hội viên',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _navigateToSubscription();
                      },
                    ),

                    _buildMenuTile(
                      icon: Icons.cloud_upload_outlined,
                      iconColor: AppColors.softSkyBlue,
                      title: 'Quản lý upload',
                      subtitle:
                          '${_videos.length} bài học ($_pendingCount chờ duyệt)',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _openMyVideosStatus();
                      },
                    ),

                    if (_profile.isModerator)
                      _buildMenuTile(
                        icon: Icons.fact_check_rounded,
                        iconColor: AppColors.periwinkle,
                        title: 'Duyệt video bài học',
                        subtitle: 'Quyền Moderator / Admin',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _openModerationQueue();
                        },
                      ),

                    _buildMenuTile(
                      icon: Icons.manage_accounts_outlined,
                      iconColor: const Color(0xFF94A3B8),
                      title: 'Cài đặt tài khoản',
                      subtitle: 'Bảo mật, thông báo và thông tin đăng nhập',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showFeatureComingSoon('Cài đặt tài khoản');
                      },
                    ),

                    _buildMenuTile(
                      icon: Icons.palette_outlined,
                      iconColor: AppColors.lavender,
                      title: 'Cá nhân hóa',
                      subtitle: 'Giao diện, chủ đề và tùy chỉnh trải nghiệm',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _showFeatureComingSoon('Cá nhân hóa');
                      },
                    ),

                    _buildMenuTile(
                      icon: Icons.edit_note_rounded,
                      iconColor: AppColors.warmPeach,
                      title: 'Chỉnh sửa hồ sơ',
                      subtitle: 'Tên hiển thị, tiểu sử, cấp độ JLPT',
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _openEditProfile();
                      },
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: const Divider(
                        color: AppColors.outlineVariant,
                        height: 1,
                      ),
                    ),

                    _buildMenuTile(
                      icon: Icons.logout_rounded,
                      iconColor: const Color(0xFFEF4444),
                      title: 'Đăng xuất',
                      titleColor: const Color(0xFFEF4444),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await AuthSession.instance.logout();
                        if (!mounted) return;
                        await navigateToGuestHome(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<UserVideoModel> get _tabVideos {
    if (_selectedTab == 0) {
      // Video public (APPROVED & PUBLIC)
      return _videos.where((v) => v.isPublic && v.isApproved).toList();
    } else if (_selectedTab == 1) {
      // Video riêng tư (!isPublic)
      return _videos.where((v) => !v.isPublic).toList();
    } else if (_selectedTab == 2) {
      return _savedVideos;
    } else if (_selectedTab == 3) {
      return _likedVideos;
    } else {
      // Video đăng lại
      return [];
    }
  }

  int get _pendingCount => _videos.where((v) => v.isPending).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
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
                    SliverToBoxAdapter(child: _buildTopBar()),
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

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Hồ sơ',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          // 3-line hamburger menu button with clear, contrasting colors
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: _showMoreMenu,
                  icon: const Icon(
                    Icons.menu_rounded,
                    size: 22,
                    color: AppColors.onSurface,
                  ),
                  tooltip: 'Tùy chọn & Cài đặt',
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  padding: EdgeInsets.zero,
                ),
                if (_pendingCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 26,
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
                              color: AppColors.periwinkle.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _profile.isAdmin ? 'ADMIN' : 'MOD',
                              style: const TextStyle(
                                color: AppColors.periwinkle,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          username,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.periwinkle.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            _profile.currentLevel,
                            style: const TextStyle(
                              color: AppColors.periwinkle,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _stat('${_profile.followingCount}', 'Đã follow'),
                        _stat('${_profile.followersCount}', 'Follower'),
                        _stat('${_profile.likesCount}', 'Thích'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _buildAvatar(),
            ],
          ),

          // Real Bio Display
          if (_profile.bio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _profile.bio,
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Chỉnh sửa'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.onSurface,
                side: const BorderSide(color: AppColors.outlineVariant),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.upload),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Đăng video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.periwinkle,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _openEditProfile,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.surfaceContainerHighest,
            backgroundImage: _profile.avatarUrl.isNotEmpty
                ? NetworkImage(_profile.avatarUrl)
                : null,
            child: _profile.avatarUrl.isEmpty
                ? const Icon(
                    Icons.person,
                    size: 55,
                    color: AppColors.textSecondary,
                  )
                : null,
          ),
          Positioned(
            right: -2,
            bottom: 2,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.periwinkle,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(
                Icons.edit,
                color: AppColors.onPrimary,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
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
        gradient: const LinearGradient(
          colors: [AppColors.surfaceCardSubtle, AppColors.surfaceCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFF0A192F),
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
                        const Text(
                          'KOTOBA VIP',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Color(0xFFFFD700),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: Color(0xFF10B981),
                                size: 7,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'ĐANG DÙNG',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF10B981),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
              color: const Color(0xFF0A192F).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  color: Color(0xFFF59E0B),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    expiryText,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFDE68A),
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
                side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                backgroundColor: const Color(0xFFF59E0B)
                    .withValues(alpha: 0.12),
              ),
              onPressed: _navigateToSubscription,
              icon: Icon(
                isLifetime
                    ? Icons.workspace_premium_rounded
                    : Icons.upgrade_rounded,
                size: 16,
                color: const Color(0xFFFFD700),
              ),
              label: Text(
                isLifetime
                    ? 'Xem chi tiết đặc quyền VIP'
                    : 'Nâng cấp lên Gói Trọn Đời',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.surfaceContainerLow, AppColors.surfaceCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
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
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFFD54F),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kotoba Premium',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Gói hiện tại: Miễn phí (Free Tier)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '✓ Mở khóa toàn bộ AI (Chat AI, Giải thích ngữ pháp, Shadowing AI)\n✓ Không giới hạn lưu từ vựng & Flashcard\n✓ Học tập tập trung, không quảng cáo',
            style: TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0A192F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: _navigateToSubscription,
              child: const Text(
                'Nâng cấp Kotoba Premium ngay',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      {'label': 'Video public', 'icon': Icons.public_rounded},
      {'label': 'Video riêng tư', 'icon': Icons.lock_outline_rounded},
      {'label': 'Video đã lưu', 'icon': Icons.bookmark_outline_rounded},
      {'label': 'Video đã thích', 'icon': Icons.favorite_border_rounded},
      {'label': 'Video đăng lại', 'icon': Icons.repeat_rounded},
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final selected = index == _selectedTab;
          final tab = tabs[index];
          final label = tab['label'] as String;
          final icon = tab['icon'] as IconData;

          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = index),
              child: SizedBox(
                height: 54,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 2.5,
                      width: selected ? 32 : 0,
                      color: AppColors.periwinkle,
                    ),
                  ],
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
      IconData emptyIcon;
      String emptyTitle;
      String emptySubtitle;
      bool showUploadBtn = false;

      switch (_selectedTab) {
        case 0:
          emptyIcon = Icons.video_library_outlined;
          emptyTitle = 'Chưa có video public nào';
          emptySubtitle = 'Đăng tải các bài học tiếng Nhật hữu ích để chia sẻ với mọi người';
          showUploadBtn = true;
          break;
        case 1:
          emptyIcon = Icons.lock_outline_rounded;
          emptyTitle = 'Không có video riêng tư nào';
          emptySubtitle =
              'Chỉ bạn mới có thể xem các video được đặt ở chế độ riêng tư';
          break;
        case 2:
          emptyIcon = Icons.bookmark_outline_rounded;
          emptyTitle = 'Chưa có video đã lưu';
          emptySubtitle = 'Bấm biểu tượng lưu khi xem video để lưu bài học vào bộ sưu tập cá nhân';
          break;
        case 3:
          emptyIcon = Icons.favorite_border_rounded;
          emptyTitle = 'Chưa có video đã thích';
          emptySubtitle = 'Những video bạn đã nhấn thích sẽ xuất hiện tại đây';
          break;
        case 4:
        default:
          emptyIcon = Icons.repeat_rounded;
          emptyTitle = 'Chưa có video đăng lại';
          emptySubtitle = 'Các bài học bạn chia sẻ lại sẽ xuất hiện tại đây';
          break;
      }

      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emptyIcon,
                  size: 40,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                emptyTitle,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (showUploadBtn) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.upload),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Đăng video bài học'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.periwinkle,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
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
      badgeColor = const Color(0xFFF59E0B);
      badgeText = 'Chờ duyệt';
    } else if (video.isRejected) {
      badgeColor = const Color(0xFFEF4444);
      badgeText = 'Từ chối';
    } else if (!video.isPublic) {
      badgeColor = const Color(0xFF64748B);
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
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: Colors.white30,
                    size: 36,
                  ),
                ),
              )
            else
              const Center(
                child: Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white30,
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
                    style: const TextStyle(
                      color: Colors.white,
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
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  video.jlptLevel,
                  style: const TextStyle(
                    color: Colors.white,
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
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${video.viewCount}',
                    style: const TextStyle(
                      color: Colors.white,
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
