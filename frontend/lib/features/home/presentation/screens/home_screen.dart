import 'package:flutter/material.dart';
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

class HomeScreen extends StatefulWidget {
  final HomeRepository? repository;

  const HomeScreen({
    super.key,
    this.repository,
  });

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
  List<VideoPost> _posts = [];

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ??
        HomeRepositoryImpl(remoteDataSource: HomeRemoteDataSourceImpl());
    _pageController = PageController();
    _loadFeed();
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
  }

  void _onFeedTabChanged(FeedTab tab) {
    if (_currentFeedTab != tab) {
      setState(() {
        _currentFeedTab = tab;
      });
      _loadFeed();
    }
  }

  void _onNavTabSelected(int index) {
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

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: Stack(
        children: [
          // 1. Main Content based on Nav Tab
          _currentNavIndex == 0
              ? _buildVideoFeed()
              : _buildPlaceholderTab(_currentNavIndex),

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
                  onSearchTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(appStrings.searchPlaceholder),
                        backgroundColor: AppColors.surfaceContainerHigh,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoFeed() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.periwinkle,
        ),
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
          onLikeToggle: () => _repository.toggleLike(post.id),
          onFollowToggle: () => _repository.toggleFollow(post.creatorTag),
        );
      },
    );
  }

  Widget _buildPlaceholderTab(int index) {
    final titles = [
      appStrings.navHome,
      appStrings.navFlashcards,
      appStrings.navAddVideo,
      appStrings.navMessages,
      appStrings.navProfile,
    ];
    final icons = [
      Icons.home_rounded,
      Icons.style_rounded,
      Icons.video_call_rounded,
      Icons.chat_bubble_rounded,
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
