import 'package:flutter/material.dart';

import '../../../../core/localization/locale_manager.dart';
import '../../../../core/theme/app_palette.dart';

/// Nút "Hữu ích" của một bình luận (biểu tượng ở trên, số lượt ở dưới, đặt bên phải dòng bình luận). [onTap] null: chỉ hiện số lượt (bình luận của chính mình).
class CommentLikeButton extends StatelessWidget {
  final int likeCount;
  final bool isLiked;
  final VoidCallback? onTap;

  const CommentLikeButton({
    super.key,
    required this.likeCount,
    required this.isLiked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isLiked ? AppPalette.accent : AppPalette.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
              size: 20,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              likeCount > 0 ? '$likeCount' : appStrings.commentHelpful,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isLiked ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
