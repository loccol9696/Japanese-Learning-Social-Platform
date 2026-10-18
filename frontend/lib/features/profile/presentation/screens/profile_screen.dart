import 'package:flutter/material.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../flashcard/data/models/flashcard_set_model.dart';
import '../../../flashcard/data/services/flashcard_store.dart';
import '../../../flashcard/presentation/screens/deck_overview_screen.dart';
import '../../../flashcard/presentation/widgets/deck_card_item.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FlashcardStore _flashcardStore = FlashcardStore.instance;

  // Profile User Info
  String _displayName = 'Nguyễn Hữu Lộc';
  String _username = '@locnh96';
  String _bio =
      'Học tiếng Nhật mỗi ngày 🇯🇵 | N3 Target 2026 🎯 | Luyện Kaiwa & chia sẻ Flashcard';
  String _avatarUrl =
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80';
  final int _streakDays = 7;

  // Mock public videos
  final List<Map<String, dynamic>> _publicVideos = [
    {
      'id': 'draft_01',
      'isDraft': true,
      'draftCount': 1,
      'title': 'Bản nháp bài học Kanji N3',
      'views': 0,
      'thumbnail': '',
      'isPinned': false,
    },
    {
      'id': 'v_01',
      'isDraft': false,
      'title': 'Phân biệt は và が trong 60s!',
      'views': 45100,
      'viewsText': '45.1K',
      'thumbnail':
          'https://images.unsplash.com/photo-1528164344705-475426879c0d?auto=format&fit=crop&w=600&q=80',
      'isPinned': true,
      'jlpt': 'N4-N3',
    },
    {
      'id': 'v_02',
      'isDraft': false,
      'title': 'Gọi món tại Izakaya chuẩn người bản xứ 🍶',
      'views': 1203,
      'viewsText': '1.203',
      'thumbnail':
          'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=600&q=80',
      'isPinned': false,
      'jlpt': 'Kaiwa',
    },
    {
      'id': 'v_03',
      'isDraft': false,
      'title': '10 câu Slang giới trẻ Tokyo hay dùng',
      'views': 24300,
      'viewsText': '24.3K',
      'thumbnail':
          'https://images.unsplash.com/photo-1542051841857-5f90071e7989?auto=format&fit=crop&w=600&q=80',
      'isPinned': false,
      'jlpt': 'Slang',
    },
    {
      'id': 'v_04',
      'isDraft': false,
      'title': 'Cách nhớ 20 Kanji bộ Thủ siêu tốc',
      'views': 8900,
      'viewsText': '8.9K',
      'thumbnail':
          'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=600&q=80',
      'isPinned': false,
      'jlpt': 'Kanji',
    },
    {
      'id': 'v_05',
      'isDraft': false,
      'title': 'Nghe hiểu N3: Hội thoại tại ga Shinjuku 🚆',
      'views': 5420,
      'viewsText': '5.420',
      'thumbnail':
          'https://images.unsplash.com/photo-1536098561742-ca998e48cbcc?auto=format&fit=crop&w=600&q=80',
      'isPinned': false,
      'jlpt': 'Listening',
    },
    {
      'id': 'v_06',
      'isDraft': false,
      'title': 'Bí kíp đạt 180/180 JLPT N4 của mình 📚',
      'views': 12800,
      'viewsText': '12.8K',
      'thumbnail':
          'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=600&q=80',
      'isPinned': false,
      'jlpt': 'Tips',
    },
  ];

  // Liked videos (Tab 3)
  final List<Map<String, dynamic>> _likedVideos = [
    {
      'id': 'like_01',
      'title': 'Luyện phát âm ngữ điệu Tokyo',
      'views': 89200,
      'viewsText': '89.2K',
      'likesText': '12.4K',
      'thumbnail':
          'https://images.unsplash.com/photo-1492571350019-22de08371fd3?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'like_02',
      'title': 'Mẫu câu từ chối lịch sự bằng Keigo',
      'views': 31200,
      'viewsText': '31.2K',
      'likesText': '4.5K',
      'thumbnail':
          'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=600&q=80',
    },
    {
      'id': 'like_03',
      'title': 'Học từ vựng qua Anime Jujutsu Kaisen',
      'views': 64100,
      'viewsText': '64.1K',
      'likesText': '9.8K',
      'thumbnail':
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=600&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    // 3 Tabs: Video, Flashcards, Liked
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final userData = await TokenStorage.instance.getUserData();
    if (userData != null && mounted) {
      setState(() {
        if (userData['displayName'] != null &&
            userData['displayName'].toString().trim().isNotEmpty) {
          _displayName = userData['displayName'];
        }
        if (userData['username'] != null &&
            userData['username'].toString().trim().isNotEmpty) {
          _username = '@${userData['username'].toString().replaceAll('@', '')}';
        }
        if (userData['bio'] != null &&
            userData['bio'].toString().trim().isNotEmpty) {
          _bio = userData['bio'];
        }
        if (userData['avatarUrl'] != null &&
            userData['avatarUrl'].toString().trim().isNotEmpty) {
          _avatarUrl = userData['avatarUrl'];
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF121212);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // 1. Top Bar Header
            _buildTopHeader(),

            // 2. Profile Info (Horizontal Layout) - Compact
            _buildProfileInfoHorizontal(),

            // 3. Social Stats + Single Wide Action Button
            _buildSocialStatsAndActions(),

            // 4. Icon-based Tab Bar (Sticky above Grid)
            _buildIconTabBar(),

            // 5. Grid/List Content wrapped inside Expanded (No overflow, independent scroll)
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Video Public (3-Column Grid)
                  _buildPublicVideoGrid(),

                  // Tab 2: Thẻ Flashcard (Flashcard Sets)
                  _buildFlashcardTab(),

                  // Tab 3: Video đã thích (Trái tim)
                  _buildLikedVideoGrid(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. TOP HEADER: [👤+] and [≡]
  // ===========================================================================
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Row(
        children: [
          // Left: User Switcher / Username
          InkWell(
            onTap: _showAccountSwitcherBottomSheet,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF8E8E93),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Right Action 1: [👤+] (Thêm bạn bè)
          IconButton(
            icon: const Icon(
              Icons.person_add_alt_1_outlined,
              color: Colors.white,
              size: 23,
            ),
            splashRadius: 20,
            tooltip: 'Thêm bạn bè',
            onPressed: _showAddFriendsBottomSheet,
          ),

          // Right Action 2: [≡] (Menu cài đặt)
          IconButton(
            icon: const Icon(
              Icons.menu_rounded,
              color: Colors.white,
              size: 24,
            ),
            splashRadius: 20,
            tooltip: 'Cài đặt và quyền riêng tư',
            onPressed: _showSettingsMenuBottomSheet,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. BỐ CỤC THÔNG TIN & BADGES
  // - Margin-top 4px giữa tên và Badges
  // - Gap 8px giữa badge "JLPT N3" và "7 ngày học"
  // ===========================================================================
  Widget _buildProfileInfoHorizontal() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bên trái: Tên to in đậm + Badge JLPT N3 + Streak tag (ngay dưới tên)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tên to in đậm
                Text(
                  _displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Margin-top 4px giữa tên và Badges
                const SizedBox(height: 4),

                // Row gồm huy hiệu JLPT N3 & Chuỗi học 7 ngày liên tiếp
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Verified / JLPT Pro badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20D5EC).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF20D5EC).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 11,
                            color: Color(0xFF20D5EC),
                          ),
                          SizedBox(width: 3),
                          Text(
                            'JLPT N3',
                            style: TextStyle(
                              color: Color(0xFF20D5EC),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Gap 8px giữa badge JLPT N3 và 7 ngày học
                    const SizedBox(width: 8),

                    // Streak tag - Giữ chất app học tập tiếng Nhật
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1F28),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFFFC4A4).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🔥',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$_streakDays ngày học',
                            style: const TextStyle(
                              color: Color(0xFFFFC4A4),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Bên phải: Avatar tròn to (w-20 h-20 = 76x76px)
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Avatar circle
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.network(
                    _avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(0xFF1E1F28),
                        child: const Icon(
                          Icons.person,
                          size: 38,
                          color: Color(0xFF8E8E93),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Icon [+] nhỏ màu xanh/coral ở góc dưới avatar
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  onTap: _showCreateContentBottomSheet,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF20D5EC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF121212),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF20D5EC).withValues(alpha: 0.35),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.add,
                        color: Colors.black,
                        size: 15,
                        weight: 900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. CĂN CHỈNH CỤM THỐNG KÊ (STATS) & NÚT HÀNH ĐỘNG
  // - 3 cột chia đều không gian với Expanded (flex-1)
  // - Divider dọc màu xám #424242 rõ ràng hơn, căn giữa theo chiều dọc
  // - Margin trên và dưới của nút "Sửa hồ sơ" tăng lên 16px
  // ===========================================================================
  Widget _buildSocialStatsAndActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          // 3 cột chia đều không gian (Expanded/flex-1)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _buildStatColumn('9.778', 'Đã follow'),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildStatColumn('170', 'Follower'),
              ),
              _buildStatDivider(),
              Expanded(
                child: _buildStatColumn('198', 'Thích'),
              ),
            ],
          ),

          // Margin trên 16px
          const SizedBox(height: 16),

          // Nút hành động duy nhất: "Sửa hồ sơ" trải rộng (full width, h-9: 36px)
          SizedBox(
            width: double.infinity,
            height: 36, // Chuẩn h-9
            child: InkWell(
              onTap: _showEditProfileDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08), // bg-white/10
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                    'Sửa hồ sơ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Margin dưới 16px
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String number, String label) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label: $number'),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFF1E1F28),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 11.5,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 18,
      color: const Color(0xFF424242), // Màu #424242 hiển thị rõ nét hơn
    );
  }

  // ===========================================================================
  // 4. THANH TABS (3 TABS CHÍNH: VIDEO, FLASHCARDS, TRÁI TIM)
  // - Căn giữa icon, indicator rõ nét (weight 2.5)
  // ===========================================================================
  Widget _buildIconTabBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 2.5, // Đường kẻ dưới rõ nét
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF8E8E93),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          // Tab 1: Video Public
          Tab(
            icon: Icon(Icons.grid_on_rounded, size: 21),
          ),
          // Tab 2: Flashcards
          Tab(
            icon: Icon(Icons.style_rounded, size: 21),
          ),
          // Tab 3: Trái tim (Liked)
          Tab(
            icon: Icon(Icons.favorite_rounded, size: 21),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. LƯỚI NỘI DUNG (TIKTOK VIDEO GRID)
  // ===========================================================================
  Widget _buildPublicVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(0, 1.5, 0, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.74,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
      ),
      itemCount: _publicVideos.length,
      itemBuilder: (context, index) {
        final video = _publicVideos[index];
        final isDraft = video['isDraft'] == true;

        if (isDraft) {
          // Ô ĐẦU TIÊN: BẢN NHÁP (DRAFTS)
          return InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mở danh sách Bản nháp video'),
                  backgroundColor: Color(0xFF1E1F28),
                ),
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1B24),
                borderRadius: BorderRadius.zero,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          size: 32,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '1 bản nháp',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Bản nháp',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // CÁC Ô VIDEO BÌNH THƯỜNG
        return InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Xem: ${video['title']}'),
                backgroundColor: const Color(0xFF1E1F28),
              ),
            );
          },
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1E1F28),
              borderRadius: BorderRadius.zero,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  video['thumbnail'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF1E1F28),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_outline,
                          color: Color(0xFF8E8E93),
                          size: 28,
                        ),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
                if (video['isPinned'] == true)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE2C55),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'Đã ghim',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (video['jlpt'] != null && video['isPinned'] != true)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        video['jlpt'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        video['viewsText'] ?? '0',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 2: FLASHCARD SETS
  // ===========================================================================
  Widget _buildFlashcardTab() {
    final cachedDecks = _flashcardStore.cachedSets ?? [];

    if (cachedDecks.isEmpty) {
      final mockDecks = [
        FlashcardSetModel(
          setId: 101,
          title: 'Từ vựng N5 Minna no Nihongo (Bài 1-10)',
          description: '50 từ vựng căn bản về chào hỏi, quốc gia và gia đình',
          authorName: _displayName,
          totalCards: 48,
          learnedCards: 36,
          progressPercentage: 0.75,
          isPublic: true,
        ),
        FlashcardSetModel(
          setId: 102,
          title: 'Kanji cấp tốc N4 - Bộ thủ & Âm On/Kun',
          description: 'Tổng hợp 80 Kanji xuất hiện nhiều nhất trong đề thi JLPT',
          authorName: _displayName,
          totalCards: 80,
          learnedCards: 45,
          progressPercentage: 0.56,
          isPublic: true,
        ),
        FlashcardSetModel(
          setId: 103,
          title: 'Giao tiếp Quán ăn & Mua sắm tại Tokyo',
          description: 'Hội thoại thực chiến gọi món, tính tiền, hỏi size đồ',
          authorName: _displayName,
          totalCards: 32,
          learnedCards: 32,
          progressPercentage: 1.0,
          isPublic: false,
        ),
      ];

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        itemCount: mockDecks.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final deck = mockDecks[index];
          return DeckCardItem(
            deck: deck,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeckOverviewScreen(
                    deck: deck,
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      itemCount: cachedDecks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final deck = cachedDecks[index];
        return DeckCardItem(
          deck: deck,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeckOverviewScreen(
                  deck: deck,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // TAB 3: TRÁI TIM (VIDEO ĐÃ THÍCH)
  // ===========================================================================
  Widget _buildLikedVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(0, 1.5, 0, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.74,
        crossAxisSpacing: 1.5,
        mainAxisSpacing: 1.5,
      ),
      itemCount: _likedVideos.length,
      itemBuilder: (context, index) {
        final video = _likedVideos[index];
        return InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Video đã thích: ${video['title']}'),
                backgroundColor: const Color(0xFF1E1F28),
              ),
            );
          },
          child: Container(
            color: const Color(0xFF1E1F28),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  video['thumbnail'] as String,
                  fit: BoxFit.cover,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFE2C55),
                        size: 13,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        video['likesText'] ?? '0',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // BOTTOM SHEETS & DIALOGS
  // ===========================================================================

  void _showCreateContentBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1F28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tạo nội dung mới',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20D5EC).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.video_call_rounded, color: Color(0xFF20D5EC)),
                  ),
                  title: const Text('Thêm Video bài học mới',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Tải lên video giải thích ngữ pháp hoặc phát âm',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFE2C55).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.style_rounded, color: Color(0xFFFE2C55)),
                  ),
                  title: const Text('Tạo bộ thẻ Flashcard mới',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Soạn từ vựng, Kanji kèm nghĩa tiếng Việt',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.periwinkle.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history_toggle_off_rounded, color: AppColors.periwinkle),
                  ),
                  title: const Text('Thêm Story học tập (24h)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Chia sẻ tiến độ học hoặc câu hỏi nhanh trong ngày',
                      style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettingsMenuBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1F28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Cài đặt và quyền riêng tư',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined, color: Colors.white70),
                  title: const Text('Tài khoản của tôi', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                  onTap: () => Navigator.pop(ctx),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.white70),
                  title: const Text('Quyền riêng tư', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                  onTap: () => Navigator.pop(ctx),
                ),
                ListTile(
                  leading: const Icon(Icons.translate_rounded, color: Colors.white70),
                  title: const Text('Ngôn ngữ ứng dụng', style: TextStyle(color: Colors.white)),
                  trailing: const Text('Tiếng Việt', style: TextStyle(color: Color(0xFF8E8E93))),
                  onTap: () => Navigator.pop(ctx),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_none_rounded, color: Colors.white70),
                  title: const Text('Thông báo nhắc học', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.white30),
                  onTap: () => Navigator.pop(ctx),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFFE2C55)),
                  title: const Text('Đăng xuất', style: TextStyle(color: Color(0xFFFE2C55), fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(ctx);
                    TokenStorage.instance.saveAuthData(accessToken: '', refreshToken: null, user: null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Đã đăng xuất')),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddFriendsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1F28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Thêm bạn học tiếng Nhật',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const TextField(
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nhập username hoặc mã bạn bè...',
                      hintStyle: TextStyle(color: Color(0xFF8E8E93)),
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: Color(0xFF8E8E93)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF20D5EC)),
                  title: const Text('Quét mã QR bạn bè', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx),
                ),
                ListTile(
                  leading: const Icon(Icons.contacts_outlined, color: Color(0xFFFFC4A4)),
                  title: const Text('Tìm kiếm từ Danh bạ', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAccountSwitcherBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1F28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Chuyển đổi tài khoản',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(_avatarUrl),
                  ),
                  title: Text(_displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(_username, style: const TextStyle(color: Color(0xFF8E8E93))),
                  trailing: const Icon(Icons.check_circle, color: Color(0xFF20D5EC)),
                  onTap: () => Navigator.pop(ctx),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                  title: const Text('Thêm tài khoản mới', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _displayName);
    final bioCtrl = TextEditingController(text: _bio);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1F28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: const Text(
          'Sửa hồ sơ',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                labelStyle: TextStyle(color: Color(0xFF8E8E93)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF20D5EC))),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: bioCtrl,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Tiểu sử',
                labelStyle: TextStyle(color: Color(0xFF8E8E93)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF20D5EC))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20D5EC),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() {
                if (nameCtrl.text.trim().isNotEmpty) {
                  _displayName = nameCtrl.text.trim();
                }
                _bio = bioCtrl.text.trim();
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã cập nhật hồ sơ thành công'),
                  backgroundColor: Color(0xFF1E1F28),
                ),
              );
            },
            child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
