import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_colors.dart';

class BottomNavDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const BottomNavDock({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const List<_TabItemData> _tabs = [
    _TabItemData(
      label: 'Home',
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
    ),
    _TabItemData(
      label: 'Flashcard',
      activeIcon: Icons.style_rounded,
      inactiveIcon: Icons.style_outlined,
    ),
    _TabItemData(
      label: 'Add Video',
      activeIcon: Icons.video_call_rounded,
      inactiveIcon: Icons.video_call_outlined,
    ),
    _TabItemData(
      label: 'Messages',
      activeIcon: Icons.chat_bubble_rounded,
      inactiveIcon: Icons.chat_bubble_outline_rounded,
      hasBadge: true,
    ),
    _TabItemData(
      label: 'Profile',
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
    ),
  ];

  String _getTabLabel(int index) {
    return switch (index) {
      0 => appStrings.navHome,
      1 => appStrings.navFlashcards,
      2 => appStrings.navAddVideo,
      3 => appStrings.navMessages,
      4 => appStrings.navProfile,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Floating Pill Dock
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420.0),
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            height: 64.0,
            padding: const EdgeInsets.all(4.0),
            decoration: BoxDecoration(
              color: AppColors.dockBackground,
              borderRadius: BorderRadius.circular(32.0),
              border: Border.all(
                color: AppColors.periwinkle.withValues(alpha: 0.3),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.backgroundCanvas.withValues(alpha: 0.85),
                  blurRadius: 36.0,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double tabWidth = constraints.maxWidth / _tabs.length;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Sliding illuminated active pill indicator
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.fastOutSlowIn,
                      left: selectedIndex * tabWidth,
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.periwinkle.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(28.0),
                          border: Border.all(
                            color: AppColors.periwinkle.withValues(alpha: 0.6),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.periwinkle.withValues(alpha: 0.4),
                              blurRadius: 16.0,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 5 Tab Buttons (Positioned.fill ensures full height & vertical centering)
                    Positioned.fill(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(_tabs.length, (index) {
                          final tab = _tabs[index];
                          final isSelected = selectedIndex == index;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => onTabSelected(index),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Icon with optional Sakura Pink notification badge
                                    Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          isSelected
                                              ? tab.activeIcon
                                              : tab.inactiveIcon,
                                          size: 22.0,
                                          color: isSelected
                                              ? AppColors.periwinkle
                                              : AppColors.softSkyBlue
                                                  .withValues(alpha: 0.55),
                                          shadows: isSelected
                                              ? [
                                                  const Shadow(
                                                    color: AppColors.periwinkle,
                                                    blurRadius: 8.0,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        if (tab.hasBadge)
                                          Positioned(
                                            top: -2.0,
                                            right: -3.0,
                                            child: Container(
                                              width: 7.0,
                                              height: 7.0,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.sakuraPink,
                                                border: Border.all(
                                                  color: AppColors.dockBackground,
                                                  width: 1.0,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: AppColors.sakuraPink,
                                                    blurRadius: 6.0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3.0),
                                    // Label (dynamically localized)
                                    Text(
                                      _getTabLabel(index),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        height: 1.2,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w400,
                                        color: isSelected
                                            ? AppColors.onSurface
                                            : AppColors.softSkyBlue
                                                .withValues(alpha: 0.55),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Home Bar Indicator (iOS style)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Container(
              width: 120.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: AppColors.periwinkle.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2.0),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.periwinkle.withValues(alpha: 0.4),
                    blurRadius: 8.0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItemData {
  final String label;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final bool hasBadge;

  const _TabItemData({
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
    this.hasBadge = false,
  });
}
