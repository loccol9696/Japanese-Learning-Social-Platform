abstract class AppStrings {
  // Navigation Bar
  String get navHome;
  String get navExplore;
  String get navFlashcards;
  String get navAddVideo;
  String get navApproveVideo;
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

  // Notifications
  String get notificationsTitle;
  String get notificationsInteractions;
  String get notificationsSystem;
  String get notificationsMarkAllRead;
  String get notificationsEmptyInteractions;
  String get notificationsEmptySystem;
  String get notificationsLoadError;
  String get notificationsRetry;
  String get notificationsLoadMoreError;
  String get notificationVideoUnavailable;
  String get notificationSomeone;
  String notificationCommented(String name);
  String notificationLiked(String name);
  String notificationShared(String name);
  String notificationApproved(String title);
  String notificationRejected(String title);
  String notificationReason(String reason);
  String get timeJustNow;
  String timeMinutesAgo(int minutes);
  String timeHoursAgo(int hours);
  String timeDaysAgo(int days);
}

class ViStrings implements AppStrings {
  @override
  String get navHome => 'Trang chủ';
  @override
  String get navExplore => 'Khám phá';
  @override
  String get navFlashcards => 'Flashcard';
  @override
  String get navAddVideo => 'Thêm video';
  @override
  String get navApproveVideo => 'Duyệt video';
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
  String get editProfile => 'Chỉnh sửa hồ sơ';
  @override
  String get saveChanges => 'Lưu thay đổi';
  @override
  String get saving => 'Đang lưu...';
  @override
  String get profileUpdatedSuccessfully => 'Cập nhật hồ sơ thành công!';
  @override
  String get updateFailed => 'Cập nhật thất bại. Vui lòng thử lại!';
  @override
  String get selectJlptLevel => 'Trình độ JLPT';
  @override
  String get selectInterests => 'Sở thích';
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
  String get displayName => 'Tên';
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

  @override
  String get notificationsTitle => 'Thông báo';
  @override
  String get notificationsInteractions => 'Tương tác';
  @override
  String get notificationsSystem => 'Hệ thống';
  @override
  String get notificationsMarkAllRead => 'Đọc tất cả';
  @override
  String get notificationsEmptyInteractions => 'Chưa có tương tác nào. Khi có người thích, bình luận hoặc chia sẻ video của bạn, bạn sẽ thấy ở đây.';
  @override
  String get notificationsEmptySystem => 'Chưa có thông báo hệ thống nào. Kết quả duyệt video của bạn sẽ hiện ở đây.';
  @override
  String get notificationsLoadError => 'Không tải được thông báo';
  @override
  String get notificationsRetry => 'Thử lại';
  @override
  String get notificationsLoadMoreError => 'Không tải thêm được thông báo';
  @override
  String get notificationVideoUnavailable => 'Video không còn khả dụng';
  @override
  String get notificationSomeone => 'Một người dùng';
  @override
  String notificationCommented(String name) => '$name đã bình luận về video của bạn';
  @override
  String notificationLiked(String name) => '$name đã thích video của bạn';
  @override
  String notificationShared(String name) => '$name đã chia sẻ video của bạn';
  @override
  String notificationApproved(String title) => 'Video “$title” đã được duyệt và đăng công khai';
  @override
  String notificationRejected(String title) => 'Video “$title” đã bị từ chối';
  @override
  String notificationReason(String reason) => 'Lý do: $reason';
  @override
  String get timeJustNow => 'Vừa xong';
  @override
  String timeMinutesAgo(int minutes) => '$minutes phút trước';
  @override
  String timeHoursAgo(int hours) => '$hours giờ trước';
  @override
  String timeDaysAgo(int days) => '$days ngày trước';
}

class EnStrings implements AppStrings {
  @override
  String get navHome => 'Home';
  @override
  String get navExplore => 'Discover';
  @override
  String get navFlashcards => 'Flashcards';
  @override
  String get navAddVideo => 'Create';
  @override
  String get navApproveVideo => 'Approve';
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

  @override
  String get notificationsTitle => 'Notifications';
  @override
  String get notificationsInteractions => 'Activity';
  @override
  String get notificationsSystem => 'System';
  @override
  String get notificationsMarkAllRead => 'Mark all as read';
  @override
  String get notificationsEmptyInteractions => 'No activity yet. When someone likes, comments on or shares your video, you will see it here.';
  @override
  String get notificationsEmptySystem => 'No system notifications yet. The review results of your videos will show up here.';
  @override
  String get notificationsLoadError => 'Unable to load notifications';
  @override
  String get notificationsRetry => 'Retry';
  @override
  String get notificationsLoadMoreError => 'Unable to load more notifications';
  @override
  String get notificationVideoUnavailable => 'This video is no longer available';
  @override
  String get notificationSomeone => 'Someone';
  @override
  String notificationCommented(String name) => '$name commented on your video';
  @override
  String notificationLiked(String name) => '$name liked your video';
  @override
  String notificationShared(String name) => '$name shared your video';
  @override
  String notificationApproved(String title) => 'Your video “$title” was approved and is now public';
  @override
  String notificationRejected(String title) => 'Your video “$title” was rejected';
  @override
  String notificationReason(String reason) => 'Reason: $reason';
  @override
  String get timeJustNow => 'Just now';
  @override
  String timeMinutesAgo(int minutes) => '${minutes}m ago';
  @override
  String timeHoursAgo(int hours) => '${hours}h ago';
  @override
  String timeDaysAgo(int days) => '${days}d ago';
}

class JaStrings implements AppStrings {
  @override
  String get navHome => 'ホーム';
  @override
  String get navExplore => '発見';
  @override
  String get navFlashcards => '単語帳';
  @override
  String get navAddVideo => '投稿';
  @override
  String get navApproveVideo => '動画を承認';
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

  @override
  String get notificationsTitle => '通知';
  @override
  String get notificationsInteractions => 'アクティビティ';
  @override
  String get notificationsSystem => 'システム';
  @override
  String get notificationsMarkAllRead => 'すべて既読にする';
  @override
  String get notificationsEmptyInteractions => 'まだアクティビティはありません。あなたの動画にいいね、コメント、シェアがあるとここに表示されます。';
  @override
  String get notificationsEmptySystem => 'システム通知はまだありません。動画の審査結果がここに表示されます。';
  @override
  String get notificationsLoadError => '通知を読み込めませんでした';
  @override
  String get notificationsRetry => '再試行';
  @override
  String get notificationsLoadMoreError => '通知をさらに読み込めませんでした';
  @override
  String get notificationVideoUnavailable => 'この動画は利用できなくなりました';
  @override
  String get notificationSomeone => 'ユーザー';
  @override
  String notificationCommented(String name) => '$nameさんがあなたの動画にコメントしました';
  @override
  String notificationLiked(String name) => '$nameさんがあなたの動画にいいねしました';
  @override
  String notificationShared(String name) => '$nameさんがあなたの動画をシェアしました';
  @override
  String notificationApproved(String title) => '動画「$title」が承認され、公開されました';
  @override
  String notificationRejected(String title) => '動画「$title」は承認されませんでした';
  @override
  String notificationReason(String reason) => '理由：$reason';
  @override
  String get timeJustNow => 'たった今';
  @override
  String timeMinutesAgo(int minutes) => '$minutes分前';
  @override
  String timeHoursAgo(int hours) => '$hours時間前';
  @override
  String timeDaysAgo(int days) => '$days日前';
}
