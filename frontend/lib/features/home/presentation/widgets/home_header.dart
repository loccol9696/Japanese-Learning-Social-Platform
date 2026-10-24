import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/adaptive_video_theme.dart';
import '../../../chat/data/services/chat_hub.dart';
import '../../../../core/theme/app_palette.dart';

enum FeedTab { following, forYou }

class HomeHeader extends StatelessWidget {
  final FeedTab currentTab;
  final ValueChanged<FeedTab> onTabChanged;
  final AdaptiveVideoTheme? theme;

  /// Mở hộp thư (tin nhắn). Null thì ẩn icon.
  final VoidCallback? onInboxTap;

  const HomeHeader({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    this.theme,
    this.onInboxTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeTheme = theme ?? const AdaptiveVideoTheme(isLight: false);

    return SizedBox(
      height: 56.0,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center Feed Switcher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabItem(
                    title: appStrings.following,
                    tab: FeedTab.following,
                    isSelected: currentTab == FeedTab.following,
                    theme: activeTheme,
                  ),
                  const SizedBox(width: 18.0),
                  _buildTabItem(
                    title: appStrings.forYou,
                    tab: FeedTab.forYou,
                    isSelected: currentTab == FeedTab.forYou,
                    theme: activeTheme,
                  ),
                ],
              ),
            ),
          ),
          if (onInboxTap != null)
            Positioned(
              right: 4,
              child: _InboxButton(theme: activeTheme, onTap: onInboxTap!),
            ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required FeedTab tab,
    required bool isSelected,
    required AdaptiveVideoTheme theme,
  }) {
    return GestureDetector(
      onTap: () => onTabChanged(tab),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: isSelected ? 16.0 : 15.0,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? theme.headerSelectedText
                    : theme.headerUnselectedText,
                shadows: theme.textShadows,
              ),
            ),
            const SizedBox(height: 4.0),
            // Glowing underline indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isSelected ? 24.0 : 0.0,
              height: 2.5,
              decoration: BoxDecoration(
                color: isSelected ? theme.headerIndicator : Colors.transparent,
                borderRadius: BorderRadius.circular(2.0),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.headerIndicator.withValues(alpha: 0.6),
                          blurRadius: 8.0,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon tin nhắn ở góc phải header, kèm số tin chưa đọc.
class _InboxButton extends StatelessWidget {
  final AdaptiveVideoTheme theme;
  final VoidCallback onTap;

  const _InboxButton({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ChatHub.instance.unreadCount,
      builder: (context, unread, _) {
        return IconButton(
          tooltip: 'Tin nhắn',
          onPressed: onTap,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 26,
                color: theme.headerSelectedText,
                shadows: theme.textShadows,
              ),
              if (unread > 0)
                Positioned(
                  right: -8,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AppPalette.like,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.onAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
