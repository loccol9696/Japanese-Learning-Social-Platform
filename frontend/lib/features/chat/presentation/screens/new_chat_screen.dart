import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/models/chat_models.dart';
import '../../data/services/chat_service.dart';
import '../widgets/chat_avatar.dart';
import 'chat_detail_screen.dart';

/// Chọn một người đang follow lẫn nhau để bắt đầu (hoặc mở lại) cuộc trò chuyện.
class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _service = ChatService();
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
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(conversation: conversation),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _opening = false);
      AppToast.showError(error.message, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        title: const Text('Tin nhắn mới'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
                fillColor: AppPalette.surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Center(
          child: Text(
            'Bạn chỉ có thể nhắn tin cho người đã follow lẫn nhau với bạn.\n'
            'Hãy follow bạn bè và chờ họ follow lại nhé!',
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
