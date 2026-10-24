import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../chat/data/services/chat_hub.dart';

/// Tab indices: 0 Home, 1 Messages, 2 Create (+), 3 Flashcard, 4 Profile.
///
/// Thanh menu dùng chung cho toàn bộ các tab: cùng màu nền trang, có viền mảnh phía trên.
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

  static const int messagesIndex = 1;
  static const int createIndex = 2;

  /// Chiều cao nội dung thanh menu, chưa tính vùng an toàn phía dưới.
  static const double contentHeight = 56.0;

  /// Chiều cao hàng icon + nhãn.
  static const double rowHeight = 48.0;

  /// Vạch cử chỉ giả (chỉ có ý nghĩa khi chạy trên web/máy tính).
  static const double _indicatorTopGap = 2.0;
  static const double _indicatorHeight = 3.0;
  static const double _indicatorBottomGap = 3.0;

  static const double _iconSize = 22.0;
  static const double _labelSize = 10.0;
  static const double _iconLabelGap = 2.0;

  static const List<_TabItemData> _tabs = [
    _TabItemData(
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
    ),
    _TabItemData(
      activeIcon: Icons.chat_bubble_rounded,
      inactiveIcon: Icons.chat_bubble_outline_rounded,
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

  static Color get _activeColor => AppPalette.textPrimary;
  static Color get _inactiveSolidColor => AppPalette.textSecondary;

  String _getTabLabel(int index) {
    return switch (index) {
      0 => appStrings.navHome,
      1 => appStrings.navMessages,
      3 => appStrings.navFlashcards,
      4 => appStrings.navProfile,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    // SafeArea chừa vạch cử chỉ thật của thiết bị, menu không bị che.
    final content = SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: rowHeight,
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

          // Vạch cử chỉ (iOS style), mảnh và sát đáy
          Padding(
            padding: const EdgeInsets.only(
              top: _indicatorTopGap,
              bottom: _indicatorBottomGap,
            ),
            child: Container(
              width: 100.0,
              height: _indicatorHeight,
              decoration: BoxDecoration(
                color: AppPalette.textSecondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppPalette.background,
        // Cùng màu nền trang; chỉ có viền mảnh 1px ở mép trên để phân cách.
        border: Border(top: BorderSide(color: AppPalette.surface, width: 1)),
      ),
      child: content,
    );
  }

  Widget _buildTab(int index) {
    final tab = _tabs[index];
    final isSelected = selectedIndex == index;
    final inactive = _inactiveSolidColor;
    final color = isSelected ? _activeColor : inactive;
    final shadows = null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        index == messagesIndex
            ? _buildMessagesIcon(isSelected ? tab.activeIcon : tab.inactiveIcon, color)
            : Icon(
                isSelected ? tab.activeIcon : tab.inactiveIcon,
                size: _iconSize,
                color: color,
                shadows: shadows,
              ),
        const SizedBox(height: _iconLabelGap),
        Text(
          _getTabLabel(index),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: _labelSize,
            height: 1.1,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: color,
            shadows: shadows,
          ),
        ),
      ],
    );
  }

  /// Icon tin nhắn kèm số tin chưa đọc.
  Widget _buildMessagesIcon(IconData icon, Color color) {
    return ValueListenableBuilder<int>(
      valueListenable: ChatHub.instance.unreadCount,
      builder: (context, unread, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: _iconSize, color: color),
            if (unread > 0)
              Positioned(
                right: -8,
                top: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(minWidth: 15),
                  decoration: BoxDecoration(
                    color: AppPalette.like,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppPalette.onAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Minimalist branded action button for uploading a video.
  Widget _buildCreateButton() {
    return Tooltip(
      message: isModerator
          ? appStrings.navApproveVideo
          : appStrings.navAddVideo,
      child: Container(
        width: 52.0,
        height: 34.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.0),
          color: AppPalette.accent,
        ),
        child: Icon(
          isModerator ? Icons.fact_check_rounded : Icons.add_rounded,
          size: 27.0,
          color: AppPalette.onAccent,
        ),
      ),
    );
  }
}

class _TabItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _TabItemData({required this.activeIcon, required this.inactiveIcon});
}
