import 'package:flutter/material.dart';
import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/topic_model.dart';

class InterestTagsSelector extends StatelessWidget {
  final List<TopicModel> availableTopics;
  final List<String> selectedInterests;
  final ValueChanged<List<String>> onInterestsChanged;

  const InterestTagsSelector({
    super.key,
    required this.availableTopics,
    required this.selectedInterests,
    required this.onInterestsChanged,
  });

  String _getTopicIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('anime') || lower.contains('manga')) return '🎌';
    if (lower.contains('giao tiếp') || lower.contains('daily') || lower.contains('hằng ngày')) return '💬';
    if (lower.contains('jlpt') || lower.contains('thi')) return '📚';
    if (lower.contains('du lịch') || lower.contains('văn hóa') || lower.contains('travel')) return '✈️';
    if (lower.contains('nhạc') || lower.contains('music') || lower.contains('j-pop')) return '🎵';
    if (lower.contains('ẩm thực') || lower.contains('food') || lower.contains('nấu')) return '🍣';
    if (lower.contains('kanji') || lower.contains('hán tự')) return '🈸';
    if (lower.contains('it') || lower.contains('công việc') || lower.contains('business')) return '💻';
    if (lower.contains('tin tức') || lower.contains('news')) return '📰';
    return '✨';
  }

  void _toggleTopic(String name) {
    final updated = List<String>.from(selectedInterests);
    if (updated.contains(name)) {
      updated.remove(name);
    } else {
      updated.add(name);
    }
    onInterestsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.tag_rounded,
              color: AppColors.sakuraPink,
              size: 20.0,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                appStrings.selectInterests,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4.0),
        Text(
          appStrings.interestsHint,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12.0),

        // Wrap list of chips
        Wrap(
          spacing: 8.0,
          runSpacing: 10.0,
          children: availableTopics.map((topic) {
            final isSelected = selectedInterests.contains(topic.name);
            final icon = _getTopicIcon(topic.name);

            return GestureDetector(
              onTap: () => _toggleTopic(topic.name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 9.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.periwinkle.withValues(alpha: 0.22)
                      : AppColors.surfaceCardSubtle,
                  borderRadius: BorderRadius.circular(22.0),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.periwinkle
                        : AppColors.softSkyBlue.withValues(alpha: 0.2),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.periwinkle.withValues(alpha: 0.3),
                            blurRadius: 8.0,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      icon,
                      style: const TextStyle(fontSize: 14.0),
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      topic.name,
                      style: TextStyle(
                        fontSize: 13.0,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppColors.onSurface
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 6.0),
                      const Icon(
                        Icons.check_rounded,
                        size: 16.0,
                        color: AppColors.periwinkle,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
