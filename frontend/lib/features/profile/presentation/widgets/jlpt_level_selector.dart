import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_colors.dart';

class JlptLevelSelector extends StatelessWidget {
  final String selectedLevel;
  final ValueChanged<String> onLevelSelected;

  const JlptLevelSelector({
    super.key,
    required this.selectedLevel,
    required this.onLevelSelected,
  });

  static const List<_JlptLevelData> _levels = [
    _JlptLevelData(code: 'N5', badgeColor: Color(0xFF4ADE80)),
    _JlptLevelData(code: 'N4', badgeColor: AppColors.softSkyBlue),
    _JlptLevelData(code: 'N3', badgeColor: AppColors.periwinkle),
    _JlptLevelData(code: 'N2', badgeColor: AppColors.lavender),
    _JlptLevelData(code: 'N1', badgeColor: AppColors.sakuraPink),
  ];

  String _getLevelDescription(String code) {
    return switch (code) {
      'N5' => appStrings.levelBeginner,
      'N4' => appStrings.levelElementary,
      'N3' => appStrings.levelIntermediate,
      'N2' => appStrings.levelUpperIntermediate,
      'N1' => appStrings.levelAdvanced,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.school_rounded,
              color: AppColors.periwinkle,
              size: 20.0,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                appStrings.selectJlptLevel,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12.0),

        // 5 Level Cards Horizontal Row
        Row(
          children: _levels.map((level) {
            final isSelected = selectedLevel.toUpperCase() == level.code;
            final desc = _getLevelDescription(level.code);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () => onLevelSelected(level.code),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryContainer.withValues(alpha: 0.6)
                          : AppColors.surfaceCardSubtle,
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.periwinkle
                            : AppColors.softSkyBlue.withValues(alpha: 0.2),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.periwinkle.withValues(alpha: 0.35),
                                blurRadius: 12.0,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Code Badge (e.g. N5, N3)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 3.0,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? level.badgeColor.withValues(alpha: 0.25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(
                            level.code,
                            style: TextStyle(
                              fontSize: 15.0,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? level.badgeColor
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4.0),
                        // Subtitle description (e.g. Trung cấp)
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.0,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.onSurface
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _JlptLevelData {
  final String code;
  final Color badgeColor;

  const _JlptLevelData({
    required this.code,
    required this.badgeColor,
  });
}
