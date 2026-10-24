import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_palette.dart';
import '../../data/models/flashcard_set_model.dart';
import '../../data/models/study_session_model.dart';
import '../../data/services/flashcard_service.dart';
import '../../data/services/flashcard_store.dart';
import '../../data/services/study_session_controller.dart';
import '../../data/services/study_reminder_service.dart';
import '../widgets/learning_header.dart';
import '../widgets/study_options_bottom_sheet.dart';

/// Học thẻ ghi nhớ theo kiểu ngắt quãng: thẻ bấm Xem lại / Khó / Ổn sẽ lặp lại
/// trong phiên, chỉ bấm Dễ thì thẻ mới rời phiên và được hẹn ngày ôn kế tiếp.
class SrsStudyScreen extends StatefulWidget {
  final FlashcardSetModel deck;

  const SrsStudyScreen({super.key, required this.deck});

  @override
  State<SrsStudyScreen> createState() => _SrsStudyScreenState();
}

class _SrsStudyScreenState extends State<SrsStudyScreen>
    with SingleTickerProviderStateMixin {
  final FlashcardService _service = FlashcardService.instance;
  late final AnimationController _flipController;

  StudySessionController? _controller;
  StudyOptions _options = StudyOptions();
  DueSummary? _dueSummary;

  bool _isLoading = true;
  String? _error;
  bool _isFront = true;
  bool _isPlayingAudio = false;
  Timer? _audioTimeoutTimer;
  bool _finishHandled = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _loadSession();
  }

  @override
  void dispose() {
    _stopAudio();
    _controller?.removeListener(_onControllerChanged);
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final session = await _service.getStudySession(widget.deck.setId);
      var cards = session.cards;
      if (_options.starredOnly) {
        cards = cards.where((c) => c.card.isStarred).toList();
      }
      if (_options.shuffle) {
        cards = List.of(cards)..shuffle();
      }
      _controller?.removeListener(_onControllerChanged);
      final controller = StudySessionController(
        cards: cards,
        sendReview: (id, rating) => _service.reviewCard(id, rating),
      )..addListener(_onControllerChanged);

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _isFront = true;
        _finishHandled = false;
        _flipController.reset();
        _isLoading = false;
      });
      if (controller.isFinished) _handleFinished();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được phiên học. Vui lòng thử lại.';
        _isLoading = false;
      });
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  /// Phiên xong: nạp lịch ôn kế tiếp và hẹn nhắc nhở.
  Future<void> _handleFinished() async {
    if (_finishHandled) return;
    _finishHandled = true;
    FlashcardStore.instance.invalidateAll();
    try {
      final summary = await _service.getDueSummary();
      if (!mounted) return;
      setState(() => _dueSummary = summary);
      await StudyReminderService.instance.scheduleFor(summary);
    } catch (_) {
      // Không có lịch ôn thì chỉ ẩn dòng "Lần ôn tiếp theo".
    }
  }

  void _flip() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  Future<void> _rate(ReviewRating rating) async {
    final controller = _controller;
    if (controller == null || controller.isFinished || _isFront) return;
    _stopAudio();
    setState(() {
      _isFront = true;
      _flipController.reset();
    });
    await controller.rate(rating);
    if (controller.isFinished) _handleFinished();
  }

  void _stopAudio() {
    _audioTimeoutTimer?.cancel();
    _audioTimeoutTimer = null;
    TtsService.stop();
    if (_isPlayingAudio && mounted) {
      setState(() => _isPlayingAudio = false);
    }
  }

  void _playAudio() {
    final card = _controller?.current?.card;
    if (card == null) return;
    final termFirst = _options.displayFrontFace == 'term';
    final speakTerm = _isFront == termFirst;
    final text = speakTerm ? card.term : card.meaning;
    if (text.trim().isEmpty) return;

    _audioTimeoutTimer?.cancel();
    setState(() => _isPlayingAudio = true);
    _audioTimeoutTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlayingAudio) setState(() => _isPlayingAudio = false);
    });
    TtsService.speak(
      text: text,
      lang: speakTerm ? 'ja-JP' : 'vi-VN',
      rate: speakTerm ? 0.9 : 1.0,
      onStart: () {
        if (mounted && !_isPlayingAudio) setState(() => _isPlayingAudio = true);
      },
      onComplete: () {
        _audioTimeoutTimer?.cancel();
        if (mounted) setState(() => _isPlayingAudio = false);
      },
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StudyOptionsBottomSheet(
        options: _options,
        onOptionsChanged: (next) {
          setState(() => _options = next);
          _loadSession();
        },
        onResetProgress: () async {
          await _service.resetProgress(widget.deck.setId);
          FlashcardStore.instance.invalidateAll();
          _loadSession();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: AppPalette.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppPalette.accent),
              )
            : _error != null
            ? _buildError()
            : controller == null || controller.isFinished
            ? _buildSummary(controller)
            : _buildStudy(controller),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error!,
            style: const TextStyle(color: AppPalette.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: _loadSession, child: const Text('Thử lại')),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- học

  Widget _buildStudy(StudySessionController controller) {
    final study = controller.current!;
    return Column(
      children: [
        LearningHeader(
          currentIndex: controller.graduated,
          totalItems: controller.total,
          onClose: () => Navigator.of(context).pop(),
          onSettingsClick: _openSettings,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: GestureDetector(
              onTap: _flip,
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: _flipController,
                builder: (context, _) {
                  final angle = _flipController.value * pi;
                  final showBack = angle > pi / 2;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(angle),
                    child: showBack
                        ? Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(pi),
                            child: _buildCardShell(study, _buildBack(study)),
                          )
                        : _buildCardShell(study, _buildFront(study)),
                  );
                },
              ),
            ),
          ),
        ),
        _buildRatingBar(study),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCardShell(StudyCard study, Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppPalette.border, width: 1.2),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(child: _buildStateBadge(study.stateLabel)),
          ),
          Positioned(top: 14, right: 16, child: _buildAudioButton()),
          Center(child: child),
        ],
      ),
    );
  }

  Widget _buildStateBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppPalette.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAudioButton() {
    return GestureDetector(
      onTap: _playAudio,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _isPlayingAudio
              ? AppPalette.accent.withValues(alpha: 0.25)
              : AppPalette.surfaceHigh,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.volume_up_rounded,
          color: _isPlayingAudio ? AppPalette.accent : AppPalette.textPrimary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildFront(StudyCard study) {
    final card = study.card;
    final isTerm = _options.displayFrontFace == 'term';
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        isTerm ? card.term : card.meaning,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppPalette.textPrimary,
          fontSize: isTerm ? 44 : 28,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildBack(StudyCard study) {
    final card = study.card;
    final isTerm = _options.displayFrontFace == 'term';
    final reading = card.reading ?? '';
    final sino = card.sinoVietnamese ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 72, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isTerm)
            Text(
              card.term,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (reading.isNotEmpty)
            Text(
              reading,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.textPrimary,
                fontSize: isTerm ? 30 : 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (sino.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              sino.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (isTerm) ...[
            const SizedBox(height: 6),
            Text(
              card.meaning,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 24,
              ),
            ),
          ],
          if (card.example != null && card.example!.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Divider(color: AppPalette.border),
            const SizedBox(height: 10),
            Text(
              card.example!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppPalette.textSecondary,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingBar(StudyCard study) {
    const ratings = ReviewRating.values;
    final enabled = !_isFront;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    for (var i = 0; i < ratings.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(
                        child: Material(
                          color: AppPalette.surfaceHigh,
                          child: InkWell(
                            onTap: enabled ? () => _rate(ratings[i]) : null,
                            child: Center(
                              child: Text(
                                ratings[i].label,
                                style: const TextStyle(
                                  color: AppPalette.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final rating in ratings)
                  Expanded(
                    child: Text(
                      rating == ReviewRating.easy
                          ? study.labelFor(rating)
                          : 'Tối đa ${study.labelFor(rating)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppPalette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ tổng kết

  Widget _buildSummary(StudySessionController? controller) {
    final studied = controller?.total ?? 0;
    final nothingToStudy = studied == 0;
    final summary = _dueSummary;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            icon: const Icon(Icons.close, color: AppPalette.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nothingToStudy
                      ? 'Hôm nay không còn thẻ cần ôn'
                      : 'Hoàn thành phiên học!',
                  style: const TextStyle(
                    color: AppPalette.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                if (!nothingToStudy)
                  Text(
                    'Bạn đã nhớ $studied thẻ sau ${controller!.reviews} lượt ôn.',
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                if (summary?.nextDueAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Lần ôn tiếp theo: ${_formatNextDue(summary!.nextDueAt!)}'
                    ' (${summary.dueAtNextCount} thẻ).',
                    style: const TextStyle(
                      color: AppPalette.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.accent,
                foregroundColor: AppPalette.textPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Xong',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatNextDue(DateTime at) {
    final now = DateTime.now();
    final diff = at.difference(now);
    if (diff.inMinutes < 60) return 'sau ${max(1, diff.inMinutes)} phút';
    if (diff.inHours < 24) return 'sau ${diff.inHours} giờ';
    return 'sau ${diff.inDays} ngày';
  }
}
