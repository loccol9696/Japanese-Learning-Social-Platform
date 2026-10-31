import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/services/video_trash_service.dart';
import '../../domain/models/user_video_model.dart';

/// Thùng rác: video đã xóa, có thể khôi phục hoặc xóa vĩnh viễn trước khi hết hạn lưu.
class DeletedVideosScreen extends StatefulWidget {
  final VideoTrashService? service;

  const DeletedVideosScreen({super.key, this.service});

  @override
  State<DeletedVideosScreen> createState() => _DeletedVideosScreenState();
}

class _DeletedVideosScreenState extends State<DeletedVideosScreen> {
  late final VideoTrashService _service;
  List<UserVideoModel> _videos = const [];
  final Set<int> _busyIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? VideoTrashService();
    _load();
  }

  Future<void> _load() async {
    try {
      final videos = await _service.fetchTrash();
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _error = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _restore(UserVideoModel video) => _run(
    video,
    action: () => _service.restore(video.id),
    successMessage: 'Đã khôi phục video',
    errorPrefix: 'Không thể khôi phục video',
  );

  Future<void> _deletePermanently(UserVideoModel video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa vĩnh viễn video?'),
        content: const Text(
          'Video cùng bình luận và lượt tương tác sẽ bị xóa hẳn. '
          'Bạn không thể hoàn tác thao tác này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa vĩnh viễn'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(
      video,
      action: () => _service.deletePermanently(video.id),
      successMessage: 'Đã xóa vĩnh viễn video',
      errorPrefix: 'Không thể xóa video',
    );
  }

  /// Chạy một thao tác trên [video]; thành công thì video rời khỏi thùng rác.
  Future<void> _run(
    UserVideoModel video, {
    required Future<void> Function() action,
    required String successMessage,
    required String errorPrefix,
  }) async {
    if (_busyIds.contains(video.id)) return;
    setState(() => _busyIds.add(video.id));
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _busyIds.remove(video.id);
        _videos = _videos.where((v) => v.id != video.id).toList();
      });
      AppToast.showSuccess(successMessage, context: context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyIds.remove(video.id));
      AppToast.showError('$errorPrefix: $error', context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppPalette.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Video đã xóa',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppPalette.accent));
    }
    if (_error != null) return _buildMessage(_error!, showRetry: true);
    if (_videos.isEmpty) {
      return _buildMessage(
        'Thùng rác trống. Video bạn xóa được giữ ở đây 30 ngày trước khi bị xóa hẳn.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppPalette.accent,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _videos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, index) => _buildVideoCard(_videos[index]),
      ),
    );
  }

  Widget _buildMessage(String message, {bool showRetry = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: AppPalette.textSecondary,
              size: 48,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (showRetry) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() => _isLoading = true);
                  _load();
                },
                child: const Text('Thử lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(UserVideoModel video) {
    final isBusy = _busyIds.contains(video.id);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppPalette.border.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(video),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${video.commentCount} bình luận · ${video.likeCount} lượt thích',
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _purgeLabel(video),
                      style: TextStyle(
                        color: AppPalette.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isBusy ? null : () => _deletePermanently(video),
                style: TextButton.styleFrom(foregroundColor: AppPalette.error),
                child: const Text('Xóa vĩnh viễn'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: isBusy ? null : () => _restore(video),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.accent,
                  foregroundColor: AppPalette.onAccent,
                ),
                child: const Text('Khôi phục'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(UserVideoModel video) {
    final fallback = Center(
      child: Icon(Icons.video_library_rounded, color: AppPalette.border),
    );
    final thumbnailUrl = video.thumbnailUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 66,
        height: 88,
        color: AppPalette.surfaceHigh,
        child: thumbnailUrl == null || thumbnailUrl.isEmpty
            ? fallback
            : Image.network(
                thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }

  String _purgeLabel(UserVideoModel video) {
    final days = video.daysUntilPurge(DateTime.now());
    if (days == null) return 'Đang trong thùng rác';
    if (days == 0) return 'Sắp bị xóa hẳn';
    return 'Còn $days ngày trước khi xóa hẳn';
  }
}

