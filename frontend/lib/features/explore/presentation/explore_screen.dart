import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/explore_service.dart';
import '../data/explore_video.dart';
import 'explore_video_player_screen.dart';

/// Màn Khám phá: tìm kiếm + lọc + lưới video, dữ liệu lấy hoàn toàn từ backend.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const Color _background = Color(0xFF121212);
  static const Color _surface = Color(0xFF1E1E1E);
  static const Color _surfaceHigh = Color(0xFF2A2A2A);
  static const Color _accent = Color(0xFFFE2C55);
  static const Color _textMuted = Color(0xFF9E9E9E);

  final ExploreService _service = ExploreService.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  ExploreFilter _filter = ExploreFilter.trending;
  String _search = '';
  final List<ExploreVideo> _videos = [];
  int _page = 0;
  bool _isLast = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  /// Tăng mỗi lần đổi bộ lọc/từ khoá để bỏ qua kết quả của request cũ.
  int _requestToken = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
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
      _showSnackBar(_messageOf(e));
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
      _search = next;
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
    _search = '';
    _loadFirstPage();
  }

  void _selectFilter(ExploreFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _loadFirstPage();
  }

  Future<void> _toggleSave(ExploreVideo video) async {
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
      _showSnackBar(_messageOf(e));
    }
  }

  void _openVideo(ExploreVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExploreVideoPlayerScreen(post: video.post),
      ),
    );
  }

  String _messageOf(Object e) {
    if (e is ApiException) return e.message;
    return 'Không tải được video. Vui lòng thử lại.';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // Chừa chỗ cho thanh menu dưới (nằm đè lên nội dung trong HomeScreen).
    final bottomInset = MediaQuery.of(context).padding.bottom + 84.0;

    return ColoredBox(
      color: _background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 8),
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildFilterChips(),
            const SizedBox(height: 12),
            Expanded(child: _buildBody(bottomInset)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        cursorColor: _accent,
        decoration: InputDecoration(
          hintText: 'Tìm video theo tiêu đề, nội dung...',
          hintStyle: const TextStyle(color: _textMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: _textMuted),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, color: _textMuted),
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
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    filter.label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
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
    if (_isLoading && _videos.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _accent));
    }

    if (_error != null && _videos.isEmpty) {
      return _buildMessage(
        icon: Icons.wifi_off_rounded,
        text: _error!,
        action: TextButton(
          onPressed: _loadFirstPage,
          child: const Text('Thử lại', style: TextStyle(color: _accent)),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.56,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _ExploreVideoCard(
                  video: _videos[index],
                  onTap: () => _openVideo(_videos[index]),
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
                  ? const Center(
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
              style: const TextStyle(color: _textMuted, fontSize: 14),
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
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
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
                          ? Colors.white
                          : Colors.white54,
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
    return Stack(
      fit: StackFit.expand,
      children: [
        if (video.thumbnailUrl.isNotEmpty)
          Image.network(
            video.thumbnailUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _thumbnailFallback(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _thumbnailFallback(),
          )
        else
          _thumbnailFallback(),
        // Gradient để chữ dưới đáy dễ đọc
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
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
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                video.jlptLevel,
                style: const TextStyle(
                  color: Colors.white,
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
              const Icon(
                Icons.play_arrow_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 2),
              Text(
                _formatCount(video.viewCount),
                style: const TextStyle(
                  color: Colors.white,
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
              color: video.isSaved ? const Color(0xFFFFC107) : Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _thumbnailFallback() {
    return Container(
      color: const Color(0xFF2A2A2A),
      alignment: Alignment.center,
      child: const Icon(
        Icons.play_circle_outline_rounded,
        size: 36,
        color: Colors.white24,
      ),
    );
  }

  Widget _buildCreator() {
    return Row(
      children: [
        CircleAvatar(
          radius: 9,
          backgroundColor: const Color(0xFF6C7EE1),
          foregroundImage: video.creatorAvatarUrl.isNotEmpty
              ? NetworkImage(video.creatorAvatarUrl)
              : null,
          child: Text(
            video.creatorName.characters.first.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white,
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
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
