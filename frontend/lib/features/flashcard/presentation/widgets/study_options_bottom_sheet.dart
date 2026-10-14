import 'package:flutter/material.dart';

class StudyOptions {
  bool shuffle;
  bool starredOnly;
  String frontLanguage; // 'ja' or 'vi'

  StudyOptions({
    this.shuffle = true,
    this.starredOnly = false,
    this.frontLanguage = 'ja',
  });
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
  late String _frontLanguage;

  @override
  void initState() {
    super.initState();
    _shuffle = widget.options.shuffle;
    _starredOnly = widget.options.starredOnly;
    _frontLanguage = widget.options.frontLanguage;
  }

  void _notifyChange() {
    widget.onOptionsChanged(StudyOptions(
      shuffle: _shuffle,
      starredOnly: _starredOnly,
      frontLanguage: _frontLanguage,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF141721),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CÀI ĐẶT ÔN TẬP
            Text(
              'CÀI ĐẶT ÔN TẬP',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C202C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Trộn thẻ ngẫu nhiên',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    value: _shuffle,
                    activeColor: const Color(0xFFFF2D55),
                    onChanged: (val) {
                      setState(() => _shuffle = val);
                      _notifyChange();
                    },
                  ),
                  Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                  SwitchListTile(
                    title: const Text(
                      'Chỉ học từ gắn sao',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    value: _starredOnly,
                    activeColor: const Color(0xFFFF2D55),
                    onChanged: (val) {
                      setState(() => _starredOnly = val);
                      _notifyChange();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // HIỂN THỊ
            Text(
              'HIỂN THỊ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C202C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mặt thẻ hiển thị trước',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF12141D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _frontLanguage = 'ja');
                              _notifyChange();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _frontLanguage == 'ja'
                                    ? const Color(0xFFFF2D55)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Tiếng Nhật',
                                style: TextStyle(
                                  color: _frontLanguage == 'ja'
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _frontLanguage = 'vi');
                              _notifyChange();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _frontLanguage == 'vi'
                                    ? const Color(0xFFFF2D55)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Tiếng Việt',
                                style: TextStyle(
                                  color: _frontLanguage == 'vi'
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.6),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ĐẶT LẠI
            Text(
              'ĐẶT LẠI',
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.pop(context);
                  widget.onResetProgress();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C202C),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.refresh, color: Color(0xFFFF453A), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Đặt lại tiến trình thẻ',
                        style: TextStyle(
                          color: Color(0xFFFF453A),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
