import 'package:flutter/material.dart';

import '../../../../app/routes.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/home_remote_datasource.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/models/video_post.dart';
import '../../domain/repositories/home_repository.dart';
import '../widgets/bottom_nav_dock.dart';
import '../widgets/home_header.dart';
import '../widgets/video_player_item.dart';
import '../../../explore/presentation/explore_screen.dart';
import '../../../flashcard/presentation/screens/deck_library_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/auth/auth_guard.dart';
import '../../../auth/data/auth_session.dart';

class HomeScreen extends StatefulWidget {
  final HomeRepository? repository;

  const HomeScreen({super.key, this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeRepository _repository;
  late final PageController _tabPageController;
  late final PageController _feedPageController;

  FeedTab _currentFeedTab = FeedTab.forYou;
  int _currentNavIndex = 0;
  int _currentPostIndex = 0;
  bool _isLoading = true;
  bool _isModerator = false;
  List<VideoPost> _posts = [];

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ??
        HomeRepositoryImpl(remoteDataSource: HomeRemoteDataSourceImpl());
    _tabPageController = PageController();
    _feedPageController = PageController();
    _checkRole();
    _loadFeed();
  }

  Future<void> _checkRole() async {
    final userData = await TokenStorage.instance.getUserData();
    final role = userData?['role']?.toString().toUpperCase();
    if (mounted && (role == 'MODERATOR' || role == 'ADMIN')) {
      setState(() => _isModerator = true);
    }
  }

  @override
  void dispose() {
    _tabPageController.dispose();
    _feedPageController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final posts = _currentFeedTab == FeedTab.forYou
          ? await _repository.getForYouFeed()
          : await _repository.getFollowingFeed();

      if (mounted) {
        setState(() {
          _posts = posts;
          _currentPostIndex = 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _posts = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onFeedTabChanged(FeedTab tab) async {
    if (tab == FeedTab.following && !AuthSession.instance.isAuthenticated) {
      if (await requireAuthentication(context) &&
          mounted &&
          AuthSession.instance.isAuthenticated) {
        setState(() => _currentFeedTab = tab);
        _loadFeed();
      }
      return;
    }
    if (_currentFeedTab != tab) {
      setState(() {
        _currentFeedTab = tab;
      });
      _loadFeed();
    }
  }

  Future<void> _onNavTabSelected(int index) async {
    if (index == 2 || index == 3 || index == 4) {
      final authenticated = await requireAuthentication(context);
      if (!mounted || !authenticated) return;
    }
    if (index == 2) {
      if (_isModerator) {
        await Navigator.of(context).pushNamed(AppRoutes.moderationQueue);
      } else {
        final result = await Navigator.of(context).pushNamed(AppRoutes.upload);
        if (!mounted) return;
        if (result is int && result != BottomNavDock.createIndex) {
          _selectTab(result);
        }
      }
      return;
    }
    _selectTab(index);
  }

  void _selectTab(int navIndex) {
    final pageIndex = _pageIndexForNavIndex(navIndex);
    if (pageIndex == null) return;
    if (_tabPageController.hasClients) {
      _tabPageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      setState(() => _currentNavIndex = navIndex);
    }
  }

  int? _pageIndexForNavIndex(int navIndex) {
    return switch (navIndex) {
      0 => 0,
      1 => 1,
      3 => 2,
      4 => 3,
      _ => null,
    };
  }

  int _navIndexForPageIndex(int pageIndex) {
    return switch (pageIndex) {
      0 => 0,
      1 => 1,
      2 => 3,
      3 => 4,
      _ => 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentPost = _posts.isNotEmpty && _currentPostIndex < _posts.length
        ? _posts[_currentPostIndex]
        : null;
    final activeVideoTheme = AdaptiveVideoTheme(
      isLight: currentPost?.isLightBackground ?? false,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: Stack(
        children: [
          // Horizontal tab navigation; the feed inside the first page keeps
          // its own vertical PageView controller.
          PageView(
            controller: _tabPageController,
            onPageChanged: (index) {
              setState(() {
                _currentNavIndex = _navIndexForPageIndex(index);
              });
            },
            children: [
              _KeepAlivePage(child: _buildVideoFeed()),
              const _KeepAlivePage(child: ExploreScreen()),
              const _KeepAlivePage(child: DeckLibraryScreen()),
              const _KeepAlivePage(child: ProfileScreen()),
            ],
          ),

          // 2. Fixed Top Header (Only on Home Feed)
          if (_currentNavIndex == 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: HomeHeader(
                  currentTab: _currentFeedTab,
                  theme: activeVideoTheme,
                  onTabChanged: _onFeedTabChanged,
                ),
              ),
            ),

          // 3. Floating Bottom Nav Dock
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomNavDock(
              selectedIndex: _currentNavIndex,
              onTabSelected: _onNavTabSelected,
              isModerator: _isModerator,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoFeed() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.periwinkle),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Text(
          appStrings.noVideos,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return PageView.builder(
      controller: _feedPageController,
      scrollDirection: Axis.vertical,
      itemCount: _posts.length,
      onPageChanged: (index) {
        setState(() {
          _currentPostIndex = index;
        });
      },
      itemBuilder: (context, index) {
        final post = _posts[index];
        return VideoPlayerItem(
          key: ValueKey(post.id),
          post: post,
          onLikeToggle: () => _handleLikeToggle(post),
          onSaveToggle: () => _handleSaveToggle(post),
          onFollowToggle: () => _handleFollowToggle(post),
          allowAccountActions: AuthSession.instance.isAuthenticated,
        );
      },
    );
  }

  Future<void> _handleLikeToggle(VideoPost post) async {
    if (!AuthSession.instance.isAuthenticated) {
      if (!await requireAuthentication(context)) return;
      if (!mounted) return;
      setState(() {});
    }
    final previousLiked = post.isLiked;
    final optimisticLiked = !previousLiked;
    _updatePostLikeState(post.id, optimisticLiked);

    try {
      final confirmedLiked = await _repository.toggleLike(post.id);
      if (mounted) {
        _updatePostLikeState(post.id, confirmedLiked);
      }
    } catch (error) {
      if (!mounted) return;
      _updatePostLikeState(post.id, previousLiked);
      AppToast.showError(
        'Không thể cập nhật lượt thích: $error',
        context: context,
      );
    }
  }

  Future<void> _handleSaveToggle(VideoPost post) async {
    if (!AuthSession.instance.isAuthenticated) {
      if (!await requireAuthentication(context)) return;
      if (!mounted) return;
      setState(() {});
    }
    final previousSaved = post.isSaved;
    _updatePostSaveState(post.id, !previousSaved);
    try {
      final confirmedSaved = await _repository.toggleSave(post.id);
      if (mounted) {
        _updatePostSaveState(post.id, confirmedSaved);
        AppToast.showSuccess(
          confirmedSaved ? 'Đã lưu video' : 'Đã bỏ lưu video',
          context: context,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _updatePostSaveState(post.id, previousSaved);
      AppToast.showError(
        'Không thể cập nhật video đã lưu: $error',
        context: context,
      );
    }
  }

  Future<void> _handleFollowToggle(VideoPost post) async {
    if (!AuthSession.instance.isAuthenticated) {
      if (!await requireAuthentication(context)) return;
      if (!mounted) return;
      setState(() {});
    }
    try {
      await _repository.toggleFollow(post.creatorTag);
    } catch (error) {
      if (!mounted) return;
      AppToast.showError(
        'Không thể cập nhật theo dõi: $error',
        context: context,
      );
    }
  }

  void _updatePostSaveState(String postId, bool isSaved) {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) return;
    setState(() {
      _posts[index] = _posts[index].copyWith(isSaved: isSaved);
    });
  }

  void _updatePostLikeState(String postId, bool isLiked) {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) return;

    final post = _posts[index];
    final likeCount = isLiked == post.isLiked
        ? post.likeCount
        : isLiked
        ? post.likeCount + 1
        : (post.likeCount > 0 ? post.likeCount - 1 : 0);
    setState(() {
      _posts[index] = post.copyWith(isLiked: isLiked, likeCount: likeCount);
    });
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;

  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
