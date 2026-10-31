import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../profile/data/repositories/profile_repository_impl.dart';
import '../../../profile/domain/models/topic_model.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../../topic/topic_service.dart';
import '../../data/video_manage_service.dart';
import '../../domain/models/user_video_model.dart';
import '../widgets/video_classification_fields.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/app_toast.dart';

class ModerationQueueScreen extends StatefulWidget {
  final ProfileRepository? repository;
  final VideoManageService? manageService;

  const ModerationQueueScreen({super.key, this.repository, this.manageService});

  @override
  State<ModerationQueueScreen> createState() => _ModerationQueueScreenState();
}

class _ModerationQueueScreenState extends State<ModerationQueueScreen> {
  late final ProfileRepository _repository;
  late final VideoManageService _manage = widget.manageService ?? VideoManageService();
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
      AppToast.showSuccess('Đã phê duyệt video "${video.title}" thành công!', context: context);
      _loadVideos();
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(e.toString().replaceAll('Exception: ', ''), context: context);
    } finally {
      if (mounted) setState(() => _processingIds.remove(video.id));
    }
  }

  /// Sửa chủ đề / hashtag gắn sai hoặc không phù hợp, video giữ nguyên trạng thái duyệt.
  Future<void> _editClassification(UserVideoModel video) async {
    var available = <TopicModel>[];
    try {
      available = await TopicService().fetchTopics();
    } catch (_) {
      // Không tải được danh sách vẫn sửa được hashtag và bỏ chủ đề đang gắn.
    }
    if (!mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ClassificationSheet(
        video: video,
        // Gộp cả chủ đề đang gắn để bỏ được chủ đề admin đã ẩn.
        topics: {...available, ...video.topics}.toList(),
        manage: _manage,
      ),
    );
    if (saved == true && mounted) {
      AppToast.showSuccess('Đã cập nhật phân loại video', context: context);
      _loadVideos();
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
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppPalette.error),
                  SizedBox(width: 8),
                  Text(
                    'Từ chối duyệt video',
                    style: TextStyle(color: AppPalette.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
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
                      Text(
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
                                        : AppPalette.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          )),
                      const SizedBox(height: 12),
                      Text(
                        'Hoặc ghi rõ lý do chi tiết:',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: reasonController,
                        maxLines: 3,
                        style: TextStyle(color: AppPalette.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Nhập lý do gửi đến người đăng...',
                          hintStyle: TextStyle(color: AppPalette.textPrimary.withValues(alpha: 0.3)),
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
                  child: Text('Hủy', style: TextStyle(color: AppPalette.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.error,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final text = reasonController.text.trim();
                    if (text.isEmpty) {
                      AppToast.showError('Vui lòng cung cấp lý do từ chối!', context: context);
                      return;
                    }
                    Navigator.of(ctx).pop(text);
                  },
                  child: Text('Xác nhận từ chối', style: TextStyle(color: AppPalette.textPrimary)),
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
        AppToast.showInfo('Đã từ chối video "${video.title}" do vi phạm.', context: context);
        _loadVideos();
      } catch (e) {
        if (!mounted) return;
        AppToast.showError(e.toString().replaceAll('Exception: ', ''), context: context);
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppPalette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Duyệt Video Bài Học',
          style: TextStyle(color: AppPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
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
                ? Center(child: CircularProgressIndicator(color: AppColors.periwinkle))
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
                      color: isSelected ? AppPalette.onAccent : AppColors.textSecondary,
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
                          Image.network(video.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.video_library_rounded, color: AppPalette.border))
                        else
                          Icon(Icons.video_library_rounded, color: AppPalette.border),
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(color: AppPalette.videoScrim.withValues(alpha: 0.87), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              _formatDuration(video.duration),
                              style: TextStyle(color: AppPalette.onVideo, fontSize: 10, fontWeight: FontWeight.bold),
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
                              style: TextStyle(color: AppColors.periwinkle, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            video.status,
                            style: TextStyle(color: AppPalette.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        video.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppPalette.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (video.description != null && video.description!.isNotEmpty)
                        Text(
                          video.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppPalette.textPrimary.withValues(alpha: 0.6), fontSize: 12),
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
                                  ? Icon(Icons.person, size: 10, color: AppPalette.textSecondary)
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
                      const SizedBox(height: 8),
                      _buildClassification(video),
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
                        foregroundColor: AppPalette.error,
                        side: BorderSide(color: AppPalette.error),
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
                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppPalette.onAccent))
                          : const Icon(Icons.check_rounded, size: 16),
                      label: const Text('Phê duyệt'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.success,
                        foregroundColor: AppPalette.onAccent,
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
                color: AppPalette.error.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Text(
                'Lý do vi phạm: ${video.rejectionReason}',
                style: TextStyle(color: AppPalette.error, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClassification(UserVideoModel video) {
    final labels = [
      ...video.topics.map((t) => t.name),
      ...video.hashtags.map((tag) => '#$tag'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label, style: TextStyle(color: AppPalette.textSecondary, fontSize: 11)),
          ),
        InkWell(
          onTap: () => _editClassification(video),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Text(
              labels.isEmpty ? 'Thêm chủ đề, hashtag' : 'Sửa',
              style: TextStyle(color: AppColors.periwinkle, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fact_check_outlined, size: 54, color: AppPalette.border),
          const SizedBox(height: 12),
          Text(
            _activeStatus == 'PENDING'
                ? 'Không có video nào đang chờ duyệt'
                : 'Hàng đợi trống',
            style: TextStyle(color: AppPalette.textSecondary, fontSize: 15, fontWeight: FontWeight.bold),
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

class _ClassificationSheet extends StatefulWidget {
  final UserVideoModel video;
  final List<TopicModel> topics;
  final VideoManageService manage;

  const _ClassificationSheet({required this.video, required this.topics, required this.manage});

  @override
  State<_ClassificationSheet> createState() => _ClassificationSheetState();
}

class _ClassificationSheetState extends State<_ClassificationSheet> {
  final _fieldsKey = GlobalKey<VideoClassificationFieldsState>();
  late Set<int> _topicIds = widget.video.topics.map((t) => t.id).toSet();
  late List<String> _hashtags = widget.video.hashtags;
  bool _isSaving = false;

  Future<void> _save() async {
    if (_fieldsKey.currentState?.commitPending() == false) return;
    setState(() => _isSaving = true);
    try {
      await widget.manage.updateClassification(widget.video.id, topicIds: _topicIds, hashtags: _hashtags);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.showError(e is ApiException ? e.message : 'Không thể cập nhật phân loại', context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppPalette.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              VideoClassificationFields(
                key: _fieldsKey,
                topics: widget.topics,
                selectedTopicIds: _topicIds,
                onTopicsChanged: (ids) => setState(() => _topicIds = ids),
                hashtags: _hashtags,
                onHashtagsChanged: (tags) => setState(() => _hashtags = tags),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.periwinkle,
                  foregroundColor: AppPalette.onAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_isSaving ? 'Đang lưu...' : 'Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
