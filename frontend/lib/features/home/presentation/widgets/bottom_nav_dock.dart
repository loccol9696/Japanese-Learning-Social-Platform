import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';

/// Tab indices: 0 Home, 1 Explore, 2 Create (+), 3 Flashcard, 4 Profile.
class BottomNavDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final bool isModerator;

  const BottomNavDock({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.isModerator = false,
  });

  static const int createIndex = 2;

  static const List<_TabItemData> _tabs = [
    _TabItemData(
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
    ),
    _TabItemData(
      activeIcon: Icons.search_rounded,
      inactiveIcon: Icons.search_rounded,
    ),
    _TabItemData(
      activeIcon: Icons.add_rounded,
      inactiveIcon: Icons.add_rounded,
    ),
    _TabItemData(
      activeIcon: Icons.layers_rounded,
      inactiveIcon: Icons.layers_outlined,
    ),
    _TabItemData(
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
    ),
  ];

  static const Color _activeColor = Colors.white;
  static const Color _inactiveColor = Color(0xFF9E9E9E);

  String _getTabLabel(int index) {
    return switch (index) {
      0 => appStrings.navHome,
      1 => appStrings.navExplore,
      3 => appStrings.navFlashcards,
      4 => appStrings.navProfile,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 56.0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(_tabs.length, (index) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTabSelected(index),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: index == createIndex
                            ? _buildCreateButton()
                            : _buildTab(index),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Home Bar Indicator (iOS style)
            Padding(
              padding: const EdgeInsets.only(top: 6.0, bottom: 6.0),
              child: Container(
                width: 120.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index) {
    final tab = _tabs[index];
    final isSelected = selectedIndex == index;
    final color = isSelected ? _activeColor : _inactiveColor;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSelected ? tab.activeIcon : tab.inactiveIcon,
          size: 26.0,
          color: color,
        ),
        const SizedBox(height: 3.0),
        Text(
          _getTabLabel(index),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.0,
            height: 1.2,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  /// TikTok-style "+" button: white pill with cyan / pink offset edges.
  Widget _buildCreateButton() {
    const double width = 46.0;
    const double height = 30.0;
    const double innerWidth = 40.0;
    final radius = BorderRadius.circular(8.0);

    return Tooltip(
      message: isModerator ? appStrings.navApproveVideo : appStrings.navAddVideo,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: innerWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF25F4EE),
                  borderRadius: radius,
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: innerWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFE2C55),
                  borderRadius: radius,
                ),
              ),
            ),
            Center(
              child: Container(
                width: innerWidth - 6.0,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: radius,
                ),
                child: Icon(
                  isModerator ? Icons.fact_check_rounded : Icons.add_rounded,
                  size: 22.0,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _TabItemData({
    required this.activeIcon,
    required this.inactiveIcon,
  });
}
