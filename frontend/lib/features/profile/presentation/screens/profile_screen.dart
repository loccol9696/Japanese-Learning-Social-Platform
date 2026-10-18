import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/models/user_profile_model.dart';
import '../../domain/repositories/profile_repository.dart';
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
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _repository.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
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
                onRefresh: _loadProfile,
                color: AppColors.periwinkle,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopBar()),
                    SliverToBoxAdapter(child: _buildProfileHeader()),
                    SliverToBoxAdapter(child: _buildActionRow()),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                  ),
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
