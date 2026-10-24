import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../auth/data/auth_session.dart';
import '../../data/models/chat_models.dart';
import '../../data/services/chat_hub.dart';
import '../../data/services/chat_service.dart';
import '../../data/services/chat_socket_service.dart';
import '../chat_format.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/message_bubble.dart';
import 'shared_video_screen.dart';

/// Khung chat 1-1. Danh sách tin được giữ theo thứ tự mới nhất trước và hiển thị
/// bằng ListView đảo ngược, nên tin mới luôn nằm sát ô nhập.
class ChatDetailScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatDetailScreen({super.key, required this.conversation});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const Duration _typingIdle = Duration(seconds: 3);
  static const Duration _typingExpire = Duration(seconds: 5);

  final _service = ChatService();
  final _socket = ChatSocketService.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late Conversation _conversation = widget.conversation;
  final List<ChatMessage> _messages = [];
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _cursor;
  String? _error;

  bool _otherTyping = false;
  Timer? _otherTypingTimer;
  Timer? _myTypingTimer;
  bool _iAmTyping = false;
  int _sendCounter = 0;

  int get _myId => AuthSession.instance.user?.id ?? 0;
  int get _conversationId => _conversation.id;
  bool get _canMessage => _conversation.canMessage;

  @override
  void initState() {
    super.initState();
    ChatHub.instance.activeConversationId = _conversationId;
    _scroll.addListener(_onScroll);
    _subscriptions
      ..add(_socket.onMessage.listen(_onIncomingMessage))
      ..add(_socket.onRead.listen(_onReadReceipt))
      ..add(_socket.onTyping.listen(_onTyping))
      ..add(
        _socket.onConnectionChanged.listen((connected) {
          // Có thể đã lỡ tin trong lúc mất kết nối → đồng bộ lại trang mới nhất.
          if (connected) unawaited(_syncLatest());
        }),
      );
    _loadInitial();
  }

  @override
  void dispose() {
    if (ChatHub.instance.activeConversationId == _conversationId) {
      ChatHub.instance.activeConversationId = null;
    }
    if (_iAmTyping) _socket.sendTyping(_conversationId, false);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _otherTypingTimer?.cancel();
    _myTypingTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Tải dữ liệu
  // ---------------------------------------------------------------------------

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Làm mới hội thoại để có trạng thái canMessage / "đã xem" mới nhất.
      final results = await Future.wait([
        _service.fetchConversation(_conversationId),
        _service.fetchMessages(_conversationId),
      ]);
      if (!mounted) return;
      final conversation = results[0] as Conversation;
      final page = results[1] as MessagePage;
      setState(() {
        _conversation = conversation;
        _messages
          ..clear()
          ..addAll(page.messages);
        _hasMore = page.hasMore;
        _cursor = page.nextCursor;
      });
      _markReadLatest();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Gộp trang mới nhất vào danh sách hiện có (sau khi kết nối lại).
  Future<void> _syncLatest() async {
    try {
      final page = await _service.fetchMessages(_conversationId);
      if (!mounted) return;
      setState(() {
        for (final message in page.messages.reversed) {
          _upsert(message);
        }
      });
      _markReadLatest();
    } on ApiException catch (_) {
      // Bỏ qua: lần kết nối sau sẽ đồng bộ lại.
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (_loadingMore || !_hasMore || cursor == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.fetchMessages(
        _conversationId,
        before: cursor,
      );
      if (!mounted) return;
      setState(() {
        _messages.addAll(page.messages);
        _hasMore = page.hasMore;
        _cursor = page.nextCursor;
      });
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  // ---------------------------------------------------------------------------
  // Sự kiện realtime
  // ---------------------------------------------------------------------------

  void _onIncomingMessage(ChatMessage message) {
    if (message.conversationId != _conversationId || !mounted) return;
    setState(() {
      _upsert(message);
      if (message.senderId != _myId) _setOtherTyping(false);
    });
    if (message.senderId != _myId) _markReadLatest();
  }

  void _onReadReceipt(ReadReceipt receipt) {
    if (receipt.conversationId != _conversationId ||
        receipt.userId == _myId ||
        !mounted) {
      return;
    }
    setState(() {
      _conversation = _conversation.copyWith(
        otherLastReadMessageId: receipt.lastReadMessageId,
      );
    });
  }

  void _onTyping(TypingEvent event) {
    if (event.conversationId != _conversationId ||
        event.userId == _myId ||
        !mounted) {
      return;
    }
    setState(() => _setOtherTyping(event.isTyping));
  }

  void _setOtherTyping(bool typing) {
    _otherTyping = typing;
    _otherTypingTimer?.cancel();
    // Phòng khi sự kiện "ngừng gõ" bị mất.
    if (typing) {
      _otherTypingTimer = Timer(_typingExpire, () {
        if (mounted) setState(() => _otherTyping = false);
      });
    }
  }

  /// Thêm hoặc thay thế tin trong danh sách (khớp theo id hoặc clientMsgId), giữ
  /// thứ tự mới nhất trước. Dùng chung cho tin từ socket, ack và REST nên không
  /// bao giờ bị nhân đôi.
  void _upsert(ChatMessage message) {
    final index = _messages.indexWhere(
      (m) =>
          (message.id != null && m.id == message.id) ||
          (message.clientMsgId.isNotEmpty &&
              m.clientMsgId == message.clientMsgId),
    );
    if (index >= 0) {
      _messages[index] = message;
      return;
    }
    // Tin đang gửi (chưa có id) luôn ở đầu; tin có id xếp theo id giảm dần.
    var position = 0;
    while (position < _messages.length) {
      final existingId = _messages[position].id;
      if (message.id == null ||
          (existingId != null && existingId < message.id!)) {
        break;
      }
      position++;
    }
    _messages.insert(position, message);
  }

  /// Đánh dấu đã đọc tới tin mới nhất của đối phương (nếu có).
  void _markReadLatest() {
    for (final message in _messages) {
      if (message.id != null && message.senderId != _myId) {
        unawaited(ChatHub.instance.markRead(_conversationId, message.id!));
        return;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Gửi tin
  // ---------------------------------------------------------------------------

  void _onInputChanged(String text) {
    setState(() {});
    if (!_canMessage) return;
    if (text.trim().isEmpty) {
      _stopTyping();
      return;
    }
    if (!_iAmTyping) {
      _iAmTyping = true;
      _socket.sendTyping(_conversationId, true);
    }
    _myTypingTimer?.cancel();
    _myTypingTimer = Timer(_typingIdle, _stopTyping);
  }

  void _stopTyping() {
    _myTypingTimer?.cancel();
    if (_iAmTyping) {
      _iAmTyping = false;
      _socket.sendTyping(_conversationId, false);
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || !_canMessage) return;
    _input.clear();
    _stopTyping();

    final pending = ChatMessage.pendingText(
      conversationId: _conversationId,
      senderId: _myId,
      content: text,
      clientMsgId:
          '$_myId-${DateTime.now().microsecondsSinceEpoch}-${_sendCounter++}',
    );
    setState(() => _upsert(pending));
    _scrollToBottom();
    unawaited(_deliver(pending));
  }

  Future<void> _deliver(ChatMessage pending) async {
    try {
      final sent = await ChatHub.instance.sendText(
        conversationId: _conversationId,
        content: pending.content,
        clientMsgId: pending.clientMsgId,
      );
      if (mounted) setState(() => _upsert(sent));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere(
          (m) => m.clientMsgId == pending.clientMsgId,
        );
        if (index >= 0) {
          _messages[index] = _messages[index].copyWith(
            status: MessageStatus.failed,
          );
        }
        // Server từ chối vì không còn follow lẫn nhau → khoá ô nhập.
        if (error.statusCode == 403) {
          _conversation = _conversation.copyWith(canMessage: false);
        }
      });
      AppToast.showError(error.message, context: context);
    }
  }

  void _retry(ChatMessage failed) {
    final index = _messages.indexWhere(
      (m) => m.clientMsgId == failed.clientMsgId,
    );
    if (index < 0) return;
    setState(
      () => _messages[index] = failed.copyWith(status: MessageStatus.sending),
    );
    unawaited(_deliver(failed));
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _openVideo(ChatMessage message) {
    final video = message.video;
    if (video == null || !video.available) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SharedVideoScreen(videoId: video.id, startMs: message.videoStartMs),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Giao diện
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _canMessage ? _buildComposer() : _buildLockedBanner(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final user = _conversation.otherUser;
    return AppBar(
      backgroundColor: AppPalette.background,
      elevation: 0,
      titleSpacing: 0,
      title: Row(
        children: [
          ChatAvatar(user: user, radius: 18),
          const SizedBox(width: 10),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _otherTyping ? 'đang nhập...' : '@${user.username}',
                  style: TextStyle(
                    color: _otherTyping
                        ? AppPalette.accent
                        : AppPalette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            TextButton(onPressed: _loadInitial, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Hãy gửi lời chào đến ${_conversation.otherUser.name} 👋',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.textSecondary),
          ),
        ),
      );
    }

    // Tin cuối cùng của mình mà đối phương đã đọc → "Đã xem".
    final seenId = _conversation.otherLastReadMessageId;
    final lastMineId = _messages
        .where((m) => m.senderId == _myId && m.id != null)
        .map((m) => m.id!)
        .fold<int?>(null, (best, id) => best == null || id > best ? id : best);

    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _messages.length + (_loadingMore ? 1 : 0),
      itemBuilder: (_, index) {
        if (index >= _messages.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final message = _messages[index];
        final older = index + 1 < _messages.length
            ? _messages[index + 1]
            : null;
        final showDay =
            older == null || !isSameDay(older.createdAt, message.createdAt);
        final isMine = message.senderId == _myId;

        return Column(
          children: [
            if (showDay) _DayLabel(label: formatDayLabel(message.createdAt)),
            MessageBubble(
              message: message,
              isMine: isMine,
              showSeen:
                  isMine &&
                  message.id != null &&
                  message.id == lastMineId &&
                  seenId != null &&
                  seenId >= message.id!,
              onRetry: () => _retry(message),
              onOpenVideo: () => _openVideo(message),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComposer() {
    final hasText = _input.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: AppPalette.background,
          border: Border(top: BorderSide(color: AppPalette.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                onChanged: _onInputChanged,
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                textInputAction: TextInputAction.newline,
                style: TextStyle(color: AppPalette.textPrimary),
                cursorColor: AppPalette.accent,
                decoration: InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: TextStyle(color: AppPalette.textSecondary),
                  counterText: '',
                  filled: true,
                  fillColor: AppPalette.surfaceHigh,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: hasText ? _send : null,
              style: IconButton.styleFrom(
                backgroundColor: AppPalette.accent,
                disabledBackgroundColor: AppPalette.surfaceHigh,
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedBanner() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: AppPalette.surface,
        child: Text(
          'Hai bạn không còn theo dõi lẫn nhau nên không thể nhắn tin. '
          'Bạn vẫn xem lại được lịch sử trò chuyện.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  final String label;

  const _DayLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        label,
        style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
      ),
    );
  }
}
