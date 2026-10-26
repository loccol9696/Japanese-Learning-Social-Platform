import 'package:flutter/material.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../../../core/theme/app_palette.dart';

class DeckCardItem extends StatelessWidget {
  final FlashcardSetModel deck;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const DeckCardItem({
    super.key,
    required this.deck,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          decoration: BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppPalette.textPrimary.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title + Action Icon (More Vert)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      deck.title,
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  // Wrapper positioning (relative + absolute popup menu right-aligned)
                  _DeckMoreMenuButton(
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Bottom Row: X thuật ngữ
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
      ),
    );
  }
}

class _DeckMoreMenuButton extends StatefulWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _DeckMoreMenuButton({
    this.onEdit,
    this.onDelete,
  });

  @override
  State<_DeckMoreMenuButton> createState() => _DeckMoreMenuButtonState();
}

class _DeckMoreMenuButtonState extends State<_DeckMoreMenuButton> {
  final OverlayPortalController _overlayController = OverlayPortalController();
  final LayerLink _layerLink = LayerLink();

  void _closeMenu() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Vùng nút cha (position: relative; display: inline-block)
    return CompositedTransformTarget(
      link: _layerLink,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (BuildContext context) {
          return Stack(
            children: [
              // Dismiss on tap outside
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeMenu,
                ),
              ),
              // 2. Canh lề chính xác: position: absolute; top: calc(100% + 4px); right: 0; z-index: 50
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(0, 4),
                child: UnconstrainedBox(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 148,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppPalette.surfaceHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppPalette.surfaceHighest,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppPalette.shadow,
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Mục 1: Chỉnh sửa
                        _MenuActionItem(
                          icon: Icons.edit_outlined,
                          title: 'Chỉnh sửa',
                          color: AppPalette.textPrimary,
                          onTap: () {
                            _closeMenu();
                            widget.onEdit?.call();
                          },
                        ),
                        const SizedBox(height: 4),
                        // Mục 2: Xóa
                        _MenuActionItem(
                          icon: Icons.delete_outline_rounded,
                          title: 'Xóa',
                          color: AppPalette.accent,
                          onTap: () {
                            _closeMenu();
                            widget.onDelete?.call();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            tooltip: 'Tùy chọn',
            splashRadius: 18,
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.more_vert_rounded,
              color: AppPalette.textSecondary,
              size: 20,
            ),
            onPressed: () {
              _overlayController.toggle();
            },
          ),
        ),
      ),
    );
  }
}

class _MenuActionItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _MenuActionItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  State<_MenuActionItem> createState() => _MenuActionItemState();
}

class _MenuActionItemState extends State<_MenuActionItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: AppPalette.accentSoft,
          highlightColor: AppPalette.accentSoft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isHovered ? AppPalette.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: widget.color,
                  size: 18,
                ),
                const SizedBox(width: 11),
                Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
