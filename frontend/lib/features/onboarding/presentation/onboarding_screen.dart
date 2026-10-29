import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/swipe_back_detector.dart';
import '../data/onboarding_service.dart';

/// Câu hỏi chào mừng 2 bước: trình độ, rồi sở thích (ít nhất 1). Chỉ thoát bằng "Tiếp tục" đến hết hoặc "Bỏ qua".
///
/// Nút Back hệ thống và vuốt quay lại đều không thoát màn này: [PopScope] chặn Back, [SwipeBackBlocker] chặn vuốt.
/// Ở bước 2, "‹" chỉ quay về bước 1 chứ không thoát.
class OnboardingScreen extends StatefulWidget {
  /// Gọi khi người dùng đã trả lời hoặc bỏ qua xong; nơi gọi tự quyết định mở màn tiếp theo.
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _levels = <(String, String)>[
    ('N5', 'Câu chào hỏi cơ bản'),
    ('N4', 'Hội thoại hằng ngày'),
    ('N3', 'Hiểu nội dung quen thuộc'),
    ('N2', 'Đọc báo, xem phim'),
    ('N1', 'Gần như thành thạo'),
  ];

  final OnboardingService _service = OnboardingService.instance;

  int _step = 0;
  String? _level;
  final Set<int> _topicIds = {};
  List<OnboardingTopic> _topics = const [];

  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final status = await _service.getStatus();
      if (!mounted) return;
      setState(() {
        _topics = status.availableTopics;
        // Điền sẵn đáp án cũ (nếu người dùng đã từng trả lời một phần) để không phải chọn lại.
        _level = status.jlptLevel;
        _topicIds
          ..clear()
          ..addAll(status.topicIds);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Không tải được câu hỏi. Kiểm tra kết nối rồi thử lại.';
      });
    }
  }

  bool get _canContinue => _step == 0 ? _level != null : _topicIds.isNotEmpty;

  Future<void> _continue() async {
    if (_busy || !_canContinue) return;
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.save(jlptLevel: _level!, topicIds: _topicIds);
      if (!mounted) return;
      widget.onFinished();
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          'Chưa lưu được. Vui lòng thử lại.',
          context: context,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _skip() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.skip();
      if (!mounted) return;
      widget.onFinished();
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          'Chưa bỏ qua được. Vui lòng thử lại.',
          context: context,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step = 0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: SwipeBackBlocker(
        child: Scaffold(
          backgroundColor: AppPalette.background,
          body: SafeArea(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? _buildError()
                : Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: _step == 0
                              ? _buildLevelStep()
                              : _buildTopicStep(),
                        ),
                      ),
                      _buildBottom(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppPalette.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
            TextButton(
              onPressed: _busy ? null : _skip,
              child: const Text('Bỏ qua'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: _step == 1
                    ? IconButton(
                        key: const ValueKey('onboarding-back'),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: AppPalette.textPrimary,
                        ),
                        onPressed: _busy ? null : _back,
                      )
                    : null,
              ),
              const Spacer(),
              TextButton(
                key: const ValueKey('onboarding-skip'),
                onPressed: _busy ? null : _skip,
                child: Text(
                  'Bỏ qua',
                  style: TextStyle(color: AppPalette.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    key: ValueKey('onboarding-progress-$i'),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= _step ? AppPalette.accent : AppPalette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trình độ tiếng Nhật của bạn?',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chọn mức gần nhất, bạn có thể đổi sau.',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
        const SizedBox(height: 24),
        for (final (code, desc) in _levels) ...[
          _LevelTile(
            key: ValueKey('level-$code'),
            code: code,
            description: desc,
            selected: _level == code,
            onTap: () => setState(() => _level = code),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildTopicStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sở thích của bạn là gì?',
          style: TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Chọn một hoặc nhiều chủ đề.',
          style: TextStyle(color: AppPalette.textSecondary),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final topic in _topics)
              _TopicChip(
                key: ValueKey('topic-${topic.id}'),
                label: topic.name,
                selected: _topicIds.contains(topic.id),
                onTap: () => setState(() {
                  if (!_topicIds.remove(topic.id)) _topicIds.add(topic.id);
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottom() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          key: const ValueKey('onboarding-continue'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.accent,
            disabledBackgroundColor: AppPalette.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: (!_canContinue || _busy) ? null : _continue,
          child: _busy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppPalette.onAccent,
                  ),
                )
              : Text(
                  'Tiếp tục',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _canContinue
                        ? AppPalette.onAccent
                        : AppPalette.textSecondary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final String code;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _LevelTile({
    super.key,
    required this.code,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppPalette.accentSoft : AppPalette.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppPalette.accent : AppPalette.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      code,
                      style: TextStyle(
                        color: AppPalette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppPalette.accent : AppPalette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TopicChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppPalette.accent : AppPalette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppPalette.accent : AppPalette.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppPalette.onAccent : AppPalette.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
