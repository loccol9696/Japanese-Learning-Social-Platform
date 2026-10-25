import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/models/chat_models.dart';
import '../../data/services/chat_service.dart';
import '../chat_format.dart';
import 'chat_avatar.dart';

/// Mở bảng chia sẻ video cho bạn bè (chỉ những người follow lẫn nhau).
///
/// [startMs] là mốc thời gian gợi ý (câu phụ đề đang xem): người nhận bấm vào
/// sẽ mở video đúng đoạn đó.
Future<void> showShareVideoSheet(
  BuildContext context, {
  required String videoId,
  required String title,
  required String thumbnailUrl,
  int startMs = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ShareVideoSheet(
      videoId: videoId,
      title: title,
      thumbnailUrl: thumbnailUrl,
      startMs: startMs,
    ),
  );
}

class _ShareVideoSheet extends StatefulWidget {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final int startMs;

  const _ShareVideoSheet({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.startMs,
  });

  @override
  State<_ShareVideoSheet> createState() => _ShareVideoSheetState();
}

class _ShareVideoSheetState extends State<_ShareVideoSheet> {
  static const int _maxRecipients = 20;

  final _service = ChatService();
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  final Set<int> _selected = {};

  List<ChatUser> _contacts = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  late bool _useTimestamp = widget.startMs >= 1000;

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
    final videoId = int.tryParse(widget.videoId);
    if (videoId == null || _selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.shareVideo(
        videoId,
        recipientIds: _selected.toList(),
        note: _noteController.text,
        startMs: _useTimestamp ? widget.startMs : null,
      );
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
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.78,
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
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
              _buildVideoCard(),
              _buildSearch(),
              Expanded(child: _buildContacts()),
              _buildFooter(),
            ],
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

  Widget _buildVideoCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 44,
                  height: 58,
                  child: widget.thumbnailUrl.isEmpty
                      ? ColoredBox(color: AppPalette.background)
                      : Image.network(
                          widget.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              ColoredBox(color: AppPalette.background),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (widget.startMs >= 1000)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 16,
                    color: AppPalette.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bắt đầu từ ${formatMillis(widget.startMs)}',
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Switch(
                    value: _useTimestamp,
                    activeThumbColor: AppPalette.accent,
                    onChanged: (value) => setState(() => _useTimestamp = value),
                  ),
                ],
              ),
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
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 12,
            ),
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
