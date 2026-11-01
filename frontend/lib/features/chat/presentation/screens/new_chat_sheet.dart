import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/models/chat_models.dart';
import '../../data/services/chat_service.dart';
import '../widgets/chat_avatar.dart';

/// Mở bảng "Tin nhắn mới" từ dưới lên. Trả về cuộc trò chuyện đã mở với người được chọn,
/// hoặc null nếu đóng bảng mà không chọn ai; màn gọi tự mở khung chat.
Future<Conversation?> showNewChatSheet(BuildContext context) {
  return showModalBottomSheet<Conversation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const NewChatSheet(),
  );
}

/// Chọn một người đang follow lẫn nhau để bắt đầu (hoặc mở lại) cuộc trò chuyện.
class NewChatSheet extends StatefulWidget {
  const NewChatSheet({super.key, this.service});

  /// Cho phép test thay dịch vụ chat.
  final ChatService? service;

  @override
  State<NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<NewChatSheet> {
  late final ChatService _service = widget.service ?? ChatService();
  final _search = TextEditingController();

  List<ChatUser> _contacts = const [];
  bool _loading = true;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
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
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _contacts;
    return _contacts
        .where(
          (u) =>
              u.name.toLowerCase().contains(query) ||
              u.username.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _open(ChatUser user) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final conversation = await _service.openConversation(user.id);
      if (!mounted) return;
      Navigator.of(context).pop(conversation);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _opening = false);
      AppToast.showError(error.message, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Cao khoảng 62% màn hình; bàn phím hiện thì nâng lên để ô tìm kiếm không bị che.
    final height = media.size.height * 0.62;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
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
                      'Tin nhắn mới',
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close_rounded, color: AppPalette.textPrimary),
                      tooltip: 'Đóng',
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _search,
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
                    fillColor: AppPalette.background,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
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
            Text(
              _error!,
              style: TextStyle(color: AppPalette.textSecondary),
            ),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_contacts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            'Bạn chỉ có thể nhắn tin cho người đã follow lẫn nhau với bạn. '
            'Hãy follow bạn bè và chờ họ follow lại nhé!',
            key: const ValueKey('new-chat-empty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.textSecondary, height: 1.5, fontSize: 13),
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
        return ListTile(
          enabled: !_opening,
          onTap: () => _open(user),
          leading: ChatAvatar(user: user, radius: 22),
          title: Text(
            user.name,
            style: TextStyle(
              color: AppPalette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '@${user.username}',
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }
}
