import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/data/auth_session.dart';
import '../../../follow/presentation/screens/user_profile_screen.dart';
import '../../data/models/chat_models.dart';
import '../../data/services/chat_hub.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/chat_socket_service.dart';
import '../chat_format.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_dialogs.dart';
import 'chat_detail_screen.dart';
import 'new_chat_screen.dart';

/// Hộp thư: danh sách hội thoại, mới nhất trước, cập nhật realtime qua Socket.IO.
///
/// Thao tác: kéo xuống để làm mới, vuốt phải để đánh dấu đã đọc, vuốt trái để xoá đoạn
/// chat, giữ lâu để mở menu.
class InboxScreen extends StatefulWidget {
  final ChatService? service;

  const InboxScreen({super.key, this.service});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late final ChatService _service = widget.service ?? ChatService();
  final _socket = ChatSocketService.instance;
  final _search = TextEditingController();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<Conversation> _conversations = const [];
  bool _loading = true;
  String? _error;
  bool _online = ChatSocketService.instance.isConnected;

  int get _myId => AuthSession.instance.user?.id ?? 0;

  /// Hội thoại khớp ô tìm kiếm theo tên hoặc username.
  List<Conversation> get _visibleConversations {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _conversations;
    return _conversations.where((conversation) {
      final user = conversation.otherUser;
      return user.name.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(_socket.onMessage.listen(_onMessage))
      ..add(_socket.onRecalled.listen(_onRecalled))
      ..add(_socket.onCleared.listen(_removeConversation))
      ..add(
        _socket.onConnectionChanged.listen((connected) {
          if (!mounted) return;
          setState(() => _online = connected);
          if (connected) unawaited(_load(silent: true));
        }),
      );
    _load();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _search.dispose();
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
      final conversations = await _service.fetchConversations();
      if (mounted) setState(() => _conversations = conversations);
      unawaited(ChatHub.instance.refreshUnread());
    } on ApiException catch (error) {
      if (mounted && !silent) setState(() => _error = error.message);
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  void _onMessage(ChatMessage message) {
    if (!mounted) return;
    final index = _conversations.indexWhere(
      (c) => c.id == message.conversationId,
    );
    if (index < 0) {
      // Hội thoại mới (chưa có trong danh sách) → tải lại để có thông tin người gửi.
      unawaited(_load(silent: true));
      return;
    }
    final fromOther = message.senderId != _myId;
    final viewing =
        ChatHub.instance.activeConversationId == message.conversationId;
    final updated = _conversations[index].copyWith(
      lastMessage: message,
      lastMessageAt: message.createdAt,
      unreadCount: fromOther && !viewing
          ? _conversations[index].unreadCount + 1
          : null,
    );
    setState(() {
      _conversations = [
        updated,
        ..._conversations.where((c) => c.id != updated.id),
      ];
    });
  }

  void _onRecalled(ChatMessage message) {
    if (!mounted) return;
    setState(() {
      _conversations = [
        for (final c in _conversations)
          c.lastMessage?.id == message.id
              ? c.copyWith(lastMessage: message)
              : c,
      ];
    });
  }

  void _removeConversation(int conversationId) {
    if (!mounted) return;
    setState(() {
      _conversations = _conversations
          .where((c) => c.id != conversationId)
          .toList();
    });
    unawaited(ChatHub.instance.refreshUnread());
  }

  void _setUnreadCleared(Conversation conversation) {
    setState(() {
      _conversations = [
        for (final c in _conversations)
          c.id == conversation.id ? c.copyWith(unreadCount: 0) : c,
      ];
    });
  }

  Future<void> _openConversation(Conversation conversation) async {
    FocusScope.of(context).unfocus();
    // Vào xem là đã đọc → bỏ số chưa đọc ngay trên giao diện.
    _setUnreadCleared(conversation);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(conversation: conversation),
      ),
    );
    if (mounted) unawaited(_load(silent: true));
  }

  Future<void> _newChat() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NewChatScreen()));
    if (mounted) unawaited(_load(silent: true));
  }

  void _markRead(Conversation conversation) {
    final lastId = conversation.lastMessage?.id;
    if (lastId == null) return;
    _setUnreadCleared(conversation);
    unawaited(ChatHub.instance.markRead(conversation.id, lastId));
  }

  Future<void> _toggleBlock(Conversation conversation) async {
    final user = conversation.otherUser;
    final blocked = conversation.blockedByMe;
    if (!blocked && !await confirmBlockUser(context, user)) return;
    try {
      if (blocked) {
        await _service.unblockUser(user.id);
      } else {
        await _service.blockUser(user.id);
      }
      await _load(silent: true);
      if (mounted) {
        AppToast.showSuccess(
          blocked ? 'Đã bỏ chặn ${user.name}' : 'Đã chặn ${user.name}',
          context: context,
        );
      }
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
    }
  }

  /// Hỏi lại rồi xoá trên server; trả về true nếu đã xoá.
  Future<bool> _deleteConversation(Conversation conversation) async {
    if (!await confirmDeleteConversation(context, conversation.otherUser)) {
      return false;
    }
    try {
      await _service.deleteConversation(conversation.id);
      return true;
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
      return false;
    }
  }

  Future<void> _openProfile(Conversation conversation) async {
    final user = conversation.otherUser;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            UserProfileScreen(userId: user.id, initialName: user.name),
      ),
    );
    if (mounted) unawaited(_load(silent: true));
  }

  Future<void> _showActions(Conversation conversation) async {
    unawaited(HapticFeedback.mediumImpact());
    final action = await showModalBottomSheet<_ConversationAction>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppPalette.surface,
      builder: (sheet) {
        Widget item(
          IconData icon,
          String label,
          _ConversationAction action, {
          Color? color,
        }) {
          final tint = color ?? AppPalette.textPrimary;
          return ListTile(
            leading: Icon(icon, color: tint),
            title: Text(label, style: TextStyle(color: tint)),
            onTap: () => Navigator.of(sheet).pop(action),
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (conversation.unreadCount > 0)
                item(
                  Icons.done_all_rounded,
                  'Đánh dấu đã đọc',
                  _ConversationAction.markRead,
                ),
              item(
                Icons.person_outline_rounded,
                'Xem trang cá nhân',
                _ConversationAction.profile,
              ),
              item(
                Icons.block_rounded,
                conversation.blockedByMe ? 'Bỏ chặn' : 'Chặn',
                _ConversationAction.block,
              ),
              item(
                Icons.delete_outline_rounded,
                'Xóa đoạn chat',
                _ConversationAction.delete,
                color: AppPalette.like,
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    switch (action) {
      case _ConversationAction.markRead:
        _markRead(conversation);
      case _ConversationAction.profile:
        await _openProfile(conversation);
      case _ConversationAction.block:
        await _toggleBlock(conversation);
      case _ConversationAction.delete:
        if (await _deleteConversation(conversation)) {
          _removeConversation(conversation.id);
        }
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchField(),
            if (!_online) _buildOfflineBanner(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tin nhắn',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tin nhắn mới',
            onPressed: _newChat,
            icon: Icon(
              Icons.edit_square,
              color: AppPalette.textPrimary,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        style: TextStyle(color: AppPalette.textPrimary),
        cursorColor: AppPalette.accent,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm',
          hintStyle: TextStyle(color: AppPalette.textSecondary),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppPalette.textSecondary,
          ),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Xoá tìm kiếm',
                  onPressed: () => setState(_search.clear),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppPalette.textSecondary,
                  ),
                ),
          filled: true,
          fillColor: AppPalette.surfaceHigh,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: AppPalette.surfaceHigh,
      child: Text(
        'Đang kết nối lại...',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: AppPalette.textSecondary)),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_conversations.isEmpty) return _buildEmpty();

    final conversations = _visibleConversations;
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: conversations.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Không tìm thấy cuộc trò chuyện nào',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppPalette.textSecondary),
                  ),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: conversations.length,
              itemBuilder: (_, index) => _buildRow(conversations[index]),
            ),
    );
  }

  /// Vuốt phải chỉ đánh dấu đã đọc nên hàng trượt về chỗ cũ; vuốt trái xoá đoạn chat,
  /// huỷ hoặc lỗi thì hàng cũng trở về.
  Widget _buildRow(Conversation conversation) {
    return Dismissible(
      key: ValueKey(conversation.id),
      direction: conversation.unreadCount > 0
          ? DismissDirection.horizontal
          : DismissDirection.endToStart,
      background: _SwipeAction(
        alignment: Alignment.centerLeft,
        color: AppPalette.accent,
        foreground: AppPalette.onAccent,
        icon: Icons.done_all_rounded,
        label: 'Đã đọc',
      ),
      secondaryBackground: _SwipeAction(
        alignment: Alignment.centerRight,
        color: AppPalette.like,
        foreground: AppPalette.onAccent,
        icon: Icons.delete_outline_rounded,
        label: 'Xóa',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _markRead(conversation);
          return false;
        }
        return _deleteConversation(conversation);
      },
      onDismissed: (_) => _removeConversation(conversation.id),
      child: _ConversationTile(
        conversation: conversation,
        myId: _myId,
        onTap: () => _openConversation(conversation),
        onLongPress: () => _showActions(conversation),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: AppPalette.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'Chưa có cuộc trò chuyện nào',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn có thể nhắn tin và chia sẻ video cho những người đã follow lẫn nhau.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _newChat,
              style: FilledButton.styleFrom(backgroundColor: AppPalette.accent),
              icon: const Icon(Icons.edit_square, size: 18),
              label: const Text('Bắt đầu trò chuyện'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ConversationAction { markRead, profile, block, delete }

/// Nền hiện ra phía sau hàng hội thoại khi vuốt.
class _SwipeAction extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;

  const _SwipeAction({
    required this.alignment,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: foreground, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final int myId;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ConversationTile({
    required this.conversation,
    required this.myId,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount;
    final last = conversation.lastMessage;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            ChatAvatar(user: conversation.otherUser, radius: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.otherUser.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatConversationTime(conversation.lastMessageAt),
                        style: TextStyle(
                          color: AppPalette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          last?.previewFor(myId) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unread > 0
                                ? AppPalette.textPrimary
                                : AppPalette.textSecondary,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: unread),
                      ],
                    ],
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

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20),
      decoration: BoxDecoration(
        color: AppPalette.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppPalette.onAccent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
