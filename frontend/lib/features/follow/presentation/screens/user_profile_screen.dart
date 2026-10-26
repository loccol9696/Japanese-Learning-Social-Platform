import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../chat/data/models/chat_models.dart';
import '../../../chat/data/services/chat_service.dart';
import '../../../chat/presentation/screens/chat_detail_screen.dart';
import '../../../chat/presentation/screens/shared_video_screen.dart';
import '../../../chat/presentation/widgets/chat_avatar.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../video/domain/models/user_video_model.dart';
import '../../data/follow_models.dart';
import '../../data/follow_service.dart';
import '../../../report/report_service.dart';
import '../../../report/report_sheet.dart';

/// Trang cá nhân công khai của một người dùng khác: thông tin, nút theo dõi và video đã đăng.
class UserProfileScreen extends StatefulWidget {
  final int userId;

  /// Tên hiển thị tạm trên thanh tiêu đề trong lúc tải hồ sơ.
  final String? initialName;

  /// Gọi sau khi theo dõi / bỏ theo dõi thành công (true = đang theo dõi), để màn
  /// đã mở trang này cập nhật nút theo dõi của nó.
  final ValueChanged<bool>? onFollowChanged;

  /// false khi trang được mở từ chính khung chat với người này, tránh chồng hai
  /// khung chat lên nhau.
  final bool showMessageButton;

  /// Nguồn video của người này; mặc định gọi backend, truyền vào để thay trong test.
  final ProfileRemoteDataSource? videoSource;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialName,
    this.onFollowChanged,
    this.showMessageButton = true,
    this.videoSource,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _service = FollowService();
  late final ProfileRemoteDataSource _videoSource =
      widget.videoSource ?? ProfileRemoteDataSourceImpl();
  final _chat = ChatService();

  PublicProfile? _profile;
  List<UserVideoModel> _videos = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchPublicProfile(widget.userId),
        _videoSource.fetchUserVideos(userId: widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as PublicProfile;
        _videos = (results[1] as List<UserVideoModel>)
            .where((v) => v.isApproved && v.isPublic)
            .toList();
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được trang cá nhân');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (profile.isFollowing) {
        await _service.unfollow(profile.id);
      } else {
        await _service.follow(profile.id);
      }
      final nowFollowing = !profile.isFollowing;
      // Báo trước khi kiểm tra mounted: server đã đổi dù người dùng vừa thoát màn.
      widget.onFollowChanged?.call(nowFollowing);
      if (!mounted) return;
      setState(() {
        _profile = profile.copyWith(
          isFollowing: nowFollowing,
          followersCount: profile.followersCount + (nowFollowing ? 1 : -1),
        );
      });
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmBlock(PublicProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppPalette.surface,
        title: Text(
          'Chặn ${profile.name}?',
          style: TextStyle(color: AppPalette.textPrimary),
        ),
        content: Text(
          'Hai bên sẽ không còn theo dõi, nhắn tin hay thấy video, bình luận của nhau. '
          'Bạn có thể bỏ chặn bất cứ lúc nào trong Cài đặt.',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Chặn', style: TextStyle(color: AppPalette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    await _setBlocked(profile, true);
  }

  Future<void> _setBlocked(PublicProfile profile, bool blocked) async {
    setState(() => _busy = true);
    try {
      if (blocked) {
        await _service.block(profile.id);
      } else {
        await _service.unblock(profile.id);
      }
      // Chặn đồng thời bỏ theo dõi hai chiều.
      if (blocked) widget.onFollowChanged?.call(false);
      if (!mounted) return;
      setState(() {
        _profile = profile.copyWith(
          isBlocked: blocked,
          isFollowing: blocked ? false : null,
          followersCount: blocked && profile.isFollowing
              ? profile.followersCount - 1
              : null,
        );
        if (blocked) _videos = const [];
      });
      AppToast.showSuccess(
        blocked ? 'Đã chặn ${profile.name}' : 'Đã bỏ chặn ${profile.name}',
        context: context,
      );
      if (!blocked) await _load();
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Mở (hoặc tạo) hội thoại với người này rồi vào khung chat.
  Future<void> _openChat(PublicProfile profile) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final conversation = await _chat.openConversation(profile.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(conversation: conversation),
        ),
      );
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        title: Text(profile?.name ?? widget.initialName ?? 'Trang cá nhân'),
        actions: [
          if (profile != null && !profile.isSelf)
            PopupMenuButton<String>(
              color: AppPalette.surface,
              icon: Icon(Icons.more_vert_rounded, color: AppPalette.textPrimary),
              onSelected: (value) {
                if (value == 'report') {
                  showReportSheet(
                    context,
                    target: ReportTarget.user,
                    targetId: profile.id,
                    subject: 'người dùng này',
                  );
                } else if (value == 'block') {
                  _confirmBlock(profile);
                } else if (value == 'unblock') {
                  _setBlocked(profile, false);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'report',
                  child: Text(
                    'Báo cáo người dùng',
                    style: TextStyle(color: AppPalette.textPrimary),
                  ),
                ),
                PopupMenuItem(
                  value: profile.isBlocked ? 'unblock' : 'block',
                  child: Text(
                    profile.isBlocked ? 'Bỏ chặn' : 'Chặn người dùng',
                    style: TextStyle(
                      color: profile.isBlocked
                          ? AppPalette.textPrimary
                          : AppPalette.error,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : profile == null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppPalette.accent,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(profile)),
                  _buildVideos(),
                ],
              ),
            ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error ?? 'Không tải được trang cá nhân',
            style: TextStyle(color: AppPalette.textSecondary),
          ),
          TextButton(onPressed: _load, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  Widget _buildHeader(PublicProfile profile) {
    final handle = profile.jlptLevel != null && profile.jlptLevel!.isNotEmpty
        ? '@${profile.username} · ${profile.jlptLevel}'
        : '@${profile.username}';
    final avatarUser = ChatUser(
      id: profile.id,
      username: profile.username,
      displayName: profile.displayName,
      avatarUrl: profile.avatarUrl,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChatAvatar(user: avatarUser, radius: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
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
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              _stat('${profile.followingCount}', 'đang follow'),
              _stat('${profile.followersCount}', 'follower'),
              _stat('${profile.likesCount}', 'thích'),
            ],
          ),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile.bio,
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          if (!profile.isSelf) ...[
            const SizedBox(height: 16),
            _buildActions(profile),
          ],
        ],
      ),
    );
  }

  /// Nút theo dõi; thêm nút Nhắn tin khi hai bên đã follow lẫn nhau (mới được nhắn tin).
  Widget _buildActions(PublicProfile profile) {
    if (profile.isBlocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bạn đã chặn người dùng này.',
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton(
              onPressed: _busy ? null : () => _setBlocked(profile, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.textPrimary,
                side: BorderSide(color: AppPalette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Bỏ chặn'),
            ),
          ),
        ],
      );
    }
    final canMessage =
        widget.showMessageButton && profile.isFollowing && profile.isFollowedBy;
    return Row(
      children: [
        Expanded(child: _buildFollowButton(profile)),
        if (canMessage) ...[
          const SizedBox(width: 10),
          Expanded(child: _buildMessageButton(profile)),
        ],
      ],
    );
  }

  Widget _buildMessageButton(PublicProfile profile) {
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: _busy ? null : () => _openChat(profile),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        label: const Text('Nhắn tin'),
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.accent,
          foregroundColor: AppPalette.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowButton(PublicProfile profile) {
    final following = profile.isFollowing;
    final label = following
        ? (profile.isFollowedBy ? 'Bạn bè' : 'Đang theo dõi')
        : (profile.isFollowedBy ? 'Theo dõi lại' : 'Theo dõi');
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: following
          ? OutlinedButton(
              onPressed: _busy ? null : _toggleFollow,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.textPrimary,
                side: BorderSide(color: AppPalette.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(label),
            )
          : FilledButton(
              onPressed: _busy ? null : _toggleFollow,
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.accent,
                foregroundColor: AppPalette.onAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(label),
            ),
    );
  }

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
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildVideos() {
    if (_videos.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
          child: Center(
            child: Text(
              'Chưa có video nào',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 15),
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(3),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildVideoTile(_videos[index]),
          childCount: _videos.length,
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
    final thumbnail = video.thumbnailUrl;
    final placeholder = Center(
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: AppPalette.border,
        size: 36,
      ),
    );
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SharedVideoScreen(videoId: video.id),
        ),
      ),
      child: Container(
        color: AppPalette.surface,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnail != null && thumbnail.isNotEmpty)
              Image.network(
                thumbnail,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              )
            else
              placeholder,
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
