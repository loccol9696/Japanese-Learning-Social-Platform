import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// Các khối giao diện của màn DeckOverviewScreen.

/// Thanh trên cùng: quay lại, tùy chọn học, menu bộ thẻ (chỉ tác giả).
class DeckOverviewTopBar extends StatelessWidget {
  final VoidCallback onOpenOptions;
  final VoidCallback? onOpenActions;

  const DeckOverviewTopBar({
    super.key,
    required this.onOpenOptions,
    this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.settings_outlined,
                    color: Colors.white, size: 23),
                onPressed: onOpenOptions,
                splashRadius: 22,
              ),
              if (onOpenActions != null)
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: Colors.white, size: 23),
                  onPressed: onOpenActions,
                  splashRadius: 22,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ô thay thế carousel khi bộ thẻ không có thẻ nào để hiển thị.
class DeckEmptyCarousel extends StatelessWidget {
  final String message;

  const DeckEmptyCarousel({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.flashCardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      alignment: Alignment.center,
      child: Text(
        message,
        style: const TextStyle(color: Colors.white54, fontSize: 15),
      ),
    );
  }
}

/// Nút thẻ trước / sau và chỉ số thẻ hiện tại (VD: 1 / 5).
class DeckCardPager extends StatelessWidget {
  final int currentPage;
  final int total;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const DeckCardPager({
    super.key,
    required this.currentPage,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrevious = currentPage > 0;
    final hasNext = currentPage < total - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: hasPrevious
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.2),
            ),
            onPressed: hasPrevious ? onPrevious : null,
            splashRadius: 22,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.flashCardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Text(
              '${currentPage + 1} / $total',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color:
                  hasNext ? Colors.white : Colors.white.withValues(alpha: 0.2),
            ),
            onPressed: hasNext ? onNext : null,
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}

/// Tên bộ thẻ và số thuật ngữ.
class DeckTitleSection extends StatelessWidget {
  final String title;
  final int termCount;

  const DeckTitleSection({
    super.key,
    required this.title,
    required this.termCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$termCount thuật ngữ',
            style: const TextStyle(
              color: AppColors.socialTextMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Một dòng chọn chế độ học (Thẻ ghi nhớ, Trắc nghiệm, ...).
class DeckModeTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final VoidCallback onTap;

  const DeckModeTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.flashCardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.35),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
