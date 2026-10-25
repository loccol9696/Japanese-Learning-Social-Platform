import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../chat/data/models/chat_models.dart';
import '../../../chat/presentation/widgets/chat_avatar.dart';
import '../../data/follow_models.dart';
import '../../data/follow_service.dart';
import 'user_profile_screen.dart';

/// Quản lý theo dõi: người đang theo dõi mình (theo dõi lại được) và người mình đang theo dõi
/// (bỏ theo dõi được).
class FollowManageScreen extends StatefulWidget {
  /// Tab mở sẵn: 0 = người theo dõi bạn, 1 = người bạn đang theo dõi.
  final int initialTab;

  const FollowManageScreen({super.key, this.initialTab = 0});

  @override
  State<FollowManageScreen> createState() => _FollowManageScreenState();
}

class _FollowManageScreenState extends State<FollowManageScreen>
    with SingleTickerProviderStateMixin {
  final _service = FollowService();
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab == 1 ? 1 : 0,
  );

  List<FollowUser> _followers = const [];
  List<FollowUser> _following = const [];
  bool _loading = true;
  String? _error;

  /// Người đang được xử lý (khoá nút để không bấm đúp).
  final Set<int> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final results = await Future.wait([
        _service.fetchFollowers(),
        _service.fetchFollowing(),
      ]);
      if (!mounted) return;
      setState(() {
        _followers = results[0];
        _following = results[1];
      });
    } on ApiException catch (error) {
      if (mounted && !silent) setState(() => _error = error.message);
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _error = 'Không tải được danh sách theo dõi');
      }
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _followBack(FollowUser user) async {
    if (!_busyIds.add(user.id)) return;
    setState(() {});
    try {
      await _service.follow(user.id);
      if (mounted) {
        AppToast.showSuccess('Đã theo dõi ${user.name}', context: context);
      }
      await _load(silent: true);
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
    } finally {
      _busyIds.remove(user.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _unfollow(FollowUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppPalette.surface,
        title: Text(
          'Bỏ theo dõi?',
          style: TextStyle(color: AppPalette.textPrimary),
        ),
        content: Text(
          'Bạn sẽ không còn theo dõi ${user.name}.',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Huỷ',
              style: TextStyle(color: AppPalette.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Bỏ theo dõi',
              style: TextStyle(color: AppPalette.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || !_busyIds.add(user.id)) return;
    setState(() {});
    try {
      await _service.unfollow(user.id);
      await _load(silent: true);
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
    } finally {
      _busyIds.remove(user.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _openProfile(FollowUser user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            UserProfileScreen(userId: user.id, initialName: user.name),
      ),
    );
    // Có thể đã theo dõi / bỏ theo dõi ở trang cá nhân đó.
    if (mounted) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        title: const Text('Quản lý theo dõi'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppPalette.textPrimary,
          unselectedLabelColor: AppPalette.textSecondary,
          indicatorColor: AppPalette.info,
          dividerColor: AppPalette.border,
          tabs: [
            Tab(text: 'Theo dõi bạn (${_followers.length})'),
            Tab(text: 'Đang theo dõi (${_following.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(color: AppPalette.textSecondary),
                  ),
                  TextButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [
                _buildList(_followers, empty: 'Chưa có ai theo dõi bạn.'),
                _buildList(_following, empty: 'Bạn chưa theo dõi ai.'),
              ],
            ),
    );
  }

  Widget _buildList(List<FollowUser> users, {required String empty}) {
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      color: AppPalette.accent,
      child: users.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 96, 32, 0),
                  child: Text(
                    empty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length,
              itemBuilder: (_, index) => _buildRow(users[index]),
            ),
    );
  }

  Widget _buildRow(FollowUser user) {
    final avatarUser = ChatUser(
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
    );
    return InkWell(
      onTap: () => _openProfile(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChatAvatar(user: avatarUser, radius: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildAction(user),
          ],
        ),
      ),
    );
  }

  Widget _buildAction(FollowUser user) {
    final busy = _busyIds.contains(user.id);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    );
    const padding = EdgeInsets.symmetric(horizontal: 14);
    const minSize = Size(0, 36);

    if (user.isFollowing) {
      return OutlinedButton(
        onPressed: busy ? null : () => _unfollow(user),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.textPrimary,
          side: BorderSide(color: AppPalette.border),
          shape: shape,
          padding: padding,
          minimumSize: minSize,
        ),
        child: Text(user.isFollowedBy ? 'Bạn bè' : 'Bỏ theo dõi'),
      );
    }
    return FilledButton(
      onPressed: busy ? null : () => _followBack(user),
      style: FilledButton.styleFrom(
        backgroundColor: AppPalette.accent,
        foregroundColor: AppPalette.onAccent,
        shape: shape,
        padding: padding,
        minimumSize: minSize,
      ),
      child: Text(user.isFollowedBy ? 'Theo dõi lại' : 'Theo dõi'),
    );
  }
}
