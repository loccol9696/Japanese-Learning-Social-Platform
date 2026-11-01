import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/adaptive_video_theme.dart';

enum FeedTab { following, forYou }

class HomeHeader extends StatelessWidget {
  final FeedTab currentTab;
  final ValueChanged<FeedTab> onTabChanged;
  final AdaptiveVideoTheme? theme;

  /// Mở màn Khám phá. Null thì ẩn icon.
  final VoidCallback? onExploreTap;

  const HomeHeader({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    this.theme,
    this.onExploreTap,
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
          if (onExploreTap != null)
            Positioned(
              right: 4,
              child: _ExploreButton(theme: activeTheme, onTap: onExploreTap!),
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

/// Icon khám phá (tìm kiếm) ở góc phải header.
class _ExploreButton extends StatelessWidget {
  final AdaptiveVideoTheme theme;
  final VoidCallback onTap;

  const _ExploreButton({required this.theme, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: appStrings.navExplore,
      onPressed: onTap,
      icon: Icon(
        Icons.search_rounded,
        size: 28,
        color: theme.headerSelectedText,
        shadows: theme.textShadows,
      ),
    );
  }
}
