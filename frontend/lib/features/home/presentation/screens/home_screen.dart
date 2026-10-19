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

import '../../../../core/storage/token_storage.dart';

class HomeScreen extends StatefulWidget {
  final HomeRepository? repository;

  const HomeScreen({super.key, this.repository});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeRepository _repository;
  late final PageController _pageController;

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
    _pageController = PageController();
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
    _pageController.dispose();
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

  void _onFeedTabChanged(FeedTab tab) {
    if (_currentFeedTab != tab) {
      setState(() {
        _currentFeedTab = tab;
      });
      _loadFeed();
    }
  }

  Future<void> _onNavTabSelected(int index) async {
    if (index == 2) {
      if (_isModerator) {
        await Navigator.of(context).pushNamed(AppRoutes.moderationQueue);
      } else {
        final result = await Navigator.of(context).pushNamed(AppRoutes.upload);
        if (!mounted) return;
        if (result is int && result != 2) {
          setState(() => _currentNavIndex = result);
        }
      }
      return;
    }
    setState(() {
      _currentNavIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentPost = _posts.isNotEmpty && _currentPostIndex < _posts.length
        ? _posts[_currentPostIndex]
        : null;
    final activeVideoTheme = AdaptiveVideoTheme(
      isLight: currentPost?.isLightBackground ?? false,
    );

    Widget mainContent;
    if (_currentNavIndex == 0) {
      mainContent = _buildVideoFeed();
    } else if (_currentNavIndex == 1) {
      mainContent = const ExploreScreen();
    } else if (_currentNavIndex == 3) {
      mainContent = const DeckLibraryScreen();
    } else if (_currentNavIndex == 4) {
      mainContent = const ProfileScreen();
    } else {
      mainContent = _buildPlaceholderTab(_currentNavIndex);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: Stack(
        children: [
          // 1. Main Content based on Nav Tab
          mainContent,

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
      controller: _pageController,
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
          onFollowToggle: () => _repository.toggleFollow(post.creatorTag),
        );
      },
    );
  }

  Future<void> _handleLikeToggle(VideoPost post) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cập nhật lượt thích: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }

  }

  Future<void> _handleSaveToggle(VideoPost post) async {
    final previousSaved = post.isSaved;
    _updatePostSaveState(post.id, !previousSaved);
    try {
      final confirmedSaved = await _repository.toggleSave(post.id);
      if (mounted) {
        _updatePostSaveState(post.id, confirmedSaved);
      }
    } catch (error) {
      if (!mounted) return;
      _updatePostSaveState(post.id, previousSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể cập nhật video đã lưu: $error'),
          backgroundColor: AppColors.error,
        ),
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

  Widget _buildPlaceholderTab(int index) {
    final titles = [
      appStrings.navHome,
      appStrings.navExplore,
      appStrings.navAddVideo,
      appStrings.navFlashcards,
      appStrings.navProfile,
    ];
    final icons = [
      Icons.home_rounded,
      Icons.search_rounded,
      Icons.add_rounded,
      Icons.layers_rounded,
      Icons.person_rounded,
    ];

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icons[index],
            size: 64.0,
            color: AppColors.periwinkle.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 16.0),
          Text(
            titles[index],
            style: const TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            appStrings.featureUnderDevelopment,
            style: const TextStyle(
              fontSize: 14.0,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
