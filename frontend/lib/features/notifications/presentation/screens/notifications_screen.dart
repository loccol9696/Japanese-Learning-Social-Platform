import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/models/notification_models.dart';
import '../../data/services/notification_hub.dart';
import '../../data/services/notification_service.dart';
import '../notification_navigation.dart';
import '../widgets/notification_tile.dart';

/// Màn Thông báo: tab Tương tác (bình luận, thích, chia sẻ) và tab Hệ thống (kết quả duyệt
/// video). Thông báo mới hiện ngay nhờ socket; bấm vào một thông báo để đánh dấu đã đọc và
/// mở video tương ứng.
class NotificationsScreen extends StatefulWidget {
  final NotificationService? service;
  final NotificationHub? hub;

  const NotificationsScreen({super.key, this.service, this.hub});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final NotificationService _service =
      widget.service ?? NotificationService();
  late final NotificationHub _hub = widget.hub ?? NotificationHub.instance;
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            TabBar(
              controller: _tabs,
              labelColor: AppPalette.textPrimary,
              unselectedLabelColor: AppPalette.textSecondary,
              indicatorColor: AppPalette.accent,
              dividerColor: AppPalette.border,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              tabs: [
                Tab(text: appStrings.notificationsInteractions),
                Tab(text: appStrings.notificationsSystem),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _NotificationList(
                    category: NotificationCategory.interaction,
                    service: _service,
                    hub: _hub,
                  ),
                  _NotificationList(
                    category: NotificationCategory.system,
                    service: _service,
                    hub: _hub,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppPalette.textPrimary,
              size: 22,
            ),
          ),
          Expanded(
            child: Text(
              appStrings.notificationsTitle,
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _hub.unreadCount,
            builder: (context, unread, _) => IconButton(
              tooltip: appStrings.notificationsMarkAllRead,
              onPressed: unread > 0 ? () => unawaited(_hub.markAllRead()) : null,
              icon: Icon(
                Icons.done_all_rounded,
                color: unread > 0
                    ? AppPalette.textPrimary
                    : AppPalette.textSecondary.withValues(alpha: 0.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Danh sách của một nhóm: tải theo trang, kéo để làm mới, nhận thông báo mới realtime.
class _NotificationList extends StatefulWidget {
  final NotificationCategory category;
  final NotificationService service;
  final NotificationHub hub;

  const _NotificationList({
    required this.category,
    required this.service,
    required this.hub,
  });

  @override
  State<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<_NotificationList>
    with AutomaticKeepAliveClientMixin {
  final _scroll = ScrollController();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<AppNotification> _items = const [];
  int _nextPage = 0;
  bool _last = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _subscriptions
      ..add(widget.hub.onNew.listen(_onNew))
      ..add(widget.hub.onRead.listen(_onRead))
      ..add(widget.hub.onReadAll.listen((_) => _onReadAll()));
    _load();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _scroll.dispose();
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
      final page = await widget.service.fetchPage(widget.category);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextPage = 1;
        _last = page.isLast;
        _loadMoreFailed = false;
        _error = null;
      });
      _fillViewport();
    } on ApiException catch (error) {
      if (mounted && !silent) setState(() => _error = error.message);
    } on FormatException catch (error) {
      if (mounted && !silent) setState(() => _error = error.message);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _last) return;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final page = await widget.service.fetchPage(
        widget.category,
        page: _nextPage,
      );
      if (!mounted) return;
      // Thông báo mới chèn lên đầu làm lệch trang, nên loại bỏ bản ghi đã có.
      final known = _items.map((n) => n.id).toSet();
      setState(() {
        _items = [..._items, ...page.items.where((n) => !known.contains(n.id))];
        _nextPage += 1;
        _last = page.isLast;
      });
      _fillViewport();
    } on ApiException {
      if (mounted) setState(() => _loadMoreFailed = true);
    } on FormatException {
      if (mounted) setState(() => _loadMoreFailed = true);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  /// Danh sách ngắn hơn màn hình thì không cuộn được nên không có sự kiện cuộn để tải tiếp.
  void _fillViewport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _last || _loadMoreFailed || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 0) unawaited(_loadMore());
    });
  }

  void _onScroll() {
    if (_loadMoreFailed) return;
    if (_scroll.position.extentAfter < 400) unawaited(_loadMore());
  }

  void _onNew(AppNotification notification) {
    if (!mounted || notification.category != widget.category) return;
    if (_items.any((n) => n.id == notification.id)) return;
    setState(() => _items = [notification, ..._items]);
  }

  void _onRead(int id) {
    if (!mounted) return;
    setState(() {
      _items = [for (final n in _items) n.id == id ? n.copyWith(isRead: true) : n];
    });
  }

  void _onReadAll() {
    if (!mounted) return;
    setState(() {
      _items = [for (final n in _items) n.copyWith(isRead: true)];
    });
  }

  Future<void> _open(AppNotification notification) async {
    if (!notification.isRead) unawaited(widget.hub.markRead(notification.id));
    final needsVideo = notification.type != NotificationType.videoRejected;
    if (needsVideo &&
        (!notification.videoAvailable || notification.videoId == null)) {
      AppToast.showInfo(appStrings.notificationVideoUnavailable);
      return;
    }
    await openNotificationTarget(
      context,
      NotificationTarget.fromNotification(notification),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: _items.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _items.length + (_last ? 0 : 1),
      itemBuilder: (_, index) {
        if (index == _items.length) return _buildFooter();
        final notification = _items[index];
        return NotificationTile(
          key: ValueKey(notification.id),
          notification: notification,
          onTap: () => _open(notification),
        );
      },
    );
  }

  Widget _buildFooter() {
    if (_loadMoreFailed) {
      return TextButton(
        onPressed: _loadMore,
        child: Text(appStrings.notificationsLoadMoreError),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final interaction = widget.category == NotificationCategory.interaction;
    // ListView để kéo làm mới được cả khi danh sách trống.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 96, 32, 32),
          child: Column(
            children: [
              Icon(
                interaction
                    ? Icons.favorite_border_rounded
                    : Icons.notifications_none_rounded,
                size: 56,
                color: AppPalette.textSecondary,
              ),
              const SizedBox(height: 14),
              Text(
                interaction
                    ? appStrings.notificationsEmptyInteractions
                    : appStrings.notificationsEmptySystem,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppPalette.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error ?? appStrings.notificationsLoadError,
            style: TextStyle(color: AppPalette.textSecondary),
          ),
          TextButton(
            onPressed: _load,
            child: Text(appStrings.notificationsRetry),
          ),
        ],
      ),
    );
  }
}
