import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../chat/data/models/chat_models.dart';
import '../../../chat/presentation/widgets/chat_avatar.dart';
import '../../data/follow_models.dart';
import '../../data/follow_service.dart';
import '../screens/user_profile_screen.dart';

/// Kết quả tìm người dùng theo [query] (username / tên hiển thị); bấm vào một người để xem
/// trang cá nhân của họ. Ô nhập và việc debounce do màn chứa nó lo: widget này chỉ tải lại
/// khi [query] đổi.
class UserSearchResults extends StatefulWidget {
  /// Từ khoá đã cắt khoảng trắng. Dưới [minQueryLength] ký tự thì chỉ hiện lời nhắc.
  final String query;

  /// Chừa chỗ ở cuối danh sách (ví dụ cho thanh menu dưới nằm đè lên nội dung).
  final double bottomInset;

  final FollowService? service;

  static const int minQueryLength = 2;

  const UserSearchResults({
    super.key,
    required this.query,
    this.bottomInset = 0,
    this.service,
  });

  @override
  State<UserSearchResults> createState() => _UserSearchResultsState();
}

class _UserSearchResultsState extends State<UserSearchResults> {
  late final FollowService _service = widget.service ?? FollowService();

  List<FollowUser> _results = const [];
  bool _loading = false;
  String? _error;

  /// Tăng mỗi lần đổi từ khoá để bỏ qua phản hồi của lượt tìm cũ.
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(covariant UserSearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _search();
  }

  Future<void> _search() async {
    final query = widget.query;
    final seq = ++_requestSeq;
    if (query.length < UserSearchResults.minQueryLength) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
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
    if (_error != null) {
      return _message(
        _error!,
        action: TextButton(onPressed: _search, child: const Text('Thử lại')),
      );
    }
    if (widget.query.length < UserSearchResults.minQueryLength) {
      return _message(
        'Nhập ít nhất ${UserSearchResults.minQueryLength} ký tự để tìm người dùng.',
        icon: Icons.person_search_rounded,
      );
    }
    if (_loading && _results.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppPalette.accent));
    }
    if (_results.isEmpty) {
      return _message(
        'Không tìm thấy người dùng nào cho "${widget.query}".',
        icon: Icons.person_off_outlined,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(bottom: widget.bottomInset),
      itemCount: _results.length,
      itemBuilder: (_, index) => _buildRow(_results[index]),
    );
  }

  Widget _message(String text, {IconData? icon, Widget? action}) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 56, color: AppPalette.textSecondary),
            const SizedBox(height: 12),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 14),
          ),
          ?action,
        ],
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
                    style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
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
