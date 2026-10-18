import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

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

  static const _sectionLabelStyle = TextStyle(
    color: AppColors.socialTextMuted,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  static final _panelDecoration = BoxDecoration(
    color: AppColors.flashPanel,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
  );

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
        backgroundColor: AppColors.socialSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.flashBorder, width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.flashCoral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.restart_alt_rounded,
                color: AppColors.flashCoral,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Đặt lại tiến trình',
                style: TextStyle(
                  color: Colors.white,
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
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 14.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Hủy',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.flashCoral,
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
            child: const Text(
              'Đặt lại',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
      ),
      value: value,
      activeThumbColor: AppColors.flashCoral,
      onChanged: (val) {
        setState(() => onChanged(val));
        _notifyChange();
      },
    );
  }

  /// Một nửa của nút chọn mặt thẻ hiển thị trước ('term' / 'definition').
  Widget _frontFaceOption(String value, String label) {
    final selected = _displayFrontFace == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _displayFrontFace = value);
          _notifyChange();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.flashCoral : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.socialTextMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.socialSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tùy chọn học',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Nhóm 1: CÀI ĐẶT ÔN TẬP
            const Text('CÀI ĐẶT ÔN TẬP', style: _sectionLabelStyle),
            const SizedBox(height: 8),
            Container(
              decoration: _panelDecoration,
              // Material trong suốt để SwitchListTile vẽ được hiệu ứng chạm trên nền panel.
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    _switchTile('Trộn thẻ ngẫu nhiên', _shuffle, (val) => _shuffle = val),
                    Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                    _switchTile('Chỉ học từ gắn sao', _starredOnly, (val) => _starredOnly = val),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Nhóm 2: HIỂN THỊ
            const Text('HIỂN THỊ', style: _sectionLabelStyle),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _panelDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mặt thẻ hiển thị trước',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.flashInset,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _frontFaceOption('term', 'Thuật ngữ'),
                        _frontFaceOption('definition', 'Định nghĩa'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Nhóm 3: ĐẶT LẠI
            const Text('ĐẶT LẠI', style: _sectionLabelStyle),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showResetConfirmDialog(context),
                borderRadius: BorderRadius.circular(16),
                // Ink (không phải Container) để hiệu ứng chạm vẽ đè lên nền panel.
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: _panelDecoration,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restart_alt_rounded, color: AppColors.flashCoral, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Đặt lại tiến trình thẻ',
                        style: TextStyle(
                          color: AppColors.flashCoral,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
