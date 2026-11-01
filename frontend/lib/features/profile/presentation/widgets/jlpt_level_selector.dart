import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_palette.dart';

/// Chọn trình độ JLPT: 5 ô chip đều nhau, ô đang chọn có nền màu nhấn.
class JlptLevelSelector extends StatelessWidget {
  final String selectedLevel;
  final ValueChanged<String> onLevelSelected;

  const JlptLevelSelector({
    super.key,
    required this.selectedLevel,
    required this.onLevelSelected,
  });

  static const List<String> _levels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appStrings.selectJlptLevel,
          style: TextStyle(
            fontSize: 13.0,
            color: AppPalette.textSecondary,
          ),
        ),
        const SizedBox(height: 8.0),
        Row(
          children: [
            for (var i = 0; i < _levels.length; i++) ...[
              if (i > 0) const SizedBox(width: 8.0),
              Expanded(child: _buildChip(_levels[i])),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildChip(String code) {
    final isSelected = selectedLevel.toUpperCase() == code;

    return GestureDetector(
      onTap: () => onLevelSelected(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.accent : AppPalette.surfaceHigh,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Text(
          code,
          style: TextStyle(
            fontSize: 15.0,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? AppPalette.textPrimary
                : AppPalette.textPrimary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
