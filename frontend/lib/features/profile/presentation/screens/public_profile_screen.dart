import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/auth_guard.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/count_format.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/data/auth_session.dart';
import '../../../home/domain/models/video_post.dart';
import '../../data/public_profile_service.dart';
import '../../domain/models/public_profile_model.dart';
import 'user_video_viewer_screen.dart';

/// Trang cá nhân công khai của người đăng video: thông tin, theo dõi và lưới video.
class PublicProfileScreen extends StatefulWidget {
  final int userId;
  final String fallbackName;
  final String fallbackUsername;
  final String fallbackAvatarUrl;
  final PublicProfileService? service;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.fallbackName = '',
    this.fallbackUsername = '',
    this.fallbackAvatarUrl = '',
    this.service,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late final PublicProfileService _service =
      widget.service ?? PublicProfileService.instance;

  PublicProfile? _profile;
  List<VideoPost> _videos = const [];
  bool _isLoading = true;
  bool _isFollowBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getProfile(widget.userId),
        _service.getVideos(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as PublicProfile;
        _videos = results[1] as List<VideoPost>;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 404
            ? 'Không tìm thấy người dùng này.'
            : 'Không tải được trang cá nhân.';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được trang cá nhân. Kiểm tra kết nối rồi thử lại.';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _isFollowBusy) return;
    if (!AuthSession.instance.isAuthenticated) {
      final ok = await requireAuthentication(
        context,
        message: 'Bạn cần đăng nhập để theo dõi người khác.',
      );
      if (!ok || !mounted) return;
      await _load();
      if (_profile?.isSelf ?? false) return;
    }
    setState(() => _isFollowBusy = true);
    try {
      final result = await _service.toggleFollow(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = (_profile ?? profile).copyWith(
          isFollowing: result.following,
          followersCount: result.followersCount,
        );
        _isFollowBusy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isFollowBusy = false);
      AppToast.showError(e.message, context: context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFollowBusy = false);
      AppToast.showError('Không cập nhật được theo dõi. Thử lại nhé.', context: context);
    }
  }

  void _showMessageComingSoon() {
    AppToast.showInfo('Tính năng nhắn tin đang được phát triển', context: context);
  }

  void _openVideo(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserVideoViewerScreen(posts: _videos, initialIndex: index),
      ),
    );
  }

  void _openMenu() {
    final profile = _profile;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Material(
        color: AppPalette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: AppPalette.textSecondary.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
                leading: const Icon(Icons.copy_rounded, color: AppPalette.textPrimary),
                title: const Text(
                  'Sao chép tên người dùng',
                  style: TextStyle(color: AppPalette.textPrimary, fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  final name = profile?.username ?? widget.fallbackUsername;
                  Clipboard.setData(ClipboardData(text: name.startsWith('@') ? name : '@$name'));
                  AppToast.showSuccess('Đã sao chép', context: context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppPalette.accent))
                  : _error != null
                  ? _buildError()
                  : _buildContent(_profile!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppPalette.textPrimary),
          ),
          const Spacer(),
          IconButton(
            onPressed: _openMenu,
            icon: const Icon(Icons.more_vert_rounded, color: AppPalette.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, style: const TextStyle(color: AppPalette.textSecondary)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _buildContent(PublicProfile profile) {
    final name = profile.displayName.isNotEmpty ? profile.displayName : widget.fallbackName;
    final username = profile.username.isNotEmpty
        ? profile.username
        : widget.fallbackUsername.replaceFirst('@', '');
    final level = profile.jlptLevel.isNotEmpty ? ' · ${profile.jlptLevel}' : '';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(url: profile.avatarUrl.isNotEmpty ? profile.avatarUrl : widget.fallbackAvatarUrl, name: name),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@$username$level',
                            style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (profile.bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    profile.bio.trim(),
                    style: const TextStyle(color: AppPalette.textSecondary, fontSize: 13.5, height: 1.4),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  children: [
                    _stat(profile.followingCount, 'đang follow'),
                    _stat(profile.followersCount, 'follower'),
                    _stat(profile.likesCount, 'thích'),
                  ],
                ),
                const SizedBox(height: 16),
                if (!profile.isSelf) _buildActions(profile),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildTabStrip()),
        _buildGrid(),
      ],
    );
  }

  Widget _stat(int value, String label) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatCompactCount(value),
            style: const TextStyle(color: AppPalette.textPrimary, fontWeight: FontWeight.w800),
          ),
          TextSpan(text: ' $label', style: const TextStyle(color: AppPalette.textSecondary)),
        ],
      ),
      style: const TextStyle(fontSize: 13.5),
    );
  }

  Widget _buildActions(PublicProfile profile) {
    final following = profile.isFollowing;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: _isFollowBusy ? null : _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: following ? AppPalette.surface : AppPalette.accent,
                foregroundColor: AppPalette.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isFollowBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      following ? 'Đang theo dõi' : 'Theo dõi',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 46,
            child: OutlinedButton(
              onPressed: _showMessageComingSoon,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.textPrimary,
                side: const BorderSide(color: AppPalette.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Nhắn tin', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabStrip() {
    return Column(
      children: [
        const SizedBox(
          height: 44,
          child: Center(
            child: Icon(Icons.grid_view_rounded, size: 20, color: AppPalette.textPrimary),
          ),
        ),
        Container(height: 1.5, color: const Color(0xFF38BDF8)),
      ],
    );
  }

  Widget _buildGrid() {
    if (_videos.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text('Chưa có video nào', style: TextStyle(color: AppPalette.textSecondary)),
        ),
      );
    }
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _VideoTile(post: _videos[index], onTap: () => _openVideo(index)),
        childCount: _videos.length,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
        childAspectRatio: 0.72,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final String name;

  const _Avatar({required this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final fallback = Center(
      child: Text(
        initial,
        style: const TextStyle(color: AppPalette.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
      ),
    );
    return Container(
      width: 76,
      height: 76,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppPalette.surfaceHigh),
      child: url.isEmpty
          ? fallback
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final VideoPost post;
  final VoidCallback onTap;

  const _VideoTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final views = int.tryParse('${post.shareCount}') ?? 0;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppPalette.surface),
          if (post.backgroundImageUrl.isNotEmpty)
            Image.network(
              post.backgroundImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Row(
              children: [
                const Icon(Icons.play_arrow_rounded, size: 14, color: AppPalette.textPrimary),
                const SizedBox(width: 2),
                Text(
                  formatCompactCount(views),
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
