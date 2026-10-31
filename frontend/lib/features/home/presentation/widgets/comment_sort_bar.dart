import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/models/video_comment.dart';

/// Chọn thứ tự bình luận: hữu ích nhất hoặc mới nhất.
class CommentSortBar extends StatelessWidget {
  final CommentSort selected;
  final ValueChanged<CommentSort> onChanged;

  const CommentSortBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(
        children: [
          _buildChip(CommentSort.helpful, appStrings.commentSortHelpful),
          const SizedBox(width: 8),
          _buildChip(CommentSort.newest, appStrings.commentSortNewest),
        ],
      ),
    );
  }

  Widget _buildChip(CommentSort sort, String label) {
    final isSelected = sort == selected;
    return InkWell(
      onTap: isSelected ? null : () => onChanged(sort),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.accent : AppPalette.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppPalette.onAccent : AppPalette.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
