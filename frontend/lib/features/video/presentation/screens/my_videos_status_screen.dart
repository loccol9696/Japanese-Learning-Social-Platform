import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../data/video_manage_service.dart';
import '../../../profile/data/datasources/profile_remote_datasource.dart';
import '../../../profile/data/repositories/profile_repository_impl.dart';
import '../../../profile/domain/repositories/profile_repository.dart';
import '../../domain/models/user_video_model.dart';
import '../../../profile/domain/models/topic_model.dart';
import '../../../topic/topic_service.dart';
import '../widgets/video_classification_fields.dart';
import 'upload_video_screen.dart';
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
  String _selectedFilter = 'ALL'; // ALL, DRAFT, PENDING, APPROVED, REJECTED

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
    if (video.isDraft) {
      final updated = await Navigator.of(context).push<dynamic>(
        MaterialPageRoute(
          builder: (_) => PublishVideoScreen(
            editingVideoId: video.id,
            videoUrl: video.videoUrl,
            thumbnailUrl: video.thumbnailUrl ?? '',
            duration: video.duration < 1 ? 1 : video.duration,
            fileName: video.title,
          ),
        ),
      );
      if (updated == true && mounted) {
        await _loadVideos();
      }
      return;
    }
    final titleCtrl = TextEditingController(text: video.title);
    final descCtrl = TextEditingController(text: video.description ?? '');
    var level = _levels.contains(video.jlptLevel) ? video.jlptLevel : 'N5';
    final formKey = GlobalKey<FormState>();
    final classificationKey = GlobalKey<VideoClassificationFieldsState>();
    var topicIds = video.topics.map((t) => t.id).toSet();
    var hashtags = video.hashtags;
    final selectableTopics = {...await _loadTopics(), ...video.topics}.toList();
    if (!mounted) return;

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
                  const SizedBox(height: 18),
                  VideoClassificationFields(
                    key: classificationKey,
                    topics: selectableTopics,
                    selectedTopicIds: topicIds,
                    onTopicsChanged: (ids) => setLocal(() => topicIds = ids),
                    hashtags: hashtags,
                    onHashtagsChanged: (tags) => setLocal(() => hashtags = tags),
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
                if (classificationKey.currentState?.commitPending() == false) return;
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
        topicIds: topicIds,
        hashtags: hashtags,
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

  /// Danh sách chủ đề chỉ để gắn thêm: tải lỗi thì vẫn sửa được các mục khác.
  Future<List<TopicModel>> _loadTopics() async {
    try {
      return await TopicService().fetchTopics();
    } catch (_) {
      return const [];
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

  bool _matchesFilter(UserVideoModel v, String filter) {
    switch (filter) {
      case 'ALL':
        return true;
      case 'DRAFT':
        return v.isDraft;
      case 'PENDING':
        return v.isPending;
      case 'APPROVED':
        return v.isApproved;
      case 'REJECTED':
        return v.isRejected;
      default:
        return v.modStatus.toUpperCase() == filter;
    }
  }

  List<UserVideoModel> get _filteredVideos {
    if (_selectedFilter == 'ALL') return _allVideos;
    return _allVideos.where((v) => _matchesFilter(v, _selectedFilter)).toList();
  }

  int _countByStatus(String status) {
    if (status == 'ALL') return _allVideos.length;
    return _allVideos.where((v) => _matchesFilter(v, status)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, color: AppPalette.textPrimary, size: 30),
          tooltip: 'Quay lại',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Chờ duyệt',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppPalette.info))
                : RefreshIndicator(
                    onRefresh: _loadVideos,
                    color: AppPalette.info,
                    backgroundColor: AppPalette.surface,
                    child: _filteredVideos.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _filteredVideos.length,
                            separatorBuilder: (_, _) => Divider(
                              height: 1,
                              thickness: 1,
                              color: AppPalette.textPrimary.withValues(alpha: 0.07),
                            ),
                            itemBuilder: (context, index) =>
                                _buildVideoRow(_filteredVideos[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Thanh tab gạch chân: nhãn + số lượng, tab đang chọn đậm với số và gạch màu xanh.
  Widget _buildFilterBar() {
    const filters = [
      ('ALL', 'Tất cả'),
      ('DRAFT', 'Nháp'),
      ('PENDING', 'Chờ duyệt'),
      ('APPROVED', 'Đã duyệt'),
      ('REJECTED', 'Từ chối'),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppPalette.textPrimary.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          for (final (key, label) in filters)
            Expanded(
              child: InkWell(
                key: ValueKey('status-tab-$key'),
                onTap: () => setState(() => _selectedFilter = key),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _selectedFilter == key ? AppPalette.info : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: label,
                              style: TextStyle(
                                color: _selectedFilter == key
                                    ? AppPalette.textPrimary
                                    : AppPalette.textPrimary.withValues(alpha: 0.6),
                                fontWeight: _selectedFilter == key
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: '  ${_countByStatus(key)}',
                              style: TextStyle(
                                color: _selectedFilter == key
                                    ? AppPalette.info
                                    : AppPalette.textPrimary.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoRow(UserVideoModel video) {
    final Color statusColor;
    final String statusText;
    if (video.isDraft) {
      statusColor = AppPalette.info;
      statusText = 'Bản nháp';
    } else if (video.isApproved) {
      statusColor = AppPalette.success;
      statusText = 'Đã duyệt';
    } else if (video.isRejected) {
      statusColor = AppPalette.error;
      statusText = 'Từ chối';
    } else {
      statusColor = AppPalette.warning;
      statusText = 'Chờ duyệt';
    }
    final mutedText = AppPalette.textPrimary.withValues(alpha: 0.6);
    final date = formatVideoDate(video.createdAt, DateTime.now());
    final reason = video.rejectionReason?.trim() ?? '';

    return InkWell(
      onTap: video.isDraft ? () => _editVideo(video) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 76,
                color: AppPalette.surface,
                child: video.thumbnailUrl != null && video.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        video.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
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
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            date.isEmpty ? statusText : '$statusText  ·  $date',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: mutedText, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                    if (video.isRejected && reason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        reason,
                        key: const ValueKey('rejection-reason'),
                        style: TextStyle(color: AppPalette.error, fontSize: 12.5, height: 1.3),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                color: AppPalette.surface,
                tooltip: 'Tùy chọn',
                icon: Icon(Icons.more_vert_rounded, color: mutedText, size: 18),
                onSelected: (v) => v == 'edit' ? _editVideo(video) : _deleteVideo(video),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Sửa', style: TextStyle(color: AppPalette.textPrimary)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Xoá', style: TextStyle(color: AppPalette.error)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // Cuộn được để kéo-làm-mới vẫn hoạt động khi danh sách rỗng.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Text(
              'Chưa có video nào',
              key: const ValueKey('empty-videos'),
              style: TextStyle(
                color: AppPalette.textPrimary.withValues(alpha: 0.55),
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Hôm nay, 21:40" cho video đăng trong ngày, còn lại "25/10" (thêm năm nếu khác năm hiện tại).
/// Trả chuỗi rỗng nếu không đọc được thời gian.
String formatVideoDate(String? iso, DateTime now) {
  final parsed = iso == null ? null : DateTime.tryParse(iso);
  if (parsed == null) return '';
  final t = parsed.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  if (t.year == now.year && t.month == now.month && t.day == now.day) {
    return 'Hôm nay, ${two(t.hour)}:${two(t.minute)}';
  }
  final day = '${two(t.day)}/${two(t.month)}';
  return t.year == now.year ? day : '$day/${t.year}';
}
