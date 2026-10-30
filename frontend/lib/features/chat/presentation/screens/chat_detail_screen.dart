import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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
import '../route_visibility.dart';
import '../widgets/chat_avatar.dart';
import '../widgets/chat_image_viewer.dart';
import '../widgets/confirm_block_dialog.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_study_sheet.dart';
import '../widgets/message_swipe.dart';
import 'messages_tab.dart';
import 'shared_video_screen.dart';

/// Khung chat 1-1. Danh sách tin được giữ theo thứ tự mới nhất trước và hiển thị
/// bằng ListView đảo ngược, nên tin mới luôn nằm sát ô nhập.
///
/// Thao tác: chạm tin để xem giờ và nút tra từ/dịch, giữ lâu để mở menu, vuốt tin sang
/// phải để trả lời, kéo khung chat sang trái để xem giờ mọi tin, vuốt danh sách để ẩn
/// bàn phím.
class ChatDetailScreen extends StatefulWidget {
  final Conversation conversation;
  final ChatService? service;

  const ChatDetailScreen({super.key, required this.conversation, this.service});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with TickerProviderStateMixin {
  static const Duration _typingIdle = Duration(seconds: 3);
  static const Duration _typingExpire = Duration(seconds: 5);

  /// Báo lại "đang nhập" đều đặn khi gõ liên tục, nhanh hơn [_typingExpire] của bên nhận.
  static const Duration _typingHeartbeat = Duration(seconds: 3);
  static const Duration _recallWindow = Duration(hours: 24);

  /// Tin cùng một người gửi cách nhau trong khoảng này được gộp thành một nhóm.
  static const Duration _groupWindow = Duration(minutes: 2);

  /// Cuộn lên quá khoảng này thì hiện nút về tin mới nhất.
  static const double _jumpButtonOffset = 240;

  late final ChatService _service = widget.service ?? ChatService();
  final _socket = ChatSocketService.instance;
  final _hub = ChatHub.instance;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _inputFocus = FocusNode();
  late final AnimationController _timeReveal = AnimationController(vsync: this);
  late final AnimationController _replySwipe = AnimationController(vsync: this);

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
  DateTime? _typingSentAt;
  int _sendCounter = 0;

  /// Người dùng đang thật sự nhìn thấy khung chat này.
  bool _viewing = false;
  bool _insideMessagesTab = false;

  final Map<int, String> _translations = {};
  final Set<int> _shownTranslations = {};
  final Set<int> _translating = {};

  /// Tin đang mở giờ gửi và nút thao tác (chạm vào tin).
  int? _detailsMessageId;

  /// Tin đang được trả lời, hiện trên ô nhập.
  ChatMessage? _replyingTo;

  /// Tin dưới ngón tay khi bắt đầu vuốt.
  ChatMessage? _swipedMessage;

  final Map<int, GlobalKey> _messageKeys = {};

  /// Tin gốc vừa được cuộn tới, nháy sáng một lúc để dễ nhận ra.
  int? _highlightedId;
  Timer? _highlightTimer;

  bool _showJumpButton = false;

  /// Số tin mới đến trong lúc đang cuộn xem tin cũ.
  int _unseenBelow = 0;

  int get _myId => AuthSession.instance.user?.id ?? 0;
  int get _conversationId => _conversation.id;
  bool get _canMessage => _conversation.canMessage;

  @override
  void initState() {
    super.initState();
    _hub.appInForeground.addListener(_updateViewing);
    _hub.messagesTabVisible.addListener(_updateViewing);
    _scroll.addListener(_onScroll);
    _subscriptions
      ..add(_socket.onMessage.listen(_onIncomingMessage))
      ..add(_socket.onRecalled.listen(_onRecalled))
      ..add(_socket.onRead.listen(_onReadReceipt))
      ..add(_socket.onTyping.listen(_onTyping))
      ..add(
        _socket.onConnectionChanged.listen((connected) {
          // Có thể đã lỡ tin trong lúc mất kết nối → kéo bù phần còn thiếu.
          if (connected) unawaited(_syncMissed());
        }),
      );
    _loadInitial();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _insideMessagesTab = MessagesTabScope.isInside(context);
    _updateViewing();
  }

  @override
  void dispose() {
    _hub.appInForeground.removeListener(_updateViewing);
    _hub.messagesTabVisible.removeListener(_updateViewing);
    if (_hub.activeConversationId == _conversationId) {
      _hub.activeConversationId = null;
    }
    if (_iAmTyping) _socket.sendTyping(_conversationId, false);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _otherTypingTimer?.cancel();
    _myTypingTimer?.cancel();
    _highlightTimer?.cancel();
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    _timeReveal.dispose();
    _replySwipe.dispose();
    super.dispose();
  }

  /// Chỉ tính là đang xem khi app ở trước mặt, tab Tin nhắn đang chọn (nếu chat nằm
  /// trong tab) và không có màn nào đè lên. Quay lại xem thì đánh dấu đã đọc phần vừa lỡ.
  void _updateViewing() {
    if (!mounted) return;
    final viewing =
        _hub.appInForeground.value &&
        (!_insideMessagesTab || _hub.messagesTabVisible.value) &&
        isRouteChainCurrent(context);
    if (viewing == _viewing) return;
    _viewing = viewing;
    if (viewing) {
      _hub.activeConversationId = _conversationId;
      _markReadLatest();
    } else if (_hub.activeConversationId == _conversationId) {
      _hub.activeConversationId = null;
    }
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

  /// Id tin mới nhất đã có trên server trong danh sách (bỏ qua tin đang gửi / lỗi).
  int? _latestServerId() {
    for (final message in _messages) {
      if (message.id != null) return message.id;
    }
    return null;
  }

  /// Lấy phần đã lỡ sau khi kết nối lại: kéo tuần tự mọi tin có id lớn hơn tin mới
  /// nhất đang có, nên không để lại khoảng trống dù offline lâu. Chưa có tin nào thì
  /// lấy trang mới nhất như lúc mở màn hình.
  Future<void> _syncMissed() async {
    try {
      var after = _latestServerId();
      while (true) {
        final page = await _service.fetchMessages(
          _conversationId,
          after: after,
        );
        if (!mounted) return;
        setState(() {
          // `after` trả cũ → mới, còn lần lấy trang đầu trả mới → cũ; _upsert tự xếp
          // đúng chỗ theo id nên thứ tự duyệt không ảnh hưởng.
          for (final message in page.messages) {
            _upsert(message);
          }
        });
        final next = page.nextCursor;
        if (after == null || !page.hasMore || next == null || next <= after) {
          break;
        }
        after = next;
      }
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
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 200) _loadMore();

    final showJump = position.pixels > _jumpButtonOffset;
    if (showJump != _showJumpButton) {
      setState(() {
        _showJumpButton = showJump;
        if (!showJump) _unseenBelow = 0;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Sự kiện realtime
  // ---------------------------------------------------------------------------

  void _onIncomingMessage(ChatMessage message) {
    if (message.conversationId != _conversationId || !mounted) return;
    setState(() {
      _upsert(message);
      if (message.senderId != _myId) {
        _setOtherTyping(false);
        if (_showJumpButton) _unseenBelow++;
      }
    });
    if (message.senderId != _myId) _markReadLatest();
  }

  void _onRecalled(ChatMessage message) {
    if (message.conversationId != _conversationId || !mounted) return;
    setState(() {
      _upsert(message);
      _translations.remove(message.id);
      _shownTranslations.remove(message.id);
      if (_replyingTo?.id == message.id) _replyingTo = null;
      for (var i = 0; i < _messages.length; i++) {
        if (_messages[i].replyTo?.id == message.id) {
          _messages[i] = _messages[i].copyWith(
            replyTo: MessageReply.of(message),
          );
        }
      }
    });
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

  /// Đánh dấu đã đọc tới tin mới nhất của đối phương (nếu có), chỉ khi đang xem.
  void _markReadLatest() {
    if (!_viewing) return;
    for (final message in _messages) {
      if (message.id != null && message.senderId != _myId) {
        unawaited(_hub.markRead(_conversationId, message.id!));
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
    final sentAt = _typingSentAt;
    if (!_iAmTyping ||
        sentAt == null ||
        DateTime.now().difference(sentAt) >= _typingHeartbeat) {
      _iAmTyping = true;
      _typingSentAt = DateTime.now();
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
      clientMsgId: _newClientMsgId(),
      replyTo: _takeReplyTarget(),
    );
    setState(() => _upsert(pending));
    _scrollToBottom();
    unawaited(_deliver(pending));
  }

  /// Trích dẫn cho tin sắp gửi; gửi xong thì thôi trả lời.
  MessageReply? _takeReplyTarget() {
    final target = _replyingTo;
    _replyingTo = null;
    return target == null ? null : MessageReply.of(target);
  }

  String _newClientMsgId() =>
      '$_myId-${DateTime.now().microsecondsSinceEpoch}-${_sendCounter++}';

  Future<void> _pickImage() async {
    final XFile? photo;
    try {
      photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) {
        AppToast.showError('Không mở được thư viện ảnh.', context: context);
      }
      return;
    }
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;

    final pending = ChatMessage.pendingImage(
      conversationId: _conversationId,
      senderId: _myId,
      bytes: bytes,
      clientMsgId: _newClientMsgId(),
      replyTo: _takeReplyTarget(),
    );
    setState(() => _upsert(pending));
    _scrollToBottom();
    unawaited(_deliverImage(pending));
  }

  /// Tải ảnh lên rồi gửi tin. Tải xong thì giữ lại URL để gửi lại không phải tải lần nữa.
  Future<void> _deliverImage(ChatMessage pending) async {
    try {
      var imageUrl = pending.imageUrl;
      if (imageUrl.isEmpty) {
        imageUrl = await _service.uploadImage(pending.localImage!, 'chat.jpg');
        if (mounted) {
          setState(
            () => _replacePending(
              pending.clientMsgId,
              (m) => m.copyWith(imageUrl: imageUrl),
            ),
          );
        }
      }
      final sent = await _hub.sendImage(
        conversationId: _conversationId,
        imageUrl: imageUrl,
        clientMsgId: pending.clientMsgId,
        replyToId: pending.replyTo?.id,
      );
      if (mounted) setState(() => _upsert(sent));
    } on ApiException catch (error) {
      _markFailed(pending, error);
    } on FormatException catch (_) {
      _markFailed(
        pending,
        ApiException(statusCode: 500, message: 'Không tải được ảnh lên.'),
      );
    }
  }

  void _replacePending(
    String clientMsgId,
    ChatMessage Function(ChatMessage) update,
  ) {
    final index = _messages.indexWhere((m) => m.clientMsgId == clientMsgId);
    if (index >= 0) _messages[index] = update(_messages[index]);
  }

  Future<void> _deliver(ChatMessage pending) async {
    try {
      final sent = await _hub.sendText(
        conversationId: _conversationId,
        content: pending.content,
        clientMsgId: pending.clientMsgId,
        replyToId: pending.replyTo?.id,
      );
      if (mounted) setState(() => _upsert(sent));
    } on ApiException catch (error) {
      _markFailed(pending, error);
    }
  }

  void _markFailed(ChatMessage pending, ApiException error) {
    if (!mounted) return;
    setState(() {
      _replacePending(
        pending.clientMsgId,
        (m) => m.copyWith(status: MessageStatus.failed),
      );
      // Server từ chối vì không còn follow lẫn nhau hoặc đã bị chặn → khoá ô nhập.
      if (error.statusCode == 403) {
        _conversation = _conversation.copyWith(canMessage: false);
      }
    });
    AppToast.showError(error.message, context: context);
  }

  void _retry(ChatMessage failed) {
    final index = _messages.indexWhere(
      (m) => m.clientMsgId == failed.clientMsgId,
    );
    if (index < 0) return;
    setState(
      () => _messages[index] = failed.copyWith(status: MessageStatus.sending),
    );
    unawaited(
      failed.type == MessageType.image
          ? _deliverImage(failed)
          : _deliver(failed),
    );
  }

  // ---------------------------------------------------------------------------
  // Thao tác trên tin nhắn
  // ---------------------------------------------------------------------------

  bool _canReplyTo(ChatMessage? message) =>
      message != null && message.id != null && !message.recalled && _canMessage;

  void _startReply(ChatMessage message) {
    setState(() => _replyingTo = message);
    _inputFocus.requestFocus();
  }

  String _authorName(int senderId) =>
      senderId == _myId ? 'Bạn' : _conversation.otherUser.name;

  GlobalKey _keyFor(int messageId) =>
      _messageKeys.putIfAbsent(messageId, GlobalKey.new);

  /// Cuộn tới tin gốc. Danh sách chỉ dựng các tin gần màn hình nên cuộn dần lên, tải
  /// thêm tin cũ nếu cần, đến khi tin đó xuất hiện.
  Future<void> _jumpToMessage(int messageId) async {
    for (var attempt = 0; attempt < 40; attempt++) {
      if (!mounted || !_scroll.hasClients) return;
      final target = _messageKeys[messageId]?.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
        );
        if (mounted) _highlight(messageId);
        return;
      }

      final position = _scroll.position;
      if (position.pixels >= position.maxScrollExtent) {
        if (!_hasMore) break;
        await _loadMore();
        continue;
      }
      await _scroll.animateTo(
        (position.pixels + position.viewportDimension * 0.8).clamp(
          0.0,
          position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 120),
        curve: Curves.linear,
      );
    }
    if (mounted) {
      AppToast.showInfo('Không tìm thấy tin nhắn gốc', context: context);
    }
  }

  void _highlight(int messageId) {
    setState(() => _highlightedId = messageId);
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  void _toggleDetails(ChatMessage message) {
    final id = message.id;
    if (id == null) return;
    setState(() => _detailsMessageId = _detailsMessageId == id ? null : id);
  }

  Future<void> _showMessageActions(ChatMessage message) async {
    if (message.id == null || message.recalled) return;
    final canCopy = message.content.isNotEmpty;
    final canStudy = containsJapanese(message.content);
    final translated = _shownTranslations.contains(message.id);
    final canRecall =
        message.senderId == _myId &&
        DateTime.now().difference(message.createdAt) < _recallWindow;
    final canReply = _canReplyTo(message);
    if (!canReply && !canCopy && !canRecall) return;

    unawaited(HapticFeedback.mediumImpact());
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppPalette.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canReply)
              ListTile(
                leading: Icon(
                  Icons.reply_rounded,
                  color: AppPalette.textPrimary,
                ),
                title: Text(
                  'Trả lời',
                  style: TextStyle(color: AppPalette.textPrimary),
                ),
                onTap: () => Navigator.of(sheet).pop(_MessageAction.reply),
              ),
            if (canStudy)
              ListTile(
                leading: Icon(
                  Icons.menu_book_rounded,
                  color: AppPalette.textPrimary,
                ),
                title: Text(
                  'Tra từ',
                  style: TextStyle(color: AppPalette.textPrimary),
                ),
                onTap: () => Navigator.of(sheet).pop(_MessageAction.study),
              ),
            if (canStudy)
              ListTile(
                leading: Icon(
                  Icons.translate_rounded,
                  color: AppPalette.textPrimary,
                ),
                title: Text(
                  translated ? 'Ẩn bản dịch' : 'Dịch',
                  style: TextStyle(color: AppPalette.textPrimary),
                ),
                onTap: () => Navigator.of(sheet).pop(_MessageAction.translate),
              ),
            if (canCopy)
              ListTile(
                leading: Icon(
                  Icons.copy_rounded,
                  color: AppPalette.textPrimary,
                ),
                title: Text(
                  'Sao chép',
                  style: TextStyle(color: AppPalette.textPrimary),
                ),
                onTap: () => Navigator.of(sheet).pop(_MessageAction.copy),
              ),
            if (canRecall)
              ListTile(
                leading: Icon(Icons.undo_rounded, color: AppPalette.like),
                title: Text(
                  'Thu hồi',
                  style: TextStyle(color: AppPalette.like),
                ),
                onTap: () => Navigator.of(sheet).pop(_MessageAction.recall),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _MessageAction.reply:
        _startReply(message);
      case _MessageAction.study:
        await showMessageStudySheet(context, message.content);
      case _MessageAction.translate:
        await _toggleTranslation(message);
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.content));
        if (mounted) AppToast.showSuccess('Đã sao chép', context: context);
      case _MessageAction.recall:
        await _recall(message);
      case null:
        break;
    }
  }

  Future<void> _recall(ChatMessage message) async {
    try {
      final recalled = await _service.recallMessage(message.id!);
      if (mounted) _onRecalled(recalled);
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
    }
  }

  Future<void> _toggleTranslation(ChatMessage message) async {
    final id = message.id;
    if (id == null) return;
    if (_shownTranslations.contains(id)) {
      setState(() => _shownTranslations.remove(id));
      return;
    }
    if (_translations.containsKey(id)) {
      setState(() => _shownTranslations.add(id));
      return;
    }
    setState(() => _translating.add(id));
    try {
      final translation = await _service.translateMessage(id);
      if (!mounted) return;
      setState(() {
        _translations[id] = translation;
        _shownTranslations.add(id);
      });
    } on ApiException catch (error) {
      if (mounted) AppToast.showError(error.message, context: context);
    } finally {
      if (mounted) setState(() => _translating.remove(id));
    }
  }

  void _openImage(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => ChatImageViewer(url: url),
    );
  }

  Future<void> _toggleBlock() async {
    final user = _conversation.otherUser;
    final blocked = _conversation.blockedByMe;
    if (!blocked && !await confirmBlockUser(context, user)) return;
    try {
      if (blocked) {
        await _service.unblockUser(user.id);
      } else {
        await _service.blockUser(user.id);
        _stopTyping();
      }
      await _refreshConversation();
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
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildBody()),
                if (_showJumpButton) _buildJumpButton(),
              ],
            ),
          ),
          _canMessage ? _buildComposer() : _buildLockedBanner(),
        ],
      ),
    );
  }

  Widget _buildJumpButton() {
    return Positioned(
      right: 12,
      bottom: 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton.filled(
            tooltip: 'Về tin mới nhất',
            onPressed: _scrollToBottom,
            style: IconButton.styleFrom(
              backgroundColor: AppPalette.surfaceHigh,
            ),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppPalette.textPrimary,
            ),
          ),
          if (_unseenBelow > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppPalette.accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _unseenBelow > 99 ? '99+' : '$_unseenBelow',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppPalette.onAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Mở trang cá nhân người đang chat cùng. Không hiện nút Nhắn tin vì đang ở trong
  /// khung chat; quay lại thì làm mới hội thoại vì có thể vừa bỏ theo dõi (khoá chat).
  Future<void> _openProfile() async {
    final user = _conversation.otherUser;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: user.id,
          initialName: user.name,
          showMessageButton: false,
        ),
      ),
    );
    if (mounted) unawaited(_refreshConversation());
  }

  Future<void> _refreshConversation() async {
    try {
      final conversation = await _service.fetchConversation(_conversationId);
      if (mounted) setState(() => _conversation = conversation);
    } on ApiException catch (_) {
      // Giữ trạng thái cũ; lần mở lại hội thoại sẽ làm mới.
    }
  }

  PreferredSizeWidget _buildAppBar() {
    final user = _conversation.otherUser;
    return AppBar(
      backgroundColor: AppPalette.background,
      elevation: 0,
      titleSpacing: 0,
      leading: ModalRoute.of(context)?.canPop == true
          ? IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            )
          : null,
      actions: [
        PopupMenuButton<void>(
          tooltip: 'Tuỳ chọn',
          itemBuilder: (_) => [
            PopupMenuItem<void>(
              onTap: _toggleBlock,
              child: Text(_conversation.blockedByMe ? 'Bỏ chặn' : 'Chặn'),
            ),
          ],
        ),
      ],
      title: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openProfile,
        child: Row(
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_otherTyping)
                    Text(
                      'đang nhập...',
                      style: TextStyle(color: AppPalette.accent, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: MessageSwipeGesture(
        timeReveal: _timeReveal,
        replySwipe: _replySwipe,
        canReply: () => _canReplyTo(_swipedMessage),
        onReply: () => _startReply(_swipedMessage!),
        onSettled: () => _swipedMessage = null,
        child: ListView.builder(
          controller: _scroll,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
            final newer = index > 0 ? _messages[index - 1] : null;
            final older = index + 1 < _messages.length
                ? _messages[index + 1]
                : null;
            final showDay =
                older == null || !isSameDay(older.createdAt, message.createdAt);
            final isMine = message.senderId == _myId;
            final joinsOlder = older != null && _sameGroup(older, message);

            return Padding(
              padding: EdgeInsets.only(top: joinsOlder ? 2 : 12),
              child: Column(
                children: [
                  if (showDay)
                    _DayLabel(label: formatDayLabel(message.createdAt)),
                  Listener(
                    onPointerDown: (_) => _swipedMessage = message,
                    child: AnimatedContainer(
                      key: message.id == null ? null : _keyFor(message.id!),
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color:
                            message.id != null && message.id == _highlightedId
                            ? AppPalette.accent.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ReplySwipeRow(
                        animation: _replySwipe,
                        isActive: () => _swipedMessage?.id == message.id,
                        child: TimeRevealRow(
                          animation: _timeReveal,
                          time: message.createdAt,
                          isMine: isMine,
                          child: MessageBubble(
                            message: message,
                            isMine: isMine,
                            isLastInGroup:
                                newer == null || !_sameGroup(message, newer),
                            showDetails:
                                message.id != null &&
                                message.id == _detailsMessageId,
                            showSeen:
                                isMine &&
                                message.id != null &&
                                message.id == lastMineId &&
                                seenId != null &&
                                seenId >= message.id!,
                            translation:
                                message.id != null &&
                                    _shownTranslations.contains(message.id)
                                ? _translations[message.id]
                                : null,
                            translating: _translating.contains(message.id),
                            onTap: () => _toggleDetails(message),
                            onRetry: () => _retry(message),
                            onOpenVideo: () => _openVideo(message),
                            onOpenImage: () => _openImage(message.imageUrl),
                            onLongPress: () => _showMessageActions(message),
                            onStudy: () =>
                                showMessageStudySheet(context, message.content),
                            onTranslate: () => _toggleTranslation(message),
                            replyAuthor: message.replyTo == null
                                ? ''
                                : _authorName(message.replyTo!.senderId),
                            onOpenReply: () =>
                                _jumpToMessage(message.replyTo!.id),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Hai tin liền nhau cùng người gửi, gửi cách nhau không lâu.
  bool _sameGroup(ChatMessage older, ChatMessage newer) =>
      older.senderId == newer.senderId &&
      newer.createdAt.difference(older.createdAt).abs() < _groupWindow;

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyingTo != null) _buildReplyBar(_replyingTo!),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Gửi ảnh',
                  onPressed: _pickImage,
                  icon: Icon(
                    Icons.image_outlined,
                    color: AppPalette.textSecondary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _inputFocus,
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
          ],
        ),
      ),
    );
  }

  Widget _buildReplyBar(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Icon(Icons.reply_rounded, size: 20, color: AppPalette.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Đang trả lời ${_authorName(message.senderId)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppPalette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  MessageReply.of(message).preview,
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
          IconButton(
            tooltip: 'Huỷ trả lời',
            onPressed: () => setState(() => _replyingTo = null),
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: AppPalette.textSecondary,
            ),
          ),
        ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _conversation.blockedByMe
                  ? 'Bạn đã chặn người này. Bạn vẫn xem lại được lịch sử trò chuyện.'
                  : 'Bạn không thể nhắn tin cho người này. '
                        'Bạn vẫn xem lại được lịch sử trò chuyện.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (_conversation.blockedByMe)
              TextButton(
                onPressed: _toggleBlock,
                child: Text(
                  'Bỏ chặn',
                  style: TextStyle(color: AppPalette.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _MessageAction { reply, study, translate, copy, recall }

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
