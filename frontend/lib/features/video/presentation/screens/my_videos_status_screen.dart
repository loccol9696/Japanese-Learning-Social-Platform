import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/video_manage_service.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../profile/data/repositories/profile_repository_impl.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../domain/models/user_video_model.dart';
import '../../../../core/theme/app_palette.dart';

class MyVideosStatusScreen extends StatefulWidget {
  final ProfileRepository? repository;

  const MyVideosStatusScreen({super.key, this.repository});

  @override
  State<MyVideosStatusScreen> createState() => _MyVideosStatusScreenState();
}

class _MyVideosStatusScreenState extends State<MyVideosStatusScreen> {
  late final ProfileRepository _repository;
  final VideoManageService _manage = VideoManageService();
  bool _isLoading = true;
  List<UserVideoModel> _allVideos = [];
  String _selectedFilter = 'ALL'; // ALL, PENDING, APPROVED, REJECTED

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
      final videos = await _repository.getMyVideosStatus();
      if (!mounted) return;
      setState(() {
        _allVideos = videos;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  static const _levels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  Future<void> _editVideo(UserVideoModel video) async {
    final titleCtrl = TextEditingController(text: video.title);
    final descCtrl = TextEditingController(text: video.description ?? '');
    var level = _levels.contains(video.jlptLevel) ? video.jlptLevel : 'N5';
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: Text('Sửa video', style: TextStyle(color: AppPalette.textPrimary)),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    maxLength: 200,
                    style: TextStyle(color: AppPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Tiêu đề'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Tiêu đề không được để trống'
                        : null,
                  ),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    style: TextStyle(color: AppPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Mô tả'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: level,
                    dropdownColor: AppColors.surfaceCard,
                    style: TextStyle(color: AppPalette.textPrimary),
                    decoration: const InputDecoration(labelText: 'Cấp độ JLPT'),
                    items: [
                      for (final l in _levels)
                        DropdownMenuItem(value: l, child: Text(l)),
                    ],
                    onChanged: (v) => setLocal(() => level = v ?? level),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();
    titleCtrl.dispose();
    descCtrl.dispose();
    if (saved != true || !mounted) return;

    try {
      await _manage.update(
        video.id,
        title: title,
        description: desc,
        jlptLevel: level,
      );
      if (!mounted) return;
      AppToast.showSuccess('Đã cập nhật video', context: context);
      await _loadVideos();
    } on ApiException catch (e) {
      if (mounted) AppToast.showError(e.message, context: context);
    } catch (_) {
      if (mounted) {
        AppToast.showError('Không thể cập nhật video', context: context);
      }
    }
  }

  Future<void> _deleteVideo(UserVideoModel video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: Text('Xoá video?', style: TextStyle(color: AppPalette.textPrimary)),
        content: Text(
          '"${video.title}" sẽ bị xoá vĩnh viễn cùng lượt thích và bình luận.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xoá', style: TextStyle(color: AppPalette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _manage.delete(video.id);
      if (!mounted) return;
      setState(() => _allVideos.removeWhere((v) => v.id == video.id));
      AppToast.showSuccess('Đã xoá video', context: context);
    } on ApiException catch (e) {
      if (mounted) AppToast.showError(e.message, context: context);
    } catch (_) {
      if (mounted) AppToast.showError('Không thể xoá video', context: context);
    }
  }

  List<UserVideoModel> get _filteredVideos {
    if (_selectedFilter == 'ALL') return _allVideos;
    return _allVideos
        .where((v) => v.modStatus.toUpperCase() == _selectedFilter)
        .toList();
  }

  int _countByStatus(String status) {
    if (status == 'ALL') return _allVideos.length;
    return _allVideos.where((v) => v.modStatus.toUpperCase() == status).length;
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
          'Danh Sách Chờ Duyệt',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
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
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: AppColors.periwinkle),
                  )
                : RefreshIndicator(
                    onRefresh: _loadVideos,
                    color: AppColors.periwinkle,
                    backgroundColor: AppColors.surfaceCard,
                    child: _filteredVideos.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            itemCount: _filteredVideos.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final video = _filteredVideos[index];
                              return _buildVideoCard(video);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      {'key': 'ALL', 'label': 'Tất cả'},
      {'key': 'PENDING', 'label': 'Chờ duyệt'},
      {'key': 'APPROVED', 'label': 'Đã duyệt'},
      {'key': 'REJECTED', 'label': 'Từ chối'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final key = f['key']!;
            final label = f['label']!;
            final isSelected = _selectedFilter == key;
            final count = _countByStatus(key);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedFilter = key),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.periwinkle : AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.periwinkle
                          : AppColors.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? AppPalette.onAccent : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppPalette.textPrimary.withValues(alpha: 0.25)
                              : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected ? AppPalette.onAccent : AppColors.softSkyBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildVideoCard(UserVideoModel video) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (video.isApproved) {
      statusColor = AppPalette.success; // Emerald
      statusText = 'ĐÃ DUYỆT';
      statusIcon = Icons.check_circle_rounded;
    } else if (video.isRejected) {
      statusColor = AppPalette.error; // Red
      statusText = 'TỪ CHỐI';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = AppPalette.warning; // Amber
      statusText = 'CHỜ DUYỆT';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: video.isRejected
              ? AppPalette.error.withValues(alpha: 0.3)
              : AppColors.outlineVariant.withValues(alpha: 0.4),
          width: video.isRejected ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
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
                          Image.network(
                            video.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(Icons.video_library_rounded, color: AppPalette.border, size: 36),
                            ),
                          )
                        else
                          Center(
                            child: Icon(Icons.video_library_rounded, color: AppPalette.border, size: 36),
                          ),
                        // Duration badge
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppPalette.videoScrim.withValues(alpha: 0.87),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(video.duration),
                              style: TextStyle(
                                color: AppPalette.onVideo,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge & JLPT
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 28,
                            height: 24,
                            child: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              color: AppColors.surfaceCard,
                              icon: Icon(Icons.more_vert_rounded,
                                  color: AppColors.textSecondary, size: 18),
                              onSelected: (v) => v == 'edit'
                                  ? _editVideo(video)
                                  : _deleteVideo(video),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Sửa',
                                      style: TextStyle(color: AppPalette.textPrimary)),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Xoá',
                                      style: TextStyle(color: AppPalette.error)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.periwinkle.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              video.jlptLevel,
                              style: TextStyle(
                                color: AppColors.periwinkle,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Title
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

                      // Description
                      if (video.description != null && video.description!.isNotEmpty)
                        Text(
                          video.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.textPrimary.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Stats
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${video.viewCount}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.favorite_border_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${video.likeCount}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Rejection Reason Banner
          if (video.isRejected && video.rejectionReason != null && video.rejectionReason!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppPalette.error.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: AppPalette.error.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: AppPalette.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${video.rejectionReason}',
                      style: TextStyle(
                        color: AppPalette.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.periwinkle.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.video_library_outlined,
                color: AppColors.softSkyBlue,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _selectedFilter == 'PENDING'
                  ? 'Không có video nào đang chờ duyệt'
                  : _selectedFilter == 'APPROVED'
                      ? 'Chưa có video nào được duyệt'
                      : _selectedFilter == 'REJECTED'
                          ? 'Không có video nào bị từ chối'
                          : 'Bạn chưa tải lên video nào',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Các bài học bạn chia sẻ ở chế độ Công khai sẽ xuất hiện tại đây để theo dõi tiến trình kiểm duyệt.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
