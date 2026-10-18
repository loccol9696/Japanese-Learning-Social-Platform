import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/topic_model.dart';

/// Chọn nhiều chủ đề quan tâm; chip đang chọn nền trắng chữ đen.
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

  void _toggle(String name) {
    final updated = List<String>.from(selectedInterests);
    if (!updated.remove(name)) updated.add(name);
    onInterestsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        for (final topic in availableTopics)
          _TopicChip(
            label: topic.name,
            selected: selectedInterests.contains(topic.name),
            onTap: () => _toggle(topic.name),
          ),
      ],
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopicChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: selected ? Colors.white : AppColors.socialSurface,
        borderRadius: BorderRadius.circular(18.0),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 8.0,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
