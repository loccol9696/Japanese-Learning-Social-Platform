import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../../subscription/models/subscription_model.dart';
import '../../../subscription/services/subscription_service.dart';
import '../../../../app/routes.dart';
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
  bool _isLoading = true;
  int _selectedTab = 0;

  static const _postGradients = [
    [Color(0xFF28324A), Color(0xFF9FB4C7)],
    [Color(0xFF4A2D42), Color(0xFFE5A5B9)],
    [Color(0xFF162F3B), Color(0xFF8DC6D3)],
    [Color(0xFF7C4A39), Color(0xFFE7B36A)],
    [Color(0xFF293A64), Color(0xFF91A9DC)],
    [Color(0xFF4D315B), Color(0xFFC48FDA)],
    [Color(0xFF263E36), Color(0xFF8EC7A8)],
    [Color(0xFF51412F), Color(0xFFD4B27B)],
    [Color(0xFF252525), Color(0xFF777777)],
  ];

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        ProfileRepositoryImpl(remoteDataSource: ProfileRemoteDataSourceImpl());
    _loadProfile();
    _loadMembershipStatus();
  }

  Future<void> _loadMembershipStatus() async {
    try {
      final status = await SubscriptionService.instance.getMySubscriptionStatus(_profile.id);
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
      final profile = await _repository.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.periwinkle),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    _loadProfile(),
                    _loadMembershipStatus(),
                  ]);
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
                    _buildPostGrid(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 28, color: Colors.black87),
          const Spacer(),
          _topIcon(Icons.person_add_alt_1_outlined, badge: '2'),
          const SizedBox(width: 18),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.menu_rounded, size: 30),
            color: Colors.black87,
          ),
        ],
      ),
    );
  }

  Widget _topIcon(IconData icon, {String? badge}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 29, color: Colors.black87),
        if (badge != null)
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFFE91E63),
                shape: BoxShape.circle,
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileHeader() {
    final displayName = _profile.displayName.isNotEmpty
        ? _profile.displayName
        : 'JLSP Learner';
    final username = _profile.username.isNotEmpty
        ? '@${_profile.username}'
        : '@learner';
    final isVip = _membershipStatus?.hasActiveSubscription == true;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: isVip ? 26 : 31,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isVip) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFF0F172A),
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  username,
                  style: const TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _stat('9.779', 'Đã follow'),
                    _stat('171', 'Follower'),
                    _stat('198', 'Thích'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: const Color(0xFFEDEDED),
          backgroundImage: _profile.avatarUrl.isNotEmpty
              ? NetworkImage(_profile.avatarUrl)
              : null,
          child: _profile.avatarUrl.isEmpty
              ? const Icon(Icons.person, size: 60, color: Colors.black38)
              : null,
        ),
        Positioned(
          right: -4,
          bottom: 2,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF18BFE5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 23),
          ),
        ),
      ],
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
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF777777), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openEditProfile,
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Thêm tiểu sử'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                backgroundColor: const Color(0xFFF1F1F1),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: _openEditProfile,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF1F1F1),
              foregroundColor: Colors.black54,
            ),
            icon: const Icon(Icons.edit_outlined),
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
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF10B981), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
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
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B), size: 16),
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
                backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              ),
              onPressed: _navigateToSubscription,
              icon: Icon(
                isLifetime ? Icons.workspace_premium_rounded : Icons.upgrade_rounded,
                size: 16,
                color: const Color(0xFFFFD700),
              ),
              label: Text(
                isLifetime ? 'Xem chi tiết đặc quyền VIP' : 'Nâng cấp lên Gói Trọn Đời',
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
          colors: [Color(0xFF0F2042), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
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
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    const icons = [
      Icons.grid_view_rounded,
      Icons.lock_outline_rounded,
      Icons.repeat_rounded,
      Icons.bookmark_border_rounded,
      Icons.favorite_border_rounded,
    ];

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
      ),
      child: Row(
        children: List.generate(icons.length, (index) {
          final selected = index == _selectedTab;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = index),
              child: SizedBox(
                height: 58,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[index],
                      size: 26,
                      color: selected ? Colors.black : Colors.black45,
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 3,
                      width: selected ? 42 : 0,
                      color: Colors.black,
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

  Widget _buildPostGrid() {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 2),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildPostTile(index),
          childCount: _postGradients.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 0.72,
        ),
      ),
    );
  }

  Widget _buildPostTile(int index) {
    final colors = _postGradients[index];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Icon(
              index.isEven
                  ? Icons.auto_awesome_rounded
                  : Icons.play_circle_outline_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 38,
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Row(
              children: [
                const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 2),
                Text(
                  [
                    '432',
                    '155',
                    '198',
                    '177',
                    '1.203',
                    '213',
                    '98',
                    '64',
                    '41',
                  ][index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (index == 0)
            const Positioned(
              left: 8,
              top: 8,
              child: Text(
                'Bản nháp',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
