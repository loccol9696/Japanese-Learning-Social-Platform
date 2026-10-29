import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/square_add_button.dart';
import '../../../auth/data/auth_session.dart';
import '../../data/models/chat_models.dart';
import '../../data/services/chat_hub.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/chat_socket_service.dart';
import '../chat_format.dart';
import '../widgets/chat_avatar.dart';
import 'chat_detail_screen.dart';
import 'new_chat_sheet.dart';

/// Hộp thư: danh sách hội thoại, mới nhất trước, cập nhật realtime qua Socket.IO.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _service = ChatService();
  final _socket = ChatSocketService.instance;
  final _searchController = TextEditingController();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  List<Conversation> _conversations = const [];
  bool _loading = true;
  String? _error;
  bool _online = ChatSocketService.instance.isConnected;

  int get _myId => AuthSession.instance.user?.id ?? 0;

  @override
  void initState() {
    super.initState();
    _subscriptions
      ..add(_socket.onMessage.listen(_onMessage))
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
    _searchController.dispose();
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

  Future<void> _openConversation(Conversation conversation) async {
    // Vào xem là đã đọc → bỏ số chưa đọc ngay trên giao diện.
    setState(() {
      _conversations = [
        for (final c in _conversations)
          c.id == conversation.id ? c.copyWith(unreadCount: 0) : c,
      ];
    });
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(conversation: conversation),
      ),
    );
    if (mounted) unawaited(_load(silent: true));
  }

  Future<void> _newChat() async {
    final conversation = await showNewChatSheet(context);
    if (!mounted) return;
    if (conversation != null) {
      await _openConversation(conversation);
    } else {
      unawaited(_load(silent: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          'Tin nhắn',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          if (!_online) _buildOfflineBanner(),
          _buildSearchRow(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// Hội thoại khớp ô tìm kiếm: theo tên, @username hoặc nội dung tin cuối.
  List<Conversation> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _conversations;
    return _conversations.where((c) {
      final preview = c.lastMessage?.previewFor(_myId) ?? '';
      return c.otherUser.name.toLowerCase().contains(query) ||
          c.otherUser.username.toLowerCase().contains(query) ||
          preview.toLowerCase().contains(query);
    }).toList();
  }

  /// Ô tìm cuộc trò chuyện + nút "+" soạn tin mới.
  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                key: const ValueKey('inbox-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: AppPalette.textPrimary, fontSize: 15),
                cursorColor: AppPalette.accent,
                decoration: InputDecoration(
                  hintText: 'Tìm cuộc trò chuyện...',
                  hintStyle: TextStyle(
                    color: AppPalette.textPrimary.withValues(alpha: 0.35),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppPalette.textPrimary.withValues(alpha: 0.4),
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SquareAddButton(
            key: const ValueKey('new-chat-button'),
            tooltip: 'Tin nhắn mới',
            onPressed: _newChat,
          ),
        ],
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
            Text(
              _error!,
              style: TextStyle(color: AppPalette.textSecondary),
            ),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_conversations.isEmpty) return _buildEmpty();

    final conversations = _filtered;
    if (conversations.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy cuộc trò chuyện nào',
          key: const ValueKey('inbox-no-match'),
          style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: conversations.length,
        separatorBuilder: (_, _) => const SizedBox.shrink(),
        itemBuilder: (_, index) => _ConversationTile(
          conversation: conversations[index],
          myId: _myId,
          onTap: () => _openConversation(conversations[index]),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Text(
                'Chưa có cuộc trò chuyện nào',
                style: TextStyle(
                  color: AppPalette.textPrimary.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final int myId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.myId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount;
    final last = conversation.lastMessage;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            ChatAvatar(user: conversation.otherUser, radius: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.otherUser.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    last?.previewFor(myId) ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unread > 0
                          ? AppPalette.textPrimary
                          : AppPalette.textSecondary,
                      fontWeight: unread > 0
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatConversationTime(conversation.lastMessageAt),
                  style: TextStyle(
                    color: AppPalette.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                // Chưa đọc: chấm xanh nhỏ dưới giờ (số tin chưa đọc đã có ở huy hiệu tab Tin nhắn).
                if (unread > 0)
                  Container(
                    key: ValueKey('unread-dot-${conversation.id}'),
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppPalette.info,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const SizedBox(height: 9),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
