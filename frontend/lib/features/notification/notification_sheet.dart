import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/app_toast.dart';
import '../chat/data/models/chat_models.dart';
import '../chat/presentation/screens/shared_video_screen.dart';
import '../chat/presentation/widgets/chat_avatar.dart';
import '../follow/presentation/screens/user_profile_screen.dart';
import 'notification_hub.dart';
import 'notification_model.dart';
import 'notification_service.dart';

/// Mở bảng thông báo từ dưới lên.
Future<void> showNotificationsSheet(BuildContext context, {NotificationService? service}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NotificationSheet(service: service),
  );
}

/// Danh sách thông báo của người dùng; thông báo mới nhận realtime được chèn lên đầu.
class NotificationSheet extends StatefulWidget {
  final NotificationService? service;

  const NotificationSheet({super.key, this.service});

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  late final NotificationService _service =
      widget.service ?? NotificationService();
  final _scrollController = ScrollController();
  final List<AppNotification> _items = [];
  StreamSubscription<AppNotification>? _incomingSub;

  int _page = 0;
  bool _isLast = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _incomingSub = NotificationHub.instance.onIncoming.listen((n) {
      if (!mounted || _items.any((e) => e.id == n.id)) return;
      setState(() => _items.insert(0, n));
    });
    _loadFirstPage();
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = _items.isEmpty;
      _error = null;
    });
    try {
      final result = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = 0;
        _isLast = result.isLast;
      });
      unawaited(NotificationHub.instance.refreshUnread());
    } catch (e) {
      if (mounted) setState(() => _error = _messageOf(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || _isLast) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.fetch(page: _page + 1);
      if (!mounted) return;
      setState(() {
        final known = _items.map((e) => e.id).toSet();
        _items.addAll(result.items.where((e) => !known.contains(e.id)));
        _page += 1;
        _isLast = result.isLast;
      });
    } catch (e) {
      if (mounted) AppToast.showError(_messageOf(e), context: context);
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _markAllRead() async {
    if (!_items.any((e) => !e.isRead)) return;
    try {
      await _service.markAllRead();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < _items.length; i++) {
          _items[i] = _items[i].copyWith(isRead: true);
        }
      });
      NotificationHub.instance.setUnread(0);
    } catch (e) {
      if (mounted) AppToast.showError(_messageOf(e), context: context);
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.isRead) {
      final index = _items.indexWhere((e) => e.id == n.id);
      if (index != -1) setState(() => _items[index] = n.copyWith(isRead: true));
      NotificationHub.instance
          .setUnread(NotificationHub.instance.unreadCount.value - 1);
      // Lỗi mạng ở đây không đáng báo: lần mở sau sẽ đồng bộ lại với server.
      unawaited(_service.markRead(n.id).catchError((_) {}));
    }

    final navigator = Navigator.of(context);
    final actorId = n.actorId;
    final videoId = n.videoId;
    // Đích đến của thông báo; null nghĩa là không có gì để mở nên giữ nguyên bảng.
    final Future<void> Function()? open = switch (n.type) {
      NotificationType.follow when actorId != null => () => navigator.push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: actorId, initialName: n.actorName),
        ),
      ),
      // Màn quản lý đăng tải hiển thị lý do từ chối.
      NotificationType.videoRejected => () => navigator.pushNamed(AppRoutes.myVideosStatus),
      NotificationType.like ||
      NotificationType.comment ||
      NotificationType.reply ||
      NotificationType.videoApproved ||
      NotificationType.reportUpdate when videoId != null => () => navigator.push(
        MaterialPageRoute(builder: (_) => SharedVideoScreen(videoId: videoId)),
      ),
      _ => null,
    };
    if (open == null) return;
    // Đóng bảng trước, rồi mở đích đến trên cùng navigator để không bị chồng lên nhau.
    navigator.pop();
    await open();
  }

  static String _messageOf(Object e) =>
      e is ApiException ? e.message : 'Không thể tải thông báo. Vui lòng thử lại.';

  static String _ago(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Cao khoảng 78% màn hình, giống các bảng từ dưới lên khác.
    final height = MediaQuery.sizeOf(context).height * 0.78;
    final hasUnread = _items.any((e) => !e.isRead);
    return SizedBox(
      height: height,
      child: Material(
        color: AppPalette.navBar,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppPalette.textPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Text(
                    'Thông báo',
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (hasUnread)
                    TextButton(
                      onPressed: _markAllRead,
                      child: Text('Đọc tất cả', style: TextStyle(color: AppPalette.accent)),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close_rounded, color: AppPalette.textPrimary),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppPalette.accent));
    }
    if (_error != null && _items.isEmpty) {
      return _centered(_error!, action: TextButton(
        onPressed: _loadFirstPage,
        child: const Text('Thử lại'),
      ));
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      color: AppPalette.accent,
      child: _items.isEmpty
          ? ListView(children: [SizedBox(
              height: 400,
              child: _centered('Bạn chưa có thông báo nào.'),
            )])
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (_, index) {
                if (index >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                return _buildRow(_items[index]);
              },
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

  Widget _buildRow(AppNotification n) {
    final hasActor = n.actorId != null;
    final avatarUser = ChatUser(
      id: n.actorId ?? 0,
      username: n.actorUsername,
      displayName: n.actorDisplayName,
      avatarUrl: n.actorAvatarUrl,
    );
    return InkWell(
      onTap: () => _open(n),
      child: Container(
        color: n.isRead ? null : AppPalette.accentSoft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasActor)
              ChatAvatar(user: avatarUser, radius: 22)
            else
              CircleAvatar(
                radius: 22,
                backgroundColor: AppPalette.surfaceHigh,
                child: Icon(Icons.notifications_rounded, color: AppPalette.accent),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 14,
                      fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  if (n.message.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      n.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _ago(n.createdAt),
                    style: TextStyle(color: AppPalette.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!n.isRead)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 6),
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppPalette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
