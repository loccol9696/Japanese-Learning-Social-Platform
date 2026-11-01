import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../data/models/chat_models.dart';

/// Thẻ bộ từ vựng trong tin nhắn chia sẻ: biểu tượng, tên bộ, số thuật ngữ. Bấm để mở bộ thẻ.
class DeckShareCard extends StatelessWidget {
  final SharedDeck deck;
  final VoidCallback? onTap;

  const DeckShareCard({super.key, required this.deck, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!deck.available) return _buildUnavailable();

    return Material(
      color: AppPalette.background.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 220,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppPalette.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.style_rounded, color: AppPalette.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deck.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppPalette.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${deck.cardCount} thuật ngữ',
                        style: TextStyle(color: AppPalette.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppPalette.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnavailable() {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_clear_outlined, color: AppPalette.textSecondary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Bộ thẻ không còn khả dụng',
              style: TextStyle(color: AppPalette.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
