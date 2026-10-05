import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/adaptive_video_theme.dart';

enum FeedTab { following, forYou }

class HomeHeader extends StatelessWidget {
  final FeedTab currentTab;
  final ValueChanged<FeedTab> onTabChanged;
  final VoidCallback? onSearchTap;
  final AdaptiveVideoTheme? theme;

  const HomeHeader({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    this.onSearchTap,
    this.theme,
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

          // Right Search Action Button
          Positioned(
            right: 8.0,
            child: SizedBox(
              width: 40.0,
              height: 40.0,
              child: IconButton(
                onPressed: onSearchTap,
                icon: Icon(
                  Icons.search_rounded,
                  size: 26.0,
                  color: activeTheme.headerSearchIcon,
                ),
                splashRadius: 22.0,
                padding: EdgeInsets.zero,
              ),
            ),
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
