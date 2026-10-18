import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// ===========================================================================
// 1. TOP HEADER: [username ▾] ... [👤+] [≡]
// ===========================================================================
class ProfileTopBar extends StatelessWidget {
  const ProfileTopBar({
    super.key,
    required this.username,
    required this.onSwitchAccount,
    required this.onAddFriends,
    required this.onOpenSettings,
  });

  final String username;
  final VoidCallback onSwitchAccount;
  final VoidCallback onAddFriends;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
      child: Row(
        children: [
          // Left: User Switcher / Username
          InkWell(
            onTap: onSwitchAccount,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    username,
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
                    color: AppColors.socialTextMuted,
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
            onPressed: onAddFriends,
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
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// 2. THÔNG TIN & BADGES (tên + JLPT + chuỗi ngày học | avatar)
// - Margin-top 4px giữa tên và Badges
// - Gap 8px giữa badge "JLPT N3" và "7 ngày học"
// ===========================================================================
class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.streakDays,
    required this.onCreateContent,
  });

  final String displayName;
  final String avatarUrl;
  final int streakDays;
  final VoidCallback onCreateContent;

  @override
  Widget build(BuildContext context) {
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
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildJlptLevelBadge(),
                    const SizedBox(width: 8),
                    _buildStreakBadge(),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Bên phải: Avatar tròn to (76x76px) + nút [+] tạo nội dung
          _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildJlptLevelBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.socialCyan.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.socialCyan.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: 11,
            color: AppColors.socialCyan,
          ),
          SizedBox(width: 3),
          Text(
            'JLPT N3',
            style: TextStyle(
              color: AppColors.socialCyan,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.socialSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.warmPeach.withValues(alpha: 0.3),
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
            '$streakDays ngày học',
            style: const TextStyle(
              color: AppColors.warmPeach,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
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
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.socialSurface,
                  child: const Icon(
                    Icons.person,
                    size: 38,
                    color: AppColors.socialTextMuted,
                  ),
                );
              },
            ),
          ),
        ),

        // Icon [+] nhỏ màu cyan ở góc dưới avatar
        Positioned(
          bottom: -2,
          right: -2,
          child: GestureDetector(
            onTap: onCreateContent,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.socialCyan,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.socialBackground,
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.socialCyan.withValues(alpha: 0.35),
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
    );
  }
}

// ===========================================================================
// 3. CỤM THỐNG KÊ (STATS) & NÚT "SỬA HỒ SƠ"
// - 3 cột chia đều không gian với Expanded (flex-1)
// - Divider dọc #424242, căn giữa theo chiều dọc
// - Margin trên và dưới của nút "Sửa hồ sơ" 16px
// ===========================================================================
class ProfileStatsSection extends StatelessWidget {
  const ProfileStatsSection({super.key, required this.onEditProfile});

  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _StatColumn('9.778', 'Đã follow')),
              _StatDivider(),
              Expanded(child: _StatColumn('170', 'Follower')),
              _StatDivider(),
              Expanded(child: _StatColumn('198', 'Thích')),
            ],
          ),

          const SizedBox(height: 16),

          // Nút hành động duy nhất: "Sửa hồ sơ" trải rộng (full width, h-9: 36px)
          SizedBox(
            width: double.infinity,
            height: 36,
            child: InkWell(
              onTap: onEditProfile,
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

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn(this.number, this.label);

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label: $number'),
            duration: const Duration(seconds: 1),
            backgroundColor: AppColors.socialSurface,
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
                color: AppColors.socialTextMuted,
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
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      color: AppColors.socialDivider,
    );
  }
}
