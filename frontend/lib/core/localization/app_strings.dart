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

  // Profile Update Screen
  String get profileTitle;
  String get editProfile;
  String get saveChanges;
  String get saving;
  String get profileUpdatedSuccessfully;
  String get updateFailed;
  String get selectJlptLevel;
  String get selectInterests;
  String get interestsHint;
  String get changeAvatar;
  String get choosePresetAvatar;
  String get customAvatarUrl;
  String get enterAvatarUrl;
  String get displayName;
  String get displayNamePlaceholder;
  String get bio;
  String get bioPlaceholder;
  String get cancel;
  String get select;
  String get levelBeginner;
  String get levelElementary;
  String get levelIntermediate;
  String get levelUpperIntermediate;
  String get levelAdvanced;
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

  @override
  String get profileTitle => 'Hồ sơ người dùng';
  @override
  String get editProfile => 'Cập nhật hồ sơ';
  @override
  String get saveChanges => 'Lưu thay đổi';
  @override
  String get saving => 'Đang lưu...';
  @override
  String get profileUpdatedSuccessfully => 'Cập nhật hồ sơ thành công!';
  @override
  String get updateFailed => 'Cập nhật thất bại. Vui lòng thử lại!';
  @override
  String get selectJlptLevel => 'Cấp độ JLPT mục tiêu';
  @override
  String get selectInterests => 'Chủ đề & Sở thích (Topics)';
  @override
  String get interestsHint => 'Chọn các chủ đề bạn yêu thích để nhận video phù hợp';
  @override
  String get changeAvatar => 'Đổi ảnh đại diện';
  @override
  String get choosePresetAvatar => 'Chọn avatar mẫu Anime/Chibi';
  @override
  String get customAvatarUrl => 'Hoặc dán liên kết ảnh (URL)';
  @override
  String get enterAvatarUrl => 'https://example.com/avatar.png';
  @override
  String get displayName => 'Tên hiển thị';
  @override
  String get displayNamePlaceholder => 'Nhập tên hiển thị của bạn';
  @override
  String get bio => 'Giới thiệu bản thân (Bio)';
  @override
  String get bioPlaceholder => 'Chia sẻ đôi nét về bạn và mục tiêu học tiếng Nhật...';
  @override
  String get cancel => 'Hủy';
  @override
  String get select => 'Chọn';
  @override
  String get levelBeginner => 'Nhập môn';
  @override
  String get levelElementary => 'Sơ cấp';
  @override
  String get levelIntermediate => 'Trung cấp';
  @override
  String get levelUpperIntermediate => 'Trung cao cấp';
  @override
  String get levelAdvanced => 'Thành thạo';
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

  @override
  String get profileTitle => 'User Profile';
  @override
  String get editProfile => 'Update Profile';
  @override
  String get saveChanges => 'Save Changes';
  @override
  String get saving => 'Saving...';
  @override
  String get profileUpdatedSuccessfully => 'Profile updated successfully!';
  @override
  String get updateFailed => 'Update failed. Please try again!';
  @override
  String get selectJlptLevel => 'Target JLPT Level';
  @override
  String get selectInterests => 'Topics & Interests';
  @override
  String get interestsHint => 'Choose topics you love to personalize your feed';
  @override
  String get changeAvatar => 'Change Avatar';
  @override
  String get choosePresetAvatar => 'Choose preset Anime/Chibi avatar';
  @override
  String get customAvatarUrl => 'Or paste image URL';
  @override
  String get enterAvatarUrl => 'https://example.com/avatar.png';
  @override
  String get displayName => 'Display Name';
  @override
  String get displayNamePlaceholder => 'Enter your display name';
  @override
  String get bio => 'Bio';
  @override
  String get bioPlaceholder => 'Tell us about yourself and your Japanese study goals...';
  @override
  String get cancel => 'Cancel';
  @override
  String get select => 'Select';
  @override
  String get levelBeginner => 'Beginner';
  @override
  String get levelElementary => 'Elementary';
  @override
  String get levelIntermediate => 'Intermediate';
  @override
  String get levelUpperIntermediate => 'Upper-Intermediate';
  @override
  String get levelAdvanced => 'Advanced';
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

  @override
  String get profileTitle => 'マイページ';
  @override
  String get editProfile => 'プロフィール編集';
  @override
  String get saveChanges => '変更を保存';
  @override
  String get saving => '保存中...';
  @override
  String get profileUpdatedSuccessfully => 'プロフィールを更新しました！';
  @override
  String get updateFailed => '更新に失敗しました。もう一度お試しください。';
  @override
  String get selectJlptLevel => '目標JLPTレベル';
  @override
  String get selectInterests => '関心のあるトピック・興味';
  @override
  String get interestsHint => '好きなトピックを選択してフィードをパーソナライズ';
  @override
  String get changeAvatar => 'アバターを変更';
  @override
  String get choosePresetAvatar => 'プリセットアバターから選択';
  @override
  String get customAvatarUrl => 'または画像URLを入力';
  @override
  String get enterAvatarUrl => 'https://example.com/avatar.png';
  @override
  String get displayName => '表示名';
  @override
  String get displayNamePlaceholder => '表示名を入力してください';
  @override
  String get bio => '自己紹介';
  @override
  String get bioPlaceholder => '自己紹介や日本語学習の目標を書いてみましょう...';
  @override
  String get cancel => 'キャンセル';
  @override
  String get select => '選択';
  @override
  String get levelBeginner => '入門';
  @override
  String get levelElementary => '初級';
  @override
  String get levelIntermediate => '中級';
  @override
  String get levelUpperIntermediate => '中上級';
  @override
  String get levelAdvanced => '上級';
}
