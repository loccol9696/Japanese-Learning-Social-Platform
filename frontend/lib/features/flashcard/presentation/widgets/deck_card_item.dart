import 'package:flutter/material.dart';

import '../../data/models/flashcard_set_model.dart';
import '../../../../core/theme/app_palette.dart';

class DeckCardItem extends StatelessWidget {
  final FlashcardSetModel deck;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Vị trí trong danh sách kéo thả; có giá trị thì hiện biểu tượng ⠿ để kéo ngay (không cần nhấn giữ).
  final int? dragIndex;

  const DeckCardItem({
    super.key,
    required this.deck,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deck.title,
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${deck.totalCards} thuật ngữ',
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (dragIndex != null)
                ReorderableDragStartListener(
                  index: dragIndex!,
                  child: Container(
                    key: ValueKey('deck-drag-handle-${deck.setId}'),
                    color: Colors.transparent,
                    padding: const EdgeInsets.fromLTRB(14, 12, 0, 12),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: AppPalette.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
