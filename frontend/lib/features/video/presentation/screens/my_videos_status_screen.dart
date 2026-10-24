import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Danh Sách Chờ Duyệt',
          style: TextStyle(
            color: Colors.white,
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
                ? const Center(
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
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.softSkyBlue,
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
      statusColor = const Color(0xFF10B981); // Emerald
      statusText = 'ĐÃ DUYỆT';
      statusIcon = Icons.check_circle_rounded;
    } else if (video.isRejected) {
      statusColor = const Color(0xFFEF4444); // Red
      statusText = 'TỪ CHỐI';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFFF59E0B); // Amber
      statusText = 'CHỜ DUYỆT';
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: video.isRejected
              ? const Color(0xFFEF4444).withValues(alpha: 0.3)
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
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.video_library_rounded, color: AppPalette.border, size: 36),
                            ),
                          )
                        else
                          const Center(
                            child: Icon(Icons.video_library_rounded, color: AppPalette.border, size: 36),
                          ),
                        // Duration badge
                        Positioned(
                          right: 4,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(video.duration),
                              style: const TextStyle(
                                color: Colors.white,
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.periwinkle.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              video.jlptLevel,
                              style: const TextStyle(
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
                        style: const TextStyle(
                          color: Colors.white,
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
                            color: Colors.white.withValues(alpha: 0.6),
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
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.favorite_border_rounded, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${video.likeCount}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
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
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFEF4444), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Lý do từ chối: ${video.rejectionReason}',
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
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
