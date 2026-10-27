import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/auth_guard.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_toast.dart';
import '../../follow/presentation/widgets/user_search_results.dart';
import '../../profile/domain/models/topic_model.dart';
import '../../topic/topic_service.dart';
import '../data/explore_service.dart';
import '../data/explore_video.dart';
import '../../home/presentation/widgets/video_player_item.dart';

/// Màn Khám phá: tìm kiếm + lọc + lưới video, dữ liệu lấy hoàn toàn từ backend.
class ExploreScreen extends StatefulWidget {
  /// Hiện nút quay lại cạnh ô tìm kiếm khi màn được mở riêng (không nằm trong thanh menu).
  final bool showBackButton;

  const ExploreScreen({super.key, this.showBackButton = false});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static Color get _background => AppPalette.background;
  static Color get _surface => AppPalette.surface;
  static Color get _surfaceHigh => AppPalette.surface;
  static Color get _accent => AppPalette.accent;
  static Color get _textMuted => AppPalette.textSecondary;

  final ExploreService _service = ExploreService.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  ExploreFilter _filter = ExploreFilter.trending;
  String _search = '';
  List<TopicModel> _topics = const [];
  int? _topicId;
  final List<ExploreVideo> _videos = [];
  int _page = 0;
  bool _isLast = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int? _selectedVideoIndex;
  PageController? _videoFeedController;

  /// Tăng mỗi lần đổi bộ lọc/từ khoá để bỏ qua kết quả của request cũ.
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
    _loadTopics();
  }

  /// Chip chủ đề là phần phụ: tải lỗi thì không hiện, danh sách video vẫn dùng được.
  Future<void> _loadTopics() async {
    try {
      final topics = await TopicService().fetchTopics();
      if (mounted) setState(() => _topics = topics);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _videoFeedController?.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    final token = ++_requestToken;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.fetchVideos(
        filter: _filter,
        search: _search,
        topicId: _topicId,
      );
      if (!mounted || token != _requestToken) return;
      setState(() {
        _videos
          ..clear()
          ..addAll(result.items);
        _page = 0;
        _isLast = result.isLast;
      });
    } catch (e) {
      if (!mounted || token != _requestToken) return;
      setState(() => _error = _messageOf(e));
    } finally {
      if (mounted && token == _requestToken) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || _isLast) return;
    final token = _requestToken;
    setState(() => _isLoadingMore = true);

    try {
      final result = await _service.fetchVideos(
        filter: _filter,
        search: _search,
        topicId: _topicId,
        page: _page + 1,
      );
      if (!mounted || token != _requestToken) return;
      setState(() {
        _videos.addAll(result.items);
        _page += 1;
        _isLast = result.isLast;
      });
    } catch (e) {
      if (!mounted || token != _requestToken) return;
      _showSnackBar(_messageOf(e), isError: true);
    } finally {
      if (mounted && token == _requestToken) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    setState(() {}); // cập nhật nút xoá
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final next = value.trim();
      if (next == _search) return;
      if (_filter.isUsers) {
        // Kết quả người dùng do UserSearchResults tự tải khi từ khoá đổi.
        setState(() => _search = next);
        return;
      }
      _search = next;
      if (next.isNotEmpty) _topicId = null;
      _loadFirstPage();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_search.isEmpty) {
      setState(() {});
      return;
    }
    if (_filter.isUsers) {
      setState(() => _search = '');
      return;
    }
    _search = '';
    _loadFirstPage();
  }

  void _selectTopic(int? topicId) {
    if (topicId == _topicId) return;
    _searchDebounce?.cancel();
    // Máy chủ ưu tiên từ khoá hơn chủ đề, nên chọn chủ đề thì xoá ô tìm kiếm.
    _searchController.clear();
    setState(() {
      _topicId = topicId;
      _search = '';
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _loadFirstPage();
  }

  void _selectFilter(ExploreFilter filter) {
    if (filter == _filter) return;
    // Áp dụng ngay chữ đang gõ (nếu chưa kịp debounce) để hai chế độ dùng chung một từ khoá.
    _searchDebounce?.cancel();
    final typed = _searchController.text.trim();
    final wasUsers = _filter.isUsers;
    setState(() {
      _filter = filter;
      _search = typed;
      // Máy chủ ưu tiên từ khoá hơn chủ đề: có từ khoá thì bỏ chủ đề đang chọn khi quay lại video.
      if (wasUsers && typed.isNotEmpty) _topicId = null;
    });
    // Chế độ người dùng không có danh sách video để tải.
    if (filter.isUsers) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _loadFirstPage();
  }

  Future<void> _toggleSave(ExploreVideo video) async {
    if (!await requireAuthentication(context)) return;
    final index = _videos.indexWhere((v) => v.id == video.id);
    if (index == -1) return;
    final newSaved = !video.isSaved;

    setState(() => _videos[index] = video.copyWith(isSaved: newSaved));
    try {
      await _service.setSaved(video.id, newSaved);
      if (!mounted) return;
      _showSnackBar(newSaved ? 'Đã lưu video' : 'Đã bỏ lưu video');
    } catch (e) {
      if (!mounted) return;
      final current = _videos.indexWhere((v) => v.id == video.id);
      if (current != -1) {
        setState(() => _videos[current] = video.copyWith(isSaved: !newSaved));
      }
      _showSnackBar(_messageOf(e), isError: true);
    }
  }

  void _openVideo(int index) {
    _videoFeedController?.dispose();
    setState(() {
      _selectedVideoIndex = index;
      _videoFeedController = PageController(initialPage: index);
    });
  }

  void _closeVideoFeed() {
    _videoFeedController?.dispose();
    setState(() {
      _videoFeedController = null;
      _selectedVideoIndex = null;
    });
  }

  String _messageOf(Object e) {
    if (e is ApiException) return e.message;
    return 'Không tải được video. Vui lòng thử lại.';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (isError) {
      AppToast.showError(message, context: context);
    } else {
      AppToast.showSuccess(message, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedVideoIndex != null) {
      return _buildVideoFeed();
    }

    // Chừa chỗ cho thanh menu dưới (nằm đè lên nội dung trong HomeScreen).
    final bottomInset =
        MediaQuery.of(context).padding.bottom +
        (widget.showBackButton ? 16.0 : 84.0);

    return ColoredBox(
      color: _background,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 10),
            _buildFilterChips(),
            if (_topics.isNotEmpty && !_filter.isUsers) ...[
              const SizedBox(height: 8),
              _buildTopicChips(),
            ],
            const SizedBox(height: 12),
            Expanded(child: _buildBody(bottomInset)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoFeed() {
    final controller = _videoFeedController;
    if (controller == null || _videos.isEmpty) {
      return const SizedBox.shrink();
    }

    return ColoredBox(
      color: AppPalette.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: controller,
            scrollDirection: Axis.vertical,
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              final video = _videos[index];
              return VideoPlayerItem(key: ValueKey(video.id), post: video.post);
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  tooltip: 'Quay lại danh sách',
                  style: IconButton.styleFrom(
                    backgroundColor: AppPalette.videoScrim.withValues(alpha: 0.38),
                    foregroundColor: AppPalette.onAccent,
                  ),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: _closeVideoFeed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final searchField = SizedBox(
        height: 46,
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 14,
          ),
          cursorColor: _accent,
          decoration: InputDecoration(
            hintText: _filter.isUsers
                ? 'Tìm người dùng theo tên hoặc username...'
                : 'Tìm video theo tiêu đề, nội dung...',
            hintStyle: TextStyle(color: _textMuted, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: _textMuted),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded, color: _textMuted),
                    onPressed: _clearSearch,
                  ),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 8),
      child: Row(
        children: [
          if (widget.showBackButton)
            IconButton(
              tooltip: 'Quay lại',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppPalette.textPrimary,
                size: 20,
              ),
            ),
          Expanded(child: searchField),
        ],
      ),
    );
  }

  Widget _buildTopicChips() {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _accent : _surfaceHigh,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? AppPalette.onAccent : _textMuted,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _topics.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return chip('Mọi chủ đề', _topicId == null, () => _selectTopic(null));
          }
          final topic = _topics[index - 1];
          return chip(topic.name, topic.id == _topicId, () => _selectTopic(topic.id));
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ExploreFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = ExploreFilter.values[index];
          final selected = filter == _filter;
          return GestureDetector(
            onTap: () => _selectFilter(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _accent : _surfaceHigh,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (filter == ExploreFilter.trending) ...[
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: AppPalette.onVideo,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    filter.label,
                    style: TextStyle(
                      color: selected
                          ? AppPalette.textPrimary
                          : AppPalette.textSecondary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(double bottomInset) {
    if (_filter.isUsers) {
      return UserSearchResults(query: _search, bottomInset: bottomInset);
    }

    if (_isLoading && _videos.isEmpty) {
      return Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_error != null && _videos.isEmpty) {
      return _buildMessage(
        icon: Icons.wifi_off_rounded,
        text: _error!,
        action: TextButton(
          onPressed: _loadFirstPage,
          child: Text('Thử lại', style: TextStyle(color: _accent)),
        ),
      );
    }

    if (_videos.isEmpty) {
      return _buildMessage(
        icon: Icons.video_library_outlined,
        text: _search.isNotEmpty
            ? 'Không tìm thấy video nào cho "$_search"'
            : 'Chưa có video nào',
      );
    }

    return RefreshIndicator(
      color: _accent,
      onRefresh: _loadFirstPage,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ExploreVideoCard(
                  video: _videos[index],
                  onTap: () => _openVideo(index),
                  onToggleSave: () => _toggleSave(_videos[index]),
                ),
                childCount: _videos.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 16, bottom: bottomInset),
              child: _isLoadingMore
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String text,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: _textMuted),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: _textMuted, fontSize: 14),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _ExploreVideoCard extends StatelessWidget {
  final ExploreVideo video;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const _ExploreVideoCard({
    required this.video,
    required this.onTap,
    required this.onToggleSave,
  });

  static String _formatCount(int count) {
    if (count >= 1000000) {
      final value = count / 1000000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}M';
    }
    if (count >= 1000) {
      final value = count / 1000;
      return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}k';
    }
    return '$count';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppPalette.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildThumbnail()),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title.isNotEmpty ? video.title : 'Không có tiêu đề',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: video.title.isNotEmpty
                          ? AppPalette.textPrimary
                          : AppPalette.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (video.creatorName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildCreator(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumbnailUrl = video.thumbnailUrl.trim();
    final previewUrl = video.post.backgroundImageUrl.trim();

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildThumbnailImage(
          thumbnailUrl: thumbnailUrl,
          previewUrl: previewUrl,
        ),
        // Gradient để chữ dưới đáy dễ đọc
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [AppPalette.videoScrim.withValues(alpha: 0.45), Colors.transparent],
              ),
            ),
          ),
        ),
        if (video.jlptLevel.isNotEmpty)
          Positioned(
            top: 6,
            left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppPalette.videoScrim.withValues(alpha: 0.54),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                video.jlptLevel,
                style: TextStyle(
                  color: AppPalette.onVideo,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Row(
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 16,
                color: AppPalette.onVideo,
              ),
              const SizedBox(width: 2),
              Text(
                _formatCount(video.viewCount),
                style: TextStyle(
                  color: AppPalette.onVideo,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onToggleSave,
            tooltip: video.isSaved ? 'Bỏ lưu' : 'Lưu video',
            icon: Icon(
              video.isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 20,
              color: video.isSaved ? AppPalette.gold : AppPalette.onVideo,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnailImage({
    required String thumbnailUrl,
    required String previewUrl,
  }) {
    if (thumbnailUrl.isEmpty && previewUrl.isEmpty) {
      return _thumbnailFallback();
    }

    final primaryUrl = thumbnailUrl.isNotEmpty ? thumbnailUrl : previewUrl;
    final fallbackUrl = primaryUrl == previewUrl ? '' : previewUrl;

    return Image.network(
      primaryUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        if (fallbackUrl.isEmpty) return _thumbnailFallback();
        return Image.network(
          fallbackUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _thumbnailFallback(),
        );
      },
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _thumbnailFallback(),
    );
  }

  Widget _thumbnailFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppPalette.surface, AppPalette.background],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.play_circle_outline_rounded,
        size: 36,
        color: AppPalette.textSecondary,
      ),
    );
  }

  Widget _buildCreator() {
    return Row(
      children: [
        CircleAvatar(
          radius: 9,
          backgroundColor: AppPalette.accent,
          foregroundImage: video.creatorAvatarUrl.isNotEmpty
              ? NetworkImage(video.creatorAvatarUrl)
              : null,
          child: Text(
            video.creatorName.characters.first.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              color: AppPalette.onVideo,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            video.creatorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
