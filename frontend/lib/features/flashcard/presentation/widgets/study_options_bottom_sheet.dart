import 'package:flutter/material.dart';
import '../../../../core/theme/app_palette.dart';

class StudyOptions {
  bool shuffle;
  bool starredOnly;
  String displayFrontFace; // 'term' or 'definition'
  String? frontLanguage; // Tương thích Hot Reload

  StudyOptions({
    this.shuffle = false,
    this.starredOnly = false,
    this.displayFrontFace = 'term',
    this.frontLanguage,
  });

  StudyOptions copyWith({
    bool? shuffle,
    bool? starredOnly,
    String? displayFrontFace,
    String? frontLanguage,
  }) {
    return StudyOptions(
      shuffle: shuffle ?? this.shuffle,
      starredOnly: starredOnly ?? this.starredOnly,
      displayFrontFace: displayFrontFace ?? this.displayFrontFace,
      frontLanguage: frontLanguage ?? this.frontLanguage,
    );
  }
}

class StudyOptionsBottomSheet extends StatefulWidget {
  final StudyOptions options;
  final VoidCallback onResetProgress;
  final ValueChanged<StudyOptions> onOptionsChanged;

  const StudyOptionsBottomSheet({
    super.key,
    required this.options,
    required this.onResetProgress,
    required this.onOptionsChanged,
  });

  @override
  State<StudyOptionsBottomSheet> createState() => _StudyOptionsBottomSheetState();
}

class _StudyOptionsBottomSheetState extends State<StudyOptionsBottomSheet> {
  late bool _shuffle;
  late bool _starredOnly;
  late String _displayFrontFace;

  @override
  void initState() {
    super.initState();
    _shuffle = widget.options.shuffle;
    _starredOnly = widget.options.starredOnly;
    _displayFrontFace = widget.options.displayFrontFace;
  }

  void _notifyChange() {
    widget.onOptionsChanged(StudyOptions(
      shuffle: _shuffle,
      starredOnly: _starredOnly,
      displayFrontFace: _displayFrontFace,
    ));
  }

  void _showResetConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppPalette.border, width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppPalette.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.restart_alt_rounded,
                color: AppPalette.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Đặt lại tiến trình',
                style: TextStyle(
                  color: AppPalette.onAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn đặt lại toàn bộ tiến trình học của bộ thẻ này về 0 không?',
          style: TextStyle(
            color: AppPalette.textPrimary.withValues(alpha: 0.75),
            fontSize: 14.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Hủy',
              style: TextStyle(color: AppPalette.textPrimary.withValues(alpha: 0.65)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.accent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
              widget.onResetProgress();
            },
            child: Text(
              'Đặt lại',
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Xanh tím nhạt cho chữ và icon của nút đặt lại tiến trình.
  static Color get _resetTint => AppPalette.accent;

  @override
  Widget build(BuildContext context) {
    // Material (không phải Container tô màu) để hiệu ứng chạm hiển thị đúng.
    return Material(
      color: AppPalette.navBar,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo (Drag handle)
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppPalette.textSecondary.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tùy chọn học',
                    style: TextStyle(
                      color: AppPalette.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppPalette.textSecondary,
                      size: 24,
                    ),
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Nhóm 1: CÀI ĐẶT ÔN TẬP
              _buildSectionLabel('CÀI ĐẶT ÔN TẬP'),
              _buildSwitchRow(
                title: 'Trộn thẻ ngẫu nhiên',
                value: _shuffle,
                onChanged: (val) {
                  setState(() => _shuffle = val);
                  _notifyChange();
                },
              ),
              Divider(height: 1, color: AppPalette.border),
              _buildSwitchRow(
                title: 'Chỉ học từ gắn sao',
                value: _starredOnly,
                onChanged: (val) {
                  setState(() => _starredOnly = val);
                  _notifyChange();
                },
              ),
              const SizedBox(height: 22),

              // Nhóm 2: HIỂN THỊ
              _buildSectionLabel('HIỂN THỊ'),
              Divider(height: 1, color: AppPalette.border),
              Padding(
                padding: EdgeInsets.only(top: 16, bottom: 12),
                child: Text(
                  'Mặt thẻ hiển thị trước',
                  style: TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 16,
                  ),
                ),
              ),
              _buildFaceSegmentedControl(),
              const SizedBox(height: 26),

              // Đặt lại tiến trình
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: AppPalette.accent.withValues(alpha: 0.2),
                    foregroundColor: _resetTint,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _showResetConfirmDialog(context),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'Đặt lại tiến trình thẻ',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// Một hàng "tiêu đề + công tắc" (công tắc luôn có núm trắng).
  Widget _buildSwitchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppPalette.textPrimary,
                  fontSize: 16,
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              thumbColor: WidgetStatePropertyAll(AppPalette.textPrimary),
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppPalette.accent
                    : AppPalette.surfaceHigh,
              ),
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Thuật ngữ | Định nghĩa": rãnh tối, mặt đang chọn nền màu nhấn.
  Widget _buildFaceSegmentedControl() {
    Widget segment(String label, String face) {
      final selected = _displayFrontFace == face;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() => _displayFrontFace = face);
            _notifyChange();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppPalette.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppPalette.textPrimary
                    : AppPalette.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppPalette.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          segment('Thuật ngữ', 'term'),
          segment('Định nghĩa', 'definition'),
        ],
      ),
    );
  }
}
