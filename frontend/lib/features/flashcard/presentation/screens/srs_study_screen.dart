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
    with TickerProviderStateMixin {
  static const Color _badgeBlue = Color(0xFF8F9BFF);

  final FlashcardService _service = FlashcardService.instance;
  late final AnimationController _flipController;
  late final AnimationController _settleController;
  Animation<Offset>? _settleAnimation;

  /// Vị trí kéo thẻ hiện tại; kéo đủ xa theo hướng nào sẽ chọn mức đánh giá đó.
  Offset _drag = Offset.zero;
  bool _isDragging = false;
  bool _isSettling = false;

  static const double _showThreshold = 36;
  static const double _commitThreshold = 110;
  static const double _verticalSplit = 50;

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
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        final anim = _settleAnimation;
        if (anim != null) setState(() => _drag = anim.value);
      });
    _loadSession();
  }

  @override
  void dispose() {
    _settleController.dispose();
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
    if (controller == null || controller.isFinished) return;
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

  void _toggleStar() {
    final controller = _controller;
    final study = controller?.current;
    if (controller == null || study == null) return;
    final card = study.card;
    final starred = !card.isStarred;
    _service.updateStar(card.cardId, starred);
    controller.replaceCurrent(study.withCard(card.copyWith(isStarred: starred)));
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _buildDraggableCard(study),
          ),
        ),
        _buildRatingBar(study),
        const SizedBox(height: 16),
      ],
    );
  }

  // ------------------------------------------------------------ kéo thẻ

  /// Mức đánh giá ứng với hướng kéo: phải = Dễ; trái = Ổn (lên) / Khó (ngang) /
  /// Xem lại (xuống).
  ReviewRating? _ratingForDrag(Offset d) {
    if (d.distance < _showThreshold) return null;
    if (d.dx > 0) return ReviewRating.easy;
    if (d.dy < -_verticalSplit) return ReviewRating.good;
    if (d.dy > _verticalSplit) return ReviewRating.again;
    return ReviewRating.hard;
  }

  static Color _ratingColor(ReviewRating r) => switch (r) {
    ReviewRating.again => const Color(0xFFFF9F43),
    ReviewRating.hard => const Color(0xFFC77DFF),
    ReviewRating.good => const Color(0xFF38BDF8),
    ReviewRating.easy => const Color(0xFF34D399),
  };

  static IconData _ratingIcon(ReviewRating r) => switch (r) {
    ReviewRating.again || ReviewRating.hard => Icons.refresh_rounded,
    ReviewRating.good || ReviewRating.easy => Icons.check_rounded,
  };

  void _onPanStart(DragStartDetails d) {
    if (_isSettling) return;
    _settleController.stop();
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!_isDragging) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (!_isDragging) return;
    _isDragging = false;
    final rating = _ratingForDrag(_drag);
    if (rating != null && _drag.distance > _commitThreshold) {
      _flyOutAndRate(rating);
    } else {
      _animateDragTo(Offset.zero);
    }
  }

  void _animateDragTo(Offset target, {VoidCallback? onDone}) {
    _settleAnimation = Tween<Offset>(begin: _drag, end: target).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOut),
    );
    _settleController.forward(from: 0).then((_) {
      if (!mounted) return;
      onDone?.call();
    });
  }

  void _flyOutAndRate(ReviewRating rating) {
    setState(() => _isSettling = true);
    final dir = _drag / _drag.distance;
    _animateDragTo(dir * 700, onDone: () async {
      setState(() {
        _drag = Offset.zero;
        _isSettling = false;
      });
      await _rate(rating);
    });
  }

  Widget _buildDraggableCard(StudyCard study) {
    final rating = _ratingForDrag(_drag);
    final angle = (_drag.dx / 300).clamp(-1.0, 1.0) * (15 * pi / 180);
    final overlayOpacity = rating == null
        ? 0.0
        : ((_drag.distance - _showThreshold) / 50).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: _flip,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      behavior: HitTestBehavior.opaque,
      child: Transform.translate(
        offset: _drag,
        child: Transform.rotate(
          angle: angle,
          child: Stack(
            children: [
              Positioned.fill(child: _buildFlipCard(study)),
              if (rating != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: overlayOpacity,
                    child: _buildRatingOverlay(study, rating),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingOverlay(StudyCard study, ReviewRating rating) {
    final color = _ratingColor(rating);
    final when = rating == ReviewRating.easy
        ? 'Quay lại sau ${study.labelFor(rating)}'
        : 'Quay lại sau tối đa ${study.labelFor(rating)}';
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color, width: 1.6),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_ratingIcon(rating), color: color, size: 38),
            const SizedBox(height: 14),
            Text(
              rating.label,
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                when,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlipCard(StudyCard study) {
    return AnimatedBuilder(
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
    );
  }

  Widget _buildCardShell(StudyCard study, Widget child) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(child: _buildStateBadge(study.stateLabel)),
          ),
          Positioned(top: 6, left: 8, child: _buildAudioButton()),
          Positioned(top: 6, right: 8, child: _buildStarButton(study)),
          Center(child: child),
        ],
      ),
    );
  }

  Widget _buildStateBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppPalette.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _badgeBlue,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildAudioButton() {
    return IconButton(
      onPressed: _playAudio,
      icon: Icon(
        Icons.volume_up_outlined,
        size: 20,
        color: _isPlayingAudio ? AppPalette.accent : AppPalette.textSecondary,
      ),
    );
  }

  Widget _buildStarButton(StudyCard study) {
    final starred = study.card.isStarred;
    return IconButton(
      onPressed: _toggleStar,
      icon: Icon(
        starred ? Icons.star_rounded : Icons.star_border_rounded,
        size: 22,
        color: starred ? const Color(0xFFFFCC00) : AppPalette.textSecondary,
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
    final pending = _ratingForDrag(_drag);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < ratings.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: pending == ratings[i]
                    ? _ratingColor(ratings[i])
                    : AppPalette.surface,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _rate(ratings[i]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ratings[i].label,
                          style: TextStyle(
                            color: pending == ratings[i]
                                ? AppPalette.background
                                : AppPalette.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          study.labelFor(ratings[i]),
                          style: TextStyle(
                            color: pending == ratings[i]
                                ? AppPalette.background
                                : AppPalette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
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
