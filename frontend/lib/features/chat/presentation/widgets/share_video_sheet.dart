import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/models/chat_models.dart';
import '../../data/services/chat_service.dart';
import 'chat_avatar.dart';

/// Hàm gửi: chia sẻ nội dung (video, bộ thẻ...) cho [recipientIds] kèm lời nhắn [note].
typedef ShareSender = Future<void> Function(
  ChatService service,
  List<int> recipientIds,
  String note,
);

/// Mở bảng chia sẻ video cho bạn bè (chỉ những người follow lẫn nhau). Chia sẻ cả video, người nhận mở từ đầu.
Future<void> showShareVideoSheet(
  BuildContext context, {
  required String videoId,
}) {
  return showShareSheet(
    context,
    send: (service, recipientIds, note) async {
      final id = int.tryParse(videoId);
      if (id == null) {
        throw ApiException(
          statusCode: 400,
          message: 'Video này chưa thể chia sẻ',
        );
      }
      await service.shareVideo(id, recipientIds: recipientIds, note: note);
    },
  );
}

/// Mở bảng chia sẻ bộ thẻ cho bạn bè (chỉ những người follow lẫn nhau; bộ thẻ phải công khai).
Future<void> showShareDeckSheet(BuildContext context, {required int deckId}) {
  return showShareSheet(
    context,
    send: (service, recipientIds, note) =>
        service.shareDeck(deckId, recipientIds: recipientIds, note: note),
  );
}

/// Bảng chọn bạn bè để chia sẻ một nội dung bất kỳ; việc gửi do [send] thực hiện.
Future<void> showShareSheet(
  BuildContext context, {
  required ShareSender send,
  ChatService? service,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ShareFriendsSheet(send: send, service: service),
  );
}

class ShareFriendsSheet extends StatefulWidget {
  final ShareSender send;

  /// Cho phép test thay dịch vụ chat.
  final ChatService? service;

  const ShareFriendsSheet({super.key, required this.send, this.service});

  @override
  State<ShareFriendsSheet> createState() => _ShareFriendsSheetState();
}

class _ShareFriendsSheetState extends State<ShareFriendsSheet> {
  static const int _maxRecipients = 20;

  late final ChatService _service = widget.service ?? ChatService();
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  final Set<int> _selected = {};

  List<ChatUser> _contacts = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contacts = await _service.fetchContacts();
      if (mounted) setState(() => _contacts = contacts);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ChatUser> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    return _contacts
        .where(
          (u) =>
              u.name.toLowerCase().contains(query) ||
              u.username.toLowerCase().contains(query),
        )
        .toList();
  }

  void _toggle(ChatUser user) {
    setState(() {
      if (_selected.contains(user.id)) {
        _selected.remove(user.id);
      } else if (_selected.length < _maxRecipients) {
        _selected.add(user.id);
      } else {
        AppToast.showInfo(
          'Chỉ chia sẻ tối đa $_maxRecipients người một lần',
          context: context,
        );
      }
    });
  }

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.send(_service, _selected.toList(), _noteController.text);
      if (!mounted) return;
      final count = _selected.length;
      Navigator.of(context).pop();
      AppToast.showSuccess('Đã chia sẻ cho $count người');
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.showError(error.message, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        // Material (không phải Container tô màu) để hiệu ứng chạm của các dòng bạn bè hiển thị.
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.78,
          child: Material(
            color: AppPalette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.textPrimary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                _buildHeader(),
                _buildSearch(),
                Expanded(child: _buildContacts()),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Chia sẻ cho bạn bè',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close, color: AppPalette.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: AppPalette.textPrimary),
        cursorColor: AppPalette.accent,
        decoration: InputDecoration(
          hintText: 'Tìm bạn bè',
          hintStyle: TextStyle(color: AppPalette.textSecondary),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppPalette.textSecondary,
          ),
          filled: true,
          fillColor: AppPalette.surfaceHigh,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildContacts() {
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
    if (_contacts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            'Bạn chỉ có thể chia sẻ cho người đã follow lẫn nhau với bạn.\n'
            'Hãy follow bạn bè để bắt đầu!',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.textSecondary, height: 1.4),
          ),
        ),
      );
    }
    final contacts = _filtered;
    if (contacts.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy ai',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
      );
    }
    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (_, index) {
        final user = contacts[index];
        final selected = _selected.contains(user.id);
        return ListTile(
          onTap: () => _toggle(user),
          leading: ChatAvatar(user: user, radius: 20),
          title: Text(
            user.name,
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '@${user.username}',
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
          ),
          trailing: Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected ? AppPalette.accent : AppPalette.textSecondary,
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _noteController,
              maxLength: 500,
              style: TextStyle(color: AppPalette.textPrimary),
              cursorColor: AppPalette.accent,
              decoration: InputDecoration(
                hintText: 'Thêm lời nhắn (tuỳ chọn)',
                hintStyle: TextStyle(color: AppPalette.textSecondary),
                counterText: '',
                filled: true,
                fillColor: AppPalette.surfaceHigh,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: _selected.isEmpty || _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppPalette.accent,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: _sending
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppPalette.onAccent,
                    ),
                  )
                : Text(_selected.isEmpty ? 'Gửi' : 'Gửi (${_selected.length})'),
          ),
        ],
      ),
    );
  }
}
