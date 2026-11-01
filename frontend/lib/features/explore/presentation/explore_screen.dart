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
import '../../../core/widgets/swipe_back_detector.dart';

/// Màn Khám phá: tìm kiếm + lọc + lưới video, dữ liệu lấy hoàn toàn từ backend.
class ExploreScreen extends StatefulWidget {
  /// Hiện nút quay lại cạnh ô tìm kiếm khi màn được mở riêng (không nằm trong thanh menu).
  final bool showBackButton;

  /// Mở sẵn kết quả của từ khoá này, ví dụ "#anime" khi bấm hashtag trên video.
  final String? initialSearch;

  /// Mở sẵn kết quả của chủ đề này, khi bấm chủ đề trên video.
  final int? initialTopicId;

  const ExploreScreen({
    super.key,
    this.showBackButton = false,
    this.initialSearch,
    this.initialTopicId,
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with SingleTickerProviderStateMixin {
  static Color get _background => AppPalette.background;
  static Color get _surface => AppPalette.surface;
  static Color get _surfaceHigh => AppPalette.surface;
  static Color get _accent => AppPalette.accent;
  static Color get _textMuted => AppPalette.textSecondary;

  final ExploreService _service = ExploreService.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  /// Đang ở tab tìm người dùng thay vì video.
  bool _showUsers = false;

  /// Cách sắp xếp người dùng tự chọn; null thì dùng mặc định theo ngữ cảnh, xem [_sort].
  ExploreSort? _chosenSort;
  String _search = '';
  String? _jlptLevel;
  List<TopicModel> _topics = const [];
  final Set<int> _topicIds = {};
  final List<ExploreVideo> _videos = [];
  int _page = 0;
  bool _isLast = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int? _selectedVideoIndex;
  PageController? _videoFeedController;

  /// Mức hiện của khung xem video: 1 = phủ kín, 0 = trượt hết ra ngoài phải. Điều khiển cả hiệu ứng mở / đóng lẫn
  /// việc trượt theo ngón tay khi vuốt quay lại, giống cách một trang thật chuyển cảnh.
  late final AnimationController _feedAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  bool _closingFeed = false;

  /// Tăng mỗi lần đổi bộ lọc/từ khoá để bỏ qua kết quả của request cũ.
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final initialSearch = widget.initialSearch?.trim() ?? '';
    if (initialSearch.isNotEmpty) {
      _search = initialSearch;
      _searchController.text = initialSearch;
    }
    if (widget.initialTopicId != null) _topicIds.add(widget.initialTopicId!);
    _loadFirstPage();
    _loadTopics();
  }

  /// Có từ khoá thì mặc định xếp theo độ liên quan, còn lại là Thịnh hành. "Liên quan" đã chọn
  /// mất ý nghĩa khi xoá từ khoá nên quay về mặc định.
  ExploreSort get _sort {
    final hasKeyword = _search.isNotEmpty;
    final chosen = _chosenSort;
    if (chosen == null || (chosen == ExploreSort.relevance && !hasKeyword)) {
      return hasKeyword ? ExploreSort.relevance : ExploreSort.trending;
    }
    return chosen;
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
    _feedAnim.dispose();
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
        sort: _sort,
        search: _search,
        jlptLevel: _jlptLevel,
        topicIds: _topicIds,
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
        sort: _sort,
        search: _search,
        jlptLevel: _jlptLevel,
        topicIds: _topicIds,
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
      if (_showUsers) {
        // Kết quả người dùng do UserSearchResults tự tải khi từ khoá đổi.
        setState(() => _search = next);
        return;
      }
      setState(() => _search = next);
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
    if (_showUsers) {
      setState(() => _search = '');
      return;
    }
    setState(() => _search = '');
    _loadFirstPage();
  }

  /// Đổi một điều kiện lọc rồi tải lại từ đầu; từ khoá, chủ đề, trình độ được giữ và kết hợp với nhau.
  void _applyFilter(VoidCallback change) {
    // Áp dụng ngay chữ đang gõ (nếu chưa kịp debounce).
    _searchDebounce?.cancel();
    final typed = _searchController.text.trim();
    setState(() {
      change();
      _search = typed;
    });
    // Chế độ người dùng không có danh sách video để tải.
    if (_showUsers) return;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _loadFirstPage();
  }

  void _toggleTopic(int topicId) {
    _applyFilter(() {
      if (!_topicIds.remove(topicId)) _topicIds.add(topicId);
    });
  }

  void _toggleJlptLevel(String level) {
    _applyFilter(() => _jlptLevel = _jlptLevel == level ? null : level);
  }

  void _selectTab({required bool users}) {
    if (users == _showUsers) return;
    _applyFilter(() => _showUsers = users);
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
    if (_closingFeed) return;
    _videoFeedController?.dispose();
    setState(() {
      _selectedVideoIndex = index;
      _videoFeedController = PageController(initialPage: index);
    });
    _feedAnim.forward(from: 0); // video trượt vào từ bên phải
  }

  /// Đóng khung xem video: trượt ra bên phải rồi gỡ khỏi cây widget, danh sách kết quả vừa tìm vẫn nằm sẵn bên dưới
  /// (giữ nguyên vị trí cuộn).
  Future<void> _closeVideoFeed() async {
    if (_closingFeed || _selectedVideoIndex == null) return;
    _closingFeed = true;
    await _feedAnim.reverse();
    if (!mounted) return;
    final controller = _videoFeedController;
    setState(() {
      _videoFeedController = null;
      _selectedVideoIndex = null;
      _closingFeed = false;
    });
    // Huỷ sau khi khung hình đã gỡ PageView ra khỏi cây.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller?.dispose());
  }

  /// Vuốt quay lại: khung video trượt theo ngón tay.
  void _onFeedDrag(double fraction) {
    if (_closingFeed) return;
    _feedAnim.value = (_feedAnim.value - fraction).clamp(0.0, 1.0);
  }

  void _onFeedDragEnd(bool goBack) {
    if (_closingFeed) return;
    if (goBack) {
      _closeVideoFeed();
    } else {
      _feedAnim.animateTo(1.0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
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
    final inVideoFeed = _selectedVideoIndex != null;
    // Đang xem video trong cùng trang: vuốt quay lại và nút Back của hệ thống chỉ đóng video để về danh sách tìm
    // kiếm vừa rồi, không đóng cả trang Khám phá (về thẳng Trang chủ).
    return SwipeBackOverride(
      active: inVideoFeed,
      onBack: _closeVideoFeed,
      onDragDelta: _onFeedDrag,
      onDragEnd: _onFeedDragEnd,
      child: PopScope(
        canPop: !inVideoFeed,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && inVideoFeed) _closeVideoFeed();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return AnimatedBuilder(
              animation: _feedAnim,
              builder: (context, _) {
                final shown = _feedAnim.value;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Danh sách kết quả luôn nằm bên dưới, dịch nhẹ sang trái khi video trượt vào (như chuyển trang).
                    Transform.translate(
                      offset: Offset(-width * 0.3 * shown, 0),
                      child: IgnorePointer(
                        ignoring: inVideoFeed,
                        child: ExcludeFocus(excluding: inVideoFeed, child: _buildResults()),
                      ),
                    ),
                    if (inVideoFeed)
                      Transform.translate(
                        offset: Offset(width * (1 - shown), 0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.shadow.withValues(alpha: 0.35 * shown),
                                blurRadius: 24,
                              ),
                            ],
                          ),
                          child: _buildVideoFeed(),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildResults() {
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
            _buildTabs(),
            if (!_showUsers) ...[
              const SizedBox(height: 8),
              _buildJlptChips(),
            ],
            if (_topics.isNotEmpty && !_showUsers) ...[
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
              return VideoPlayerItem(
                key: ValueKey(video.id),
                post: video.post,
                // Mở từ trang tìm kiếm (có nút quay lại) thì không có thanh menu dưới nên không chừa chỗ cho nó.
                reserveBottomBar: !widget.showBackButton,
              );
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
            hintText: _showUsers
                ? 'Tìm người dùng theo tên hoặc username...'
                : 'Tìm theo tên, chủ đề, #hashtag...',
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

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
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

  Widget _buildJlptChips() {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: exploreJlptLevels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final level = exploreJlptLevels[index];
          return _filterChip(level, level == _jlptLevel, () => _toggleJlptLevel(level));
        },
      ),
    );
  }

  Widget _buildTopicChips() {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _topics.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _filterChip('Mọi chủ đề', _topicIds.isEmpty, () => _applyFilter(_topicIds.clear));
          }
          final topic = _topics[index - 1];
          return _filterChip(topic.name, _topicIds.contains(topic.id), () => _toggleTopic(topic.id));
        },
      ),
    );
  }

  Widget _buildTabs() {
    Widget tab(String label, {required bool users}) {
      final selected = users == _showUsers;
      return GestureDetector(
        onTap: () => _selectTab(users: users),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _accent : _surfaceHigh,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppPalette.textPrimary : AppPalette.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 34,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            tab('Video', users: false),
            const SizedBox(width: 8),
            tab('Người dùng', users: true),
            const Spacer(),
            if (!_showUsers) _buildSortMenu(),
          ],
        ),
      ),
    );
  }

  Widget _buildSortMenu() {
    final sort = _sort;
    return PopupMenuButton<ExploreSort>(
      tooltip: 'Sắp xếp',
      color: _surface,
      initialValue: sort,
      onSelected: (value) => _applyFilter(() => _chosenSort = value),
      itemBuilder: (context) => [
        for (final option in ExploreSort.values)
          // "Liên quan" cần có từ khoá để so sánh.
          if (option != ExploreSort.relevance || _search.isNotEmpty)
            PopupMenuItem(
              value: option,
              child: Text(option.label, style: TextStyle(color: AppPalette.textPrimary, fontSize: 14)),
            ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_vert_rounded, size: 18, color: _textMuted),
          const SizedBox(width: 4),
          Text(
            sort.label,
            style: TextStyle(color: _textMuted, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(double bottomInset) {
    if (_showUsers) {
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
            : (_topicIds.isNotEmpty || _jlptLevel != null)
                ? 'Không có video nào phù hợp với bộ lọc'
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
