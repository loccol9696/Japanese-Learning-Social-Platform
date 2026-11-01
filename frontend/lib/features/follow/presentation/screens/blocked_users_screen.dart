import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../chat/data/models/chat_models.dart';
import '../../../chat/presentation/widgets/chat_avatar.dart';
import '../../data/follow_models.dart';
import '../../data/follow_service.dart';

/// Danh sách người đã chặn, kèm nút bỏ chặn.
class BlockedUsersScreen extends StatefulWidget {
  final FollowService? service;

  const BlockedUsersScreen({super.key, this.service});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late final FollowService _service = widget.service ?? FollowService();
  final Set<int> _busyIds = {};

  List<BlockedUser> _users = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _users.isEmpty;
      _error = null;
    });
    try {
      final users = await _service.fetchBlocked();
      if (mounted) setState(() => _users = users);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được danh sách. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(BlockedUser user) async {
    if (!_busyIds.add(user.id)) return;
    setState(() {});
    try {
      await _service.unblock(user.id);
      if (!mounted) return;
      setState(() => _users = _users.where((u) => u.id != user.id).toList());
      AppToast.showSuccess('Đã bỏ chặn ${user.name}', context: context);
    } on ApiException catch (e) {
      if (mounted) AppToast.showError(e.message, context: context);
    } finally {
      _busyIds.remove(user.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        title: const Text('Người đã chặn'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppPalette.accent));
    }
    if (_error != null) {
      return _centered(
        _error!,
        action: TextButton(onPressed: _load, child: const Text('Thử lại')),
      );
    }
    if (_users.isEmpty) {
      return _centered('Bạn chưa chặn ai.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppPalette.accent,
      child: ListView.builder(
        itemCount: _users.length,
        itemBuilder: (_, index) => _buildRow(_users[index]),
      ),
    );
  }

  Widget _centered(String text, {Widget? action}) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
          ),
          ?action,
        ],
      ),
    ),
  );

  Widget _buildRow(BlockedUser user) {
    final avatarUser = ChatUser(
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
    );
    final busy = _busyIds.contains(user.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => _unblock(user),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.textPrimary,
              side: BorderSide(color: AppPalette.border),
            ),
            child: const Text('Bỏ chặn'),
          ),
        ],
      ),
    );
  }
}
