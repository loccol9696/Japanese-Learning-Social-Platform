import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_palette.dart';
import '../../domain/models/topic_model.dart';

/// Chọn sở thích: lưới 3 cột các ô chip, ô đang chọn có nền màu nhấn.
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

  static const int _columns = 3;
  static const double _gap = 8.0;

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
        Text(
          appStrings.selectInterests,
          style: const TextStyle(
            fontSize: 13.0,
            color: AppPalette.textSecondary,
          ),
        ),
        const SizedBox(height: 8.0),
        LayoutBuilder(
          builder: (context, constraints) {
            final chipWidth =
                (constraints.maxWidth - _gap * (_columns - 1)) / _columns;

            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: availableTopics
                  .map((topic) => _buildChip(topic.name, chipWidth))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildChip(String name, double width) {
    final isSelected = selectedInterests.contains(name);

    return GestureDetector(
      onTap: () => _toggleTopic(name),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        constraints: const BoxConstraints(minHeight: 42.0),
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.accent : AppPalette.surfaceHigh,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppPalette.textPrimary
                : AppPalette.textPrimary.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
