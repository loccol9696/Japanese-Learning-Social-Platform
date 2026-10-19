import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../profile/data/repositories/profile_repository_impl.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../domain/models/user_video_model.dart';

class ModerationQueueScreen extends StatefulWidget {
  final ProfileRepository? repository;

  const ModerationQueueScreen({super.key, this.repository});

  @override
  State<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends State<ModerationQueueScreen> {
  late final ProfileRepository _repository;
  bool _isLoading = true;
  List<UserVideoModel> _videos = [];
  String _activeStatus = 'PENDING';
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        ProfileRepositoryImpl(remoteDataSource: ProfileRemoteDataSourceImpl());
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getModerationVideos(status: _activeStatus);
      if (!mounted) return;
      setState(() {
        _videos = list;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveVideo(UserVideoModel video) async {
    setState(() => _processingIds.add(video.id));
    try {
      await _repository.approveVideo(video.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã phê duyệt video "${video.title}" thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadVideos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(video.id));
    }
  }

  Future<void> _showRejectDialog(UserVideoModel video) async {
    final reasonController = TextEditingController();
    final reasons = [
      'Nội dung vi phạm tiêu chuẩn cộng đồng',
      'Chất lượng âm thanh hoặc video không đạt chuẩn',
      'Vi phạm bản quyền hình ảnh hoặc bài hát',
      'Thông tin ngữ pháp hoặc từ vựng không chính xác',
      'Video không liên quan đến học tiếng Nhật',
    ];

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surfaceCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Text(
                    'Từ chối duyệt video',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chọn lý do từ chối nhanh:',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      ...reasons.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  reasonController.text = r;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: reasonController.text == r
                                      ? AppColors.periwinkle.withValues(alpha: 0.2)
                                      : AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: reasonController.text == r
                                        ? AppColors.periwinkle
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    color: reasonController.text == r
                                        ? AppColors.periwinkle
                                        : Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          )),
                      const SizedBox(height: 12),
                      const Text(
                        'Hoặc ghi rõ lý do chi tiết:',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Nhập lý do gửi đến người đăng...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          filled: true,
                          fillColor: AppColors.surfaceContainerHigh,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final text = reasonController.text.trim();
                    if (text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng cung cấp lý do từ chối!')),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop(text);
                  },
                  child: const Text('Xác nhận từ chối', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _processingIds.add(video.id));
      try {
        await _repository.rejectVideo(video.id, result);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã từ chối video "${video.title}" do vi phạm.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
        _loadVideos();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      } finally {
        if (mounted) setState(() => _processingIds.remove(video.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Duyệt Video Bài Học',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.softSkyBlue),
            onPressed: _loadVideos,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.periwinkle))
                : RefreshIndicator(
                    onRefresh: _loadVideos,
                    color: AppColors.periwinkle,
                    backgroundColor: AppColors.surfaceCard,
                    child: _videos.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _videos.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final video = _videos[index];
                              return _buildModerationCard(video);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final tabs = [
      {'key': 'PENDING', 'label': 'Chờ duyệt'},
      {'key': 'APPROVED', 'label': 'Đã thông qua'},
      {'key': 'REJECTED', 'label': 'Đã từ chối'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: tabs.map((t) {
          final isSelected = _activeStatus == t['key'];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () {
                  setState(() => _activeStatus = t['key']!);
                  _loadVideos();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.periwinkle : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.periwinkle : AppColors.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    t['label']!,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModerationCard(UserVideoModel video) {
    final isProcessing = _processingIds.contains(video.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 90,
                    height: 120,
                    color: AppColors.surfaceContainerHigh,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty)
                          Image.network(video.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.video_library_rounded, color: Colors.white24))
                        else
                          const Icon(Icons.video_library_rounded, color: Colors.white24),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              _formatDuration(video.duration),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.periwinkle.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              video.jlptLevel,
                              style: const TextStyle(color: AppColors.periwinkle, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            video.status,
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (video.description != null && video.description!.isNotEmpty)
                        Text(
                          video.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                        ),
                      const SizedBox(height: 6),
                      if (video.userDisplayName != null || video.username != null)
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 9,
                              backgroundImage: video.userAvatarUrl != null && video.userAvatarUrl!.isNotEmpty
                                  ? NetworkImage(video.userAvatarUrl!)
                                  : null,
                              child: video.userAvatarUrl == null || video.userAvatarUrl!.isEmpty
                                  ? const Icon(Icons.person, size: 10, color: Colors.white54)
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                video.userDisplayName ?? '@${video.username}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.softSkyBlue, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_activeStatus == 'PENDING')
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isProcessing ? null : () => _showRejectDialog(video),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Từ chối'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isProcessing ? null : () => _approveVideo(video),
                      icon: isProcessing
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Phê duyệt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (video.isRejected && video.rejectionReason != null && video.rejectionReason!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Text(
                'Lý do vi phạm: ${video.rejectionReason}',
                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fact_check_outlined, size: 54, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            _activeStatus == 'PENDING'
                ? 'Không có video nào đang chờ duyệt'
                : 'Hàng đợi trống',
            style: const TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
