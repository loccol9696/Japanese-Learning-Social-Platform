import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_colors.dart';

/// Thanh điều hướng dưới kiểu TikTok: Trang chủ · Khám phá · [+] · Flashcard · Cá nhân.
/// Index 2 là nút tạo video (không phải tab) — xử lý ở [onTabSelected].
class BottomNavDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const BottomNavDock({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const int createIndex = 2;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58.0,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                inactiveIcon: Icons.home_outlined,
                label: appStrings.navHome,
                selected: selectedIndex == 0,
                onTap: () => onTabSelected(0),
              ),
              _NavItem(
                icon: Icons.search_rounded,
                inactiveIcon: Icons.search_rounded,
                label: appStrings.navExplore,
                selected: selectedIndex == 1,
                onTap: () => onTabSelected(1),
              ),
              Expanded(
                child: Center(
                  child: _CreateButton(
                    label: appStrings.navAddVideo,
                    onTap: () => onTabSelected(createIndex),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.layers_rounded,
                inactiveIcon: Icons.layers_outlined,
                label: appStrings.navFlashcards,
                selected: selectedIndex == 3,
                onTap: () => onTabSelected(3),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                inactiveIcon: Icons.person_outline_rounded,
                label: appStrings.navProfile,
                selected: selectedIndex == 4,
                onTap: () => onTabSelected(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData inactiveIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.inactiveIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.6);

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 28.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? icon : inactiveIcon, color: color, size: 26.0),
              const SizedBox(height: 2.0),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút "+" trắng với viền xanh ngọc / đỏ lệch hai bên (kiểu TikTok).
class _CreateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CreateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget layer(Color color) => Container(
          width: 40.0,
          height: 28.0,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8.0),
          ),
        );

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 48.0,
          height: 32.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(left: 0, child: layer(AppColors.socialCyan)),
              Positioned(right: 0, child: layer(AppColors.socialRed)),
              Container(
                width: 40.0,
                height: 28.0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.black, size: 22.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
