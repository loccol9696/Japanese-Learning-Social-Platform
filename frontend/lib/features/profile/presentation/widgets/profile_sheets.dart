import 'package:flutter/material.dart';

import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';

// Bottom sheet & dialog của màn Profile.

const _sheetTitleStyle = TextStyle(color: Colors.white);
const _optionTitleStyle =
    TextStyle(color: Colors.white, fontWeight: FontWeight.w600);
const _optionSubtitleStyle =
    TextStyle(color: AppColors.socialTextMuted, fontSize: 12);

void showCreateContentSheet(BuildContext context) {
  Widget option(BuildContext ctx, IconData icon, Color color, String title,
      String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: _optionTitleStyle),
      subtitle: Text(subtitle, style: _optionSubtitleStyle),
      onTap: () {
        Navigator.pop(ctx);
      },
    );
  }

  showAppBottomSheet(
    context: context,
    title: 'Tạo nội dung mới',
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
    builder: (ctx) => [
      option(ctx, Icons.video_call_rounded, AppColors.socialCyan,
          'Thêm Video bài học mới', 'Tải lên video giải thích ngữ pháp hoặc phát âm'),
      option(ctx, Icons.style_rounded, AppColors.socialRed,
          'Tạo bộ thẻ Flashcard mới', 'Soạn từ vựng, Kanji kèm nghĩa tiếng Việt'),
      option(ctx, Icons.history_toggle_off_rounded, AppColors.periwinkle,
          'Thêm Story học tập (24h)', 'Chia sẻ tiến độ học hoặc câu hỏi nhanh trong ngày'),
    ],
  );
}

void showSettingsSheet(BuildContext context) {
  Widget item(BuildContext ctx, IconData icon, String title, {Widget? trailing}) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: _sheetTitleStyle),
      trailing:
          trailing ?? const Icon(Icons.chevron_right, color: Colors.white30),
      onTap: () => Navigator.pop(ctx),
    );
  }

  showAppBottomSheet(
    context: context,
    title: 'Cài đặt và quyền riêng tư',
    handleGap: 14,
    titleGap: 12,
    builder: (ctx) => [
      item(ctx, Icons.manage_accounts_outlined, 'Tài khoản của tôi'),
      item(ctx, Icons.lock_outline, 'Quyền riêng tư'),
      item(ctx, Icons.translate_rounded, 'Ngôn ngữ ứng dụng',
          trailing: const Text('Tiếng Việt',
              style: TextStyle(color: AppColors.socialTextMuted))),
      item(ctx, Icons.notifications_none_rounded, 'Thông báo nhắc học'),
      const Divider(color: Colors.white12),
      ListTile(
        leading: const Icon(Icons.logout_rounded, color: AppColors.socialRed),
        title: const Text('Đăng xuất',
            style: TextStyle(
                color: AppColors.socialRed, fontWeight: FontWeight.bold)),
        onTap: () {
          Navigator.pop(ctx);
          TokenStorage.instance
              .saveAuthData(accessToken: '', refreshToken: null, user: null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã đăng xuất')),
          );
        },
      ),
    ],
  );
}

void showAddFriendsSheet(BuildContext context) {
  showAppBottomSheet(
    context: context,
    title: 'Thêm bạn học tiếng Nhật',
    padding: const EdgeInsets.all(20.0),
    builder: (ctx) => [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.socialBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: const TextField(
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nhập username hoặc mã bạn bè...',
            hintStyle: TextStyle(color: AppColors.socialTextMuted),
            border: InputBorder.none,
            icon: Icon(Icons.search, color: AppColors.socialTextMuted),
          ),
        ),
      ),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.qr_code_scanner_rounded,
            color: AppColors.socialCyan),
        title: const Text('Quét mã QR bạn bè', style: _sheetTitleStyle),
        onTap: () => Navigator.pop(ctx),
      ),
      ListTile(
        leading: const Icon(Icons.contacts_outlined, color: AppColors.warmPeach),
        title: const Text('Tìm kiếm từ Danh bạ', style: _sheetTitleStyle),
        onTap: () => Navigator.pop(ctx),
      ),
    ],
  );
}

void showAccountSwitcherSheet(
  BuildContext context, {
  required String avatarUrl,
  required String displayName,
  required String username,
}) {
  showAppBottomSheet(
    context: context,
    title: 'Chuyển đổi tài khoản',
    handleGap: 14,
    titleGap: 14,
    builder: (ctx) => [
      ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(avatarUrl),
        ),
        title: Text(displayName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(username,
            style: const TextStyle(color: AppColors.socialTextMuted)),
        trailing: const Icon(Icons.check_circle, color: AppColors.socialCyan),
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
        title: const Text('Thêm tài khoản mới', style: _sheetTitleStyle),
        onTap: () => Navigator.pop(ctx),
      ),
    ],
  );
}

/// Kết quả của dialog sửa hồ sơ (đã trim).
typedef ProfileEdit = ({String displayName, String bio});

/// Dialog sửa tên hiển thị & tiểu sử. [onSave] được gọi trước khi đóng dialog.
void showEditProfileDialog(
  BuildContext context, {
  required String displayName,
  required String bio,
  required void Function(ProfileEdit edit) onSave,
}) {
  final nameCtrl = TextEditingController(text: displayName);
  final bioCtrl = TextEditingController(text: bio);

  InputDecoration field(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.socialTextMuted),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white24)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.socialCyan)),
      );

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.socialSurface,
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
            decoration: field('Tên hiển thị'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: bioCtrl,
            maxLines: 2,
            style: const TextStyle(color: Colors.white),
            decoration: field('Tiểu sử'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy',
              style: TextStyle(color: AppColors.socialTextMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.socialCyan,
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            onSave((
              displayName: nameCtrl.text.trim(),
              bio: bioCtrl.text.trim(),
            ));
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đã cập nhật hồ sơ thành công'),
                backgroundColor: AppColors.socialSurface,
              ),
            );
          },
          child:
              const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
