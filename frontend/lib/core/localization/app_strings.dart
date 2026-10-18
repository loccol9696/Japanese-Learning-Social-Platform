abstract class AppStrings {
  // Navigation Bar
  String get navHome;
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

  // Profile Screen
  String get profileAddFriends;
  String get profileSettingsPrivacy;
  String profileStudyStreak(int days);
  String get profileStatFollowing;
  String get profileStatFollowers;
  String get profileStatLikes;
  String get profileEdit;
  String get profileNoSavedTitle;
  String get profileNoSavedHint;
  String get profileCreateTitle;
  String get profileCreateVideo;
  String get profileCreateVideoHint;
  String get profileCreateDeck;
  String get profileCreateDeckHint;
  String get profileCreateStory;
  String get profileCreateStoryHint;
  String get profileMyAccount;
  String get profilePrivacy;
  String get profileAppLanguage;
  String get profileStudyReminders;
  String get profileLogout;
  String get profileLoggedOut;
  String get profileAddFriendsTitle;
  String get profileFriendSearchHint;
  String get profileScanQr;
  String get profileFindContacts;
  String get profileSwitchAccount;
  String get profileAddAccount;
  String get profileNoVideosTitle;
  String get profileNoVideosHint;
  String get profileNoLikedTitle;
  String get profileNoLikedHint;
  String get profileStatusPending;
  String get profileStatusRejected;
  String get profileLoadFailed;
  String get profileRetry;
  String homeOriginalSound(String creator);
  String homeViews(String count);
}

class ViStrings implements AppStrings {
  @override
  String get navHome => 'Trang chủ';
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

  @override
  String get profileAddFriends => 'Thêm bạn bè';
  @override
  String get profileSettingsPrivacy => 'Cài đặt và quyền riêng tư';
  @override
  String profileStudyStreak(int days) => '$days ngày học';
  @override
  String get profileStatFollowing => 'Đã follow';
  @override
  String get profileStatFollowers => 'Follower';
  @override
  String get profileStatLikes => 'Thích';
  @override
  String get profileEdit => 'Sửa hồ sơ';
  @override
  String get profileNoSavedTitle => 'Chưa có video đã lưu';
  @override
  String get profileNoSavedHint => 'Nhấn biểu tượng bookmark trên video để lưu lại và xem sau';
  @override
  String get profileCreateTitle => 'Tạo nội dung mới';
  @override
  String get profileCreateVideo => 'Thêm Video bài học mới';
  @override
  String get profileCreateVideoHint => 'Tải lên video giải thích ngữ pháp hoặc phát âm';
  @override
  String get profileCreateDeck => 'Tạo bộ thẻ Flashcard mới';
  @override
  String get profileCreateDeckHint => 'Soạn từ vựng, Kanji kèm nghĩa tiếng Việt';
  @override
  String get profileCreateStory => 'Thêm Story học tập (24h)';
  @override
  String get profileCreateStoryHint => 'Chia sẻ tiến độ học hoặc câu hỏi nhanh trong ngày';
  @override
  String get profileMyAccount => 'Tài khoản của tôi';
  @override
  String get profilePrivacy => 'Quyền riêng tư';
  @override
  String get profileAppLanguage => 'Ngôn ngữ ứng dụng';
  @override
  String get profileStudyReminders => 'Thông báo nhắc học';
  @override
  String get profileLogout => 'Đăng xuất';
  @override
  String get profileLoggedOut => 'Đã đăng xuất';
  @override
  String get profileAddFriendsTitle => 'Thêm bạn học tiếng Nhật';
  @override
  String get profileFriendSearchHint => 'Nhập username hoặc mã bạn bè...';
  @override
  String get profileScanQr => 'Quét mã QR bạn bè';
  @override
  String get profileFindContacts => 'Tìm kiếm từ Danh bạ';
  @override
  String get profileSwitchAccount => 'Chuyển đổi tài khoản';
  @override
  String get profileAddAccount => 'Thêm tài khoản mới';
  @override
  String get profileNoVideosTitle => 'Chưa có video nào';
  @override
  String get profileNoVideosHint => 'Video bài học bạn đăng sẽ hiện ở đây';
  @override
  String get profileNoLikedTitle => 'Chưa thích video nào';
  @override
  String get profileNoLikedHint => 'Nhấn ♥ trên video để thêm vào danh sách đã thích';
  @override
  String get profileStatusPending => 'Chờ duyệt';
  @override
  String get profileStatusRejected => 'Bị từ chối';
  @override
  String get profileLoadFailed => 'Không tải được dữ liệu';
  @override
  String get profileRetry => 'Thử lại';
  @override
  String homeOriginalSound(String creator) => 'Âm thanh gốc - $creator';
  @override
  String homeViews(String count) => '$count lượt xem';
}

class EnStrings implements AppStrings {
  @override
  String get navHome => 'Home';
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
  String get profileAddFriends => 'Add friends';
  @override
  String get profileSettingsPrivacy => 'Settings and privacy';
  @override
  String profileStudyStreak(int days) => '$days-day streak';
  @override
  String get profileStatFollowing => 'Following';
  @override
  String get profileStatFollowers => 'Followers';
  @override
  String get profileStatLikes => 'Likes';
  @override
  String get profileEdit => 'Edit profile';
  @override
  String get profileNoSavedTitle => 'No saved videos yet';
  @override
  String get profileNoSavedHint => 'Tap the bookmark icon on a video to save it for later';
  @override
  String get profileCreateTitle => 'Create new content';
  @override
  String get profileCreateVideo => 'New lesson video';
  @override
  String get profileCreateVideoHint => 'Upload a video explaining grammar or pronunciation';
  @override
  String get profileCreateDeck => 'New flashcard deck';
  @override
  String get profileCreateDeckHint => 'Add vocabulary and kanji with meanings';
  @override
  String get profileCreateStory => 'New study story (24h)';
  @override
  String get profileCreateStoryHint => 'Share your progress or a quick question for today';
  @override
  String get profileMyAccount => 'My account';
  @override
  String get profilePrivacy => 'Privacy';
  @override
  String get profileAppLanguage => 'App language';
  @override
  String get profileStudyReminders => 'Study reminders';
  @override
  String get profileLogout => 'Log out';
  @override
  String get profileLoggedOut => 'Logged out';
  @override
  String get profileAddFriendsTitle => 'Add Japanese study buddies';
  @override
  String get profileFriendSearchHint => 'Enter a username or friend code...';
  @override
  String get profileScanQr => 'Scan a friend\'s QR code';
  @override
  String get profileFindContacts => 'Find from contacts';
  @override
  String get profileSwitchAccount => 'Switch account';
  @override
  String get profileAddAccount => 'Add account';
  @override
  String get profileNoVideosTitle => 'No videos yet';
  @override
  String get profileNoVideosHint => 'Lesson videos you post will appear here';
  @override
  String get profileNoLikedTitle => 'No liked videos yet';
  @override
  String get profileNoLikedHint => 'Tap ♥ on a video to add it here';
  @override
  String get profileStatusPending => 'Pending';
  @override
  String get profileStatusRejected => 'Rejected';
  @override
  String get profileLoadFailed => 'Could not load data';
  @override
  String get profileRetry => 'Retry';
  @override
  String homeOriginalSound(String creator) => 'Original sound - $creator';
  @override
  String homeViews(String count) => '$count views';
}

class JaStrings implements AppStrings {
  @override
  String get navHome => 'ホーム';
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
  String get profileAddFriends => '友だちを追加';
  @override
  String get profileSettingsPrivacy => '設定とプライバシー';
  @override
  String profileStudyStreak(int days) => '$days日連続';
  @override
  String get profileStatFollowing => 'フォロー中';
  @override
  String get profileStatFollowers => 'フォロワー';
  @override
  String get profileStatLikes => 'いいね';
  @override
  String get profileEdit => 'プロフィールを編集';
  @override
  String get profileNoSavedTitle => '保存した動画はまだありません';
  @override
  String get profileNoSavedHint => '動画のブックマークをタップすると、後で見るために保存できます';
  @override
  String get profileCreateTitle => '新しいコンテンツを作成';
  @override
  String get profileCreateVideo => 'レッスン動画を追加';
  @override
  String get profileCreateVideoHint => '文法や発音を解説する動画をアップロード';
  @override
  String get profileCreateDeck => '新しい単語カードを作成';
  @override
  String get profileCreateDeckHint => '語彙や漢字を意味付きで登録';
  @override
  String get profileCreateStory => '学習ストーリーを追加（24時間）';
  @override
  String get profileCreateStoryHint => '今日の学習の進み具合や質問をシェア';
  @override
  String get profileMyAccount => 'マイアカウント';
  @override
  String get profilePrivacy => 'プライバシー';
  @override
  String get profileAppLanguage => 'アプリの言語';
  @override
  String get profileStudyReminders => '学習リマインダー';
  @override
  String get profileLogout => 'ログアウト';
  @override
  String get profileLoggedOut => 'ログアウトしました';
  @override
  String get profileAddFriendsTitle => '日本語の学習仲間を追加';
  @override
  String get profileFriendSearchHint => 'ユーザー名またはフレンドコードを入力...';
  @override
  String get profileScanQr => '友だちのQRコードをスキャン';
  @override
  String get profileFindContacts => '連絡先から探す';
  @override
  String get profileSwitchAccount => 'アカウントを切り替え';
  @override
  String get profileAddAccount => 'アカウントを追加';
  @override
  String get profileNoVideosTitle => 'まだ動画がありません';
  @override
  String get profileNoVideosHint => '投稿したレッスン動画がここに表示されます';
  @override
  String get profileNoLikedTitle => 'いいねした動画はまだありません';
  @override
  String get profileNoLikedHint => '動画の♥をタップするとここに追加されます';
  @override
  String get profileStatusPending => '審査中';
  @override
  String get profileStatusRejected => '却下';
  @override
  String get profileLoadFailed => 'データを読み込めませんでした';
  @override
  String get profileRetry => '再試行';
  @override
  String homeOriginalSound(String creator) => 'オリジナル音声 - $creator';
  @override
  String homeViews(String count) => '$count回視聴';
}
