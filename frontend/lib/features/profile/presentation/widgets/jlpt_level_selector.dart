import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Chọn trình độ JLPT: 5 nút N5 → N1 trên một hàng; nút đang chọn nền trắng chữ đen.
class JlptLevelSelector extends StatelessWidget {
  final String selectedLevel;
  final ValueChanged<String> onLevelSelected;

  const JlptLevelSelector({
    super.key,
    required this.selectedLevel,
    required this.onLevelSelected,
  });

  static const List<String> levels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, level) in levels.indexed) ...[
          if (index > 0) const SizedBox(width: 8.0),
          Expanded(
            child: _LevelButton(
              level: level,
              selected: selectedLevel.toUpperCase() == level,
              onTap: () => onLevelSelected(level),
            ),
          ),
        ],
      ],
    );
  }
}

class _LevelButton extends StatelessWidget {
  final String level;
  final bool selected;
  final VoidCallback onTap;

  const _LevelButton({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Nền vẽ bằng Container, ink trên Material trong suốt phía trên nền.
    return Container(
      height: 44.0,
      decoration: BoxDecoration(
        color: selected ? Colors.white : AppColors.socialSurface,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10.0),
          child: Center(
            child: Text(
              level,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontSize: 15.0,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
