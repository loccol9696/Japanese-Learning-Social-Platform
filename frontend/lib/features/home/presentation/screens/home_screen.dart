import 'package:flutter/material.dart';

import '../widgets/ruby_subtitle_widget.dart';

import '../../../../app/routes.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../data/datasources/home_remote_datasource.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/models/video_post.dart';
import '../../domain/repositories/home_repository.dart';
import '../widgets/bottom_nav_dock.dart';
import '../widgets/home_header.dart';
import '../widgets/video_player_item.dart';
import '../widgets/comments_sheet.dart';
import '../../../explore/presentation/explore_screen.dart';
import '../../../flashcard/presentation/screens/deck_library_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/auth/auth_guard.dart';
import '../../../auth/data/auth_session.dart';
import '../../../chat/presentation/screens/messages_tab.dart';

class HomeScreen extends StatefulWidget {
  final HomeRepository? repository;

  const HomeScreen({super.key, this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late final HomeRepository _repository;
  late final PageController _tabPageController;
  late final PageController _homeTabController;
  late final PageController _followingFeedPageController;
  late final PageController _forYouFeedPageController;

  FeedTab _currentFeedTab = FeedTab.forYou;
  int _homeTabIndex = 1;
  int _currentNavIndex = 0;
  // true khi tab Tin nhắn đang mở một màn con (khung chat...), lúc đó thanh menu dưới được ẩn.
  bool _messagesChildOpen = false;
  int _followingPostIndex = 0;
  int _forYouPostIndex = 0;
  Offset? _homeDragStartPosition;
  bool _homeSwipeHandled = false;
  bool _followingLoading = false;
  bool _forYouLoading = true;
  bool _isModerator = false;
  bool _isAuthDialogOpening = false;
  List<VideoPost> _followingPosts = [];
  List<VideoPost> _forYouPosts = [];

  /// Video trong feed chỉ được phát khi tab Home đang hiện và không có màn nào
  /// đè lên; nếu không video vẫn phát, giải mã và dựng lại ngầm phía sau, làm
  /// giật khi chuyển tab / chuyển trang.
  final ValueNotifier<bool> _feedPlaybackAllowed = ValueNotifier<bool>(true);
  int _pagesAboveFeed = 0;
  bool _routeCovered = false;
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    AuthSession.instance.addListener(_onAuthChanged);
    _repository =
        widget.repository ??
        HomeRepositoryImpl(remoteDataSource: HomeRemoteDataSourceImpl());
    _tabPageController = PageController();
    _homeTabController = PageController(initialPage: 1);
    _followingFeedPageController = PageController();
    _forYouFeedPageController = PageController();
    _checkRole();
    _loadFeed(FeedTab.forYou);
  }

  void _syncFeedPlayback() {
    _feedPlaybackAllowed.value =
        _currentNavIndex == 0 && _pagesAboveFeed == 0 && !_routeCovered;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _subscribedRoute) return;
    if (_subscribedRoute != null) {
      appRouteObserver.unsubscribe(this);
    }
    _subscribedRoute = route;
    appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    _routeCovered = true;
    _syncFeedPlayback();
  }

  @override
  void didPopNext() {
    _routeCovered = false;
    _syncFeedPlayback();
  }

  /// Mở một màn đè lên feed: video tạm dừng trong lúc màn đó mở.
  Future<T?> _pushOverFeed<T>(Future<T?> Function() push) async {
    _pagesAboveFeed++;
    _syncFeedPlayback();
    try {
      return await push();
    } finally {
      _pagesAboveFeed--;
      if (mounted) _syncFeedPlayback();
    }
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
    appRouteObserver.unsubscribe(this);
    AuthSession.instance.removeListener(_onAuthChanged);
    _tabPageController.dispose();
    _homeTabController.dispose();
    _followingFeedPageController.dispose();
    _forYouFeedPageController.dispose();
    _feedPlaybackAllowed.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadFeed(FeedTab tab) async {
    setState(() {
      if (tab == FeedTab.following) {
        _followingLoading = true;
      } else {
        _forYouLoading = true;
      }
    });

    try {
      final posts = tab == FeedTab.forYou
          ? await _repository.getForYouFeed()
          : await _repository.getFollowingFeed();

      if (mounted) {
        setState(() {
          if (tab == FeedTab.following) {
            _followingPosts = posts;
            _followingPostIndex = 0;
            _followingLoading = false;
          } else {
            _forYouPosts = posts;
            _forYouPostIndex = 0;
            _forYouLoading = false;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          if (tab == FeedTab.following) {
            _followingPosts = [];
            _followingLoading = false;
          } else {
            _forYouPosts = [];
            _forYouLoading = false;
          }
        });
      }
    }
  }

  Future<void> _onFeedTabChanged(FeedTab tab) async {
    if (tab == FeedTab.following && !AuthSession.instance.isAuthenticated) {
      await requireAuthentication(context);
      return;
    }
    final index = tab == FeedTab.following ? 0 : 1;
    if (_homeTabController.hasClients) {
      _homeTabController.animateToPage(
        index,
        duration: AppMotion.page,
        curve: AppMotion.pageCurve,
      );
    }
  }

  Future<void> _onHomeTabPageChanged(int index) async {
    _homeTabIndex = index;
    final tab = index == 0 ? FeedTab.following : FeedTab.forYou;
    if (tab == FeedTab.following && !AuthSession.instance.isAuthenticated) {
      if (_homeTabController.hasClients) {
        _homeTabController.animateToPage(
          1,
          duration: AppMotion.quick,
          curve: AppMotion.quickCurve,
        );
      }
      await requireAuthentication(context);
      return;
    }
    if (!mounted) return;
    setState(() => _currentFeedTab = tab);
    if (tab == FeedTab.following && _followingPosts.isEmpty) {
      _loadFeed(tab);
    } else if (tab == FeedTab.forYou && _forYouPosts.isEmpty) {
      _loadFeed(tab);
    }
  }

  Future<void> _handleHomeHorizontalSwipe(double distance) async {
    if (distance.abs() < 40) return;
    final swipingLeft = distance < 0;

    if (swipingLeft) {
      if (_homeTabIndex == 0) {
        await _onFeedTabChanged(FeedTab.forYou);
        return;
      }
      _selectTab(1);
      return;
    }

    if (_homeTabIndex == 1) {
      await _onFeedTabChanged(FeedTab.following);
    }
  }

  Future<void> _handleGuestNavigationSwipe(double distance) async {
    if (distance.abs() < 40) return;
    if (_currentNavIndex == 0) {
      if (distance > 0) {
        await _onFeedTabChanged(FeedTab.following);
      } else {
        _selectTab(1);
      }
      return;
    }
    await _requestAuthentication();
  }

  Future<void> _requestAuthentication() async {
    if (_isAuthDialogOpening || !mounted) return;
    _isAuthDialogOpening = true;
    try {
      await requireAuthentication(context);
    } finally {
      _isAuthDialogOpening = false;
    }
  }

  Future<void> _onNavTabSelected(int index) async {
    // Mọi tab trừ Trang chủ đều cần đăng nhập.
    if (index >= 1) {
      final authenticated = await _requestAuthenticationAndGetResult();
      if (!mounted || !authenticated) return;
    }
    if (index == 2) {
      if (_isModerator) {
        await _pushOverFeed(
          () => Navigator.of(context).pushNamed(AppRoutes.moderationQueue),
        );
      } else {
        final result = await _pushOverFeed(
          () => Navigator.of(context).pushNamed(AppRoutes.upload),
        );
        if (!mounted) return;
        if (result is int && result != BottomNavDock.createIndex) {
          await _onNavTabSelected(result);
        }
      }
      return;
    }
    _selectTab(index);
  }

  Future<bool> _requestAuthenticationAndGetResult() async {
    if (_isAuthDialogOpening || !mounted) return false;
    _isAuthDialogOpening = true;
    try {
      return await requireAuthentication(context);
    } finally {
      _isAuthDialogOpening = false;
    }
  }

  void _selectTab(int navIndex) {
    RubySubtitleWidget.dismissLookups();
    if (!AuthSession.instance.isAuthenticated && navIndex >= 1) {
      _requestAuthentication();
      return;
    }
    final pageIndex = _pageIndexForNavIndex(navIndex);
    if (pageIndex == null) return;
    if (!_tabPageController.hasClients) {
      setState(() => _currentNavIndex = navIndex);
      _syncFeedPlayback();
      return;
    }

    final currentPage = _tabPageController.page?.round() ?? 0;
    final distance = (pageIndex - currentPage).abs();

    if (distance <= 1) {
      // Kề nhau → animation slide mượt như cũ
      _tabPageController.animateToPage(
        pageIndex,
        duration: AppMotion.page,
        curve: AppMotion.pageCurve,
      );
    } else {
      // Xa nhau → nhảy thẳng, không lướt qua trang trung gian
      _tabPageController.jumpToPage(pageIndex);
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
    final activePosts = _currentFeedTab == FeedTab.following
        ? _followingPosts
        : _forYouPosts;
    final activePostIndex = _currentFeedTab == FeedTab.following
        ? _followingPostIndex
        : _forYouPostIndex;
    final currentPost =
        activePosts.isNotEmpty && activePostIndex < activePosts.length
        ? activePosts[activePostIndex]
        : null;
    final activeVideoTheme = AdaptiveVideoTheme(
      isLight: currentPost?.isLightBackground ?? false,
    );

    // Đang trong một cuộc trò chuyện (hoặc đang gõ phím): ẩn thanh menu để khung chat được trọn màn hình
    // và bàn phím, ô nhập không bị chồng lên nó.
    final hideDockForKeyboard =
        _currentNavIndex == BottomNavDock.messagesIndex &&
        (_messagesChildOpen || MediaQuery.viewInsetsOf(context).bottom > 0);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: Stack(
        children: [
          // Horizontal tab navigation; the feed inside the first page keeps
          // its own vertical PageView controller.
          Listener(
            onPointerDown: (event) {
              if (AuthSession.instance.isAuthenticated &&
                  _currentNavIndex != 0) {
                return;
              }
              _homeDragStartPosition = event.position;
              _homeSwipeHandled = false;
            },
            onPointerMove: (event) {
              final start = _homeDragStartPosition;
              if (start == null || _homeSwipeHandled) {
                return;
              }
              final delta = event.position - start;
              if (delta.dx.abs() < 40 ||
                  delta.dx.abs() < delta.dy.abs() * 1.2) {
                return;
              }
              _homeSwipeHandled = true;
              if (!AuthSession.instance.isAuthenticated) {
                _handleGuestNavigationSwipe(delta.dx);
              } else if (_currentNavIndex == 0) {
                _handleHomeHorizontalSwipe(delta.dx);
              }
            },
            onPointerUp: (_) {
              _homeDragStartPosition = null;
              _homeSwipeHandled = false;
            },
            onPointerCancel: (_) {
              _homeDragStartPosition = null;
              _homeSwipeHandled = false;
            },
            child: PageView(
              controller: _tabPageController,
              // Đang trong khung chat thì vuốt ngang dành cho việc quay lại hộp thư, không đổi tab.
              physics:
                  !AuthSession.instance.isAuthenticated ||
                      _currentNavIndex == 0 ||
                      (_currentNavIndex == BottomNavDock.messagesIndex && _messagesChildOpen)
                  ? const NeverScrollableScrollPhysics()
                  : null,
              onPageChanged: (index) {
                RubySubtitleWidget.dismissLookups();
                if (!AuthSession.instance.isAuthenticated && index >= 1) {
                  _tabPageController.animateToPage(
                    0,
                    duration: AppMotion.quick,
                    curve: AppMotion.quickCurve,
                  );
                  _requestAuthentication();
                  return;
                }
                setState(() {
                  _currentNavIndex = _navIndexForPageIndex(index);
                });
                _syncFeedPlayback();
              },
              children: [
                _KeepAlivePage(
                  child: PageView(
                    controller: _homeTabController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: _onHomeTabPageChanged,
                    children: [
                      _buildVideoFeed(FeedTab.following),
                      _buildVideoFeed(FeedTab.forYou),
                    ],
                  ),
                ),
                const _KeepAlivePage(child: DeckLibraryScreen()),
                _KeepAlivePage(
                  child: MessagesTab(
                    onChildRouteChanged: (open) {
                      if (open != _messagesChildOpen) {
                        setState(() => _messagesChildOpen = open);
                      }
                    },
                    bottomInset: hideDockForKeyboard
                        ? 0
                        : BottomNavDock.contentHeight +
                              MediaQuery.paddingOf(context).bottom,
                  ),
                ),
                const _KeepAlivePage(child: ProfileScreen()),
              ],
            ),
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
                  onExploreTap: _openExplore,
                ),
              ),
            ),

          // 3. Floating Bottom Nav Dock
          if (!hideDockForKeyboard)
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

  Widget _buildVideoFeed(FeedTab tab) {
    final posts = tab == FeedTab.following ? _followingPosts : _forYouPosts;
    final isLoading = tab == FeedTab.following
        ? _followingLoading
        : _forYouLoading;
    final controller = tab == FeedTab.following
        ? _followingFeedPageController
        : _forYouFeedPageController;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.periwinkle),
      );
    }

    if (posts.isEmpty) {
      return Center(
        child: Text(
          appStrings.noVideos,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return PageView.builder(
      controller: controller,
      scrollDirection: Axis.vertical,
      itemCount: posts.length,
      onPageChanged: (index) {
        setState(() {
          if (tab == FeedTab.following) {
            _followingPostIndex = index;
          } else {
            _forYouPostIndex = index;
          }
        });
      },
      itemBuilder: (context, index) {
        final post = posts[index];
        return VideoPlayerItem(
          key: ValueKey(post.id),
          post: post,
          isActive: index ==
              (tab == FeedTab.following
                  ? _followingPostIndex
                  : _forYouPostIndex),
          onLikeToggle: () => _handleLikeToggle(post),
          onSaveToggle: () => _handleSaveToggle(post),
          onFollowToggle: () => _handleFollowToggle(post),
          // Đã theo dõi / bỏ theo dõi ngay trên trang cá nhân của người đăng.
          onCreatorFollowChanged: (following) {
            final creatorId = post.creatorId;
            if (creatorId != null && mounted) {
              _updateFollowState(creatorId, following);
            }
          },
          onCommentTap: () => showCommentsSheet(
            context,
            videoId: post.id,
            initialCount: post.commentCount,
          ),
          allowAccountActions: AuthSession.instance.isAuthenticated,
          playbackAllowed: _feedPlaybackAllowed,
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
      final confirmedLiked = await _repository.setLiked(post.id, liked: optimisticLiked);
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
    final optimisticSaved = !previousSaved;
    _updatePostSaveState(post.id, optimisticSaved);
    try {
      final confirmedSaved = await _repository.setSaved(post.id, saved: optimisticSaved);
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
    final creatorId = post.creatorId;
    if (creatorId == null) return;

    // Giao diện đã đảo trạng thái; ghi nhận ngay rồi đối chiếu với server.
    final follow = !post.isFollowing;
    _updateFollowState(creatorId, follow);
    try {
      final confirmed = await _repository.setFollow(creatorId, follow: follow);
      if (!mounted) return;
      _updateFollowState(creatorId, confirmed);
      if (confirmed) {
        AppToast.showSuccess(
          'Đã theo dõi. Khi họ theo dõi lại bạn, hai bạn có thể nhắn tin.',
          context: context,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _updateFollowState(creatorId, !follow);
      AppToast.showError(
        'Không thể cập nhật theo dõi: $error',
        context: context,
      );
    }
  }

  void _updateFollowState(int creatorId, bool isFollowing) {
    setState(() {
      VideoPost update(VideoPost post) => post.creatorId == creatorId
          ? post.copyWith(isFollowing: isFollowing)
          : post;
      _followingPosts = _followingPosts.map(update).toList();
      _forYouPosts = _forYouPosts.map(update).toList();
    });
  }

  Future<void> _openExplore() async {
    RubySubtitleWidget.dismissLookups();
    await _pushOverFeed(
      () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: AppColors.backgroundCanvas,
            body: const ExploreScreen(showBackButton: true),
          ),
        ),
      ),
    );
  }

  void _updatePostSaveState(String postId, bool isSaved) {
    setState(() {
      _followingPosts = _updatePostList(
        _followingPosts,
        postId,
        (post) => post.copyWith(isSaved: isSaved),
      );
      _forYouPosts = _updatePostList(
        _forYouPosts,
        postId,
        (post) => post.copyWith(isSaved: isSaved),
      );
    });
  }

  void _updatePostLikeState(String postId, bool isLiked) {
    setState(() {
      _followingPosts = _updatePostList(_followingPosts, postId, (post) {
        return post.copyWith(
          isLiked: isLiked,
          likeCount: _nextLikeCount(post, isLiked),
        );
      });
      _forYouPosts = _updatePostList(_forYouPosts, postId, (post) {
        return post.copyWith(
          isLiked: isLiked,
          likeCount: _nextLikeCount(post, isLiked),
        );
      });
    });
  }

  List<VideoPost> _updatePostList(
    List<VideoPost> posts,
    String postId,
    VideoPost Function(VideoPost) update,
  ) {
    return [for (final post in posts) post.id == postId ? update(post) : post];
  }

  int _nextLikeCount(VideoPost post, bool isLiked) {
    if (isLiked == post.isLiked) return post.likeCount;
    return isLiked
        ? post.likeCount + 1
        : (post.likeCount > 0 ? post.likeCount - 1 : 0);
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
