abstract class AppStrings {
  // Navigation Bar
  String get navHome;
  String get navFlashcards;
  String get navAddVideo;
  String get navMessages;
  String get navProfile;

  // Header
  String get following;
  String get forYou;
  String get searchPlaceholder;

  // Home Feed & Actions
  String get noVideos;
  String get featureUnderDevelopment;
  String dayStreak(int days);
  String xpEarned(int xp);
  String get follow;
  String get followingStatus;
  String get share;
  String get comments;
  String get subtitle;

  // Language
  String get selectLanguage;
  String get languageChanged;
}

class ViStrings implements AppStrings {
  @override
  String get navHome => 'Trang chủ';
  @override
  String get navFlashcards => 'Flashcard';
  @override
  String get navAddVideo => 'Thêm video';
  @override
  String get navMessages => 'Tin nhắn';
  @override
  String get navProfile => 'Cá nhân';

  @override
  String get following => 'Đang theo dõi';
  @override
  String get forYou => 'Dành cho bạn';
  @override
  String get searchPlaceholder => 'Tìm kiếm bài học / Kanji / Slang...';

  @override
  String get noVideos => 'Không có video nào.';
  @override
  String get featureUnderDevelopment => 'Tính năng đang được phát triển';
  @override
  String dayStreak(int days) => '$days ngày liên tục';
  @override
  String xpEarned(int xp) => '+$xp XP';
  @override
  String get follow => 'Theo dõi';
  @override
  String get followingStatus => 'Đang theo dõi';
  @override
  String get share => 'Chia sẻ';
  @override
  String get comments => 'Bình luận';
  @override
  String get subtitle => 'Phụ đề';

  @override
  String get selectLanguage => 'Chọn ngôn ngữ';
  @override
  String get languageChanged => 'Đã đổi sang Tiếng Việt';
}

class EnStrings implements AppStrings {
  @override
  String get navHome => 'Home';
  @override
  String get navFlashcards => 'Flashcards';
  @override
  String get navAddVideo => 'Create';
  @override
  String get navMessages => 'Inbox';
  @override
  String get navProfile => 'Profile';

  @override
  String get following => 'Following';
  @override
  String get forYou => 'For You';
  @override
  String get searchPlaceholder => 'Search lessons, Kanji, Slang...';

  @override
  String get noVideos => 'No videos available.';
  @override
  String get featureUnderDevelopment => 'Feature under development';
  @override
  String dayStreak(int days) => '$days-Day Streak';
  @override
  String xpEarned(int xp) => '+$xp XP';
  @override
  String get follow => 'Follow';
  @override
  String get followingStatus => 'Following';
  @override
  String get share => 'Share';
  @override
  String get comments => 'Comments';
  @override
  String get subtitle => 'Subtitles';

  @override
  String get selectLanguage => 'Select Language';
  @override
  String get languageChanged => 'Switched to English';
}

class JaStrings implements AppStrings {
  @override
  String get navHome => 'ホーム';
  @override
  String get navFlashcards => '単語帳';
  @override
  String get navAddVideo => '投稿';
  @override
  String get navMessages => 'メッセージ';
  @override
  String get navProfile => 'マイページ';

  @override
  String get following => 'フォロー中';
  @override
  String get forYou => 'おすすめ';
  @override
  String get searchPlaceholder => 'レッスン・漢字・スラングを検索...';

  @override
  String get noVideos => '動画がありません。';
  @override
  String get featureUnderDevelopment => 'この機能は現在開発中です';
  @override
  String dayStreak(int days) => '$days日連続達成';
  @override
  String xpEarned(int xp) => '+$xp XP';
  @override
  String get follow => 'フォロー';
  @override
  String get followingStatus => 'フォロー中';
  @override
  String get share => '共有';
  @override
  String get comments => 'コメント';
  @override
  String get subtitle => '字幕';

  @override
  String get selectLanguage => '言語を選択';
  @override
  String get languageChanged => '日本語に切り替えました';
}
