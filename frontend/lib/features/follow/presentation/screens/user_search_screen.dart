import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../chat/data/models/chat_models.dart';
import '../../../chat/presentation/widgets/chat_avatar.dart';
import '../../data/follow_models.dart';
import '../../data/follow_service.dart';
import 'user_profile_screen.dart';

/// Tìm người dùng theo username / tên hiển thị, bấm vào để xem trang cá nhân.
class UserSearchScreen extends StatefulWidget {
  final FollowService? service;

  const UserSearchScreen({super.key, this.service});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  static const int _minQueryLength = 2;

  late final FollowService _service = widget.service ?? FollowService();
  final _controller = TextEditingController();
  Timer? _debounce;

  List<FollowUser> _results = const [];
  String _query = '';
  bool _loading = false;
  String? _error;

  // Bỏ qua phản hồi của lượt tìm cũ khi người dùng đã gõ tiếp.
  int _requestSeq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final next = value.trim();
    if (next.length < _minQueryLength) {
      _requestSeq++;
      setState(() {
        _query = next;
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(next));
  }

  Future<void> _search(String query) async {
    final seq = ++_requestSeq;
    setState(() {
      _query = query;
      _loading = true;
      _error = null;
    });
    try {
      final users = await _service.searchUsers(query);
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _results = users;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() {
        _error = 'Không thể tìm kiếm. Vui lòng thử lại.';
        _loading = false;
      });
    }
  }

  void _openProfile(FollowUser user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: user.id, initialName: user.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          cursorColor: AppPalette.accent,
          style: TextStyle(color: AppPalette.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Tìm theo tên hoặc username...',
            hintStyle: TextStyle(color: AppPalette.textSecondary),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) return _message(_error!);
    if (_query.length < _minQueryLength) {
      return _message('Nhập ít nhất $_minQueryLength ký tự để tìm người dùng.');
    }
    if (_loading && _results.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppPalette.accent));
    }
    if (_results.isEmpty) return _message('Không tìm thấy người dùng nào.');

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (_, index) => _buildRow(_results[index]),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
      ),
    ),
  );

  Widget _buildRow(FollowUser user) {
    final avatarUser = ChatUser(
      id: user.id,
      username: user.username,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
    );
    return InkWell(
      onTap: () => _openProfile(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChatAvatar(user: avatarUser, radius: 22),
            const SizedBox(width: 12),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (user.isFollowing)
              Text(
                'Đang theo dõi',
                style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
