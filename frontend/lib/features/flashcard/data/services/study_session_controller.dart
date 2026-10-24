import 'package:flutter/foundation.dart';

import '../models/study_session_model.dart';

/// Gửi một lần đánh giá lên server.
typedef ReviewSender = Future<void> Function(int cardId, ReviewRating rating);

/// Hàng đợi của một phiên học ngắt quãng.
///
/// Xem lại / Khó / Ổn: thẻ quay lại hàng đợi sau vài thẻ khác.
/// Dễ: thẻ rời phiên. Phiên xong khi hàng đợi rỗng.
class StudySessionController extends ChangeNotifier {
  /// Số thẻ khác xen giữa trước khi thẻ xuất hiện lại.
  static const Map<ReviewRating, int> repeatGap = {
    ReviewRating.again: 2,
    ReviewRating.hard: 5,
    ReviewRating.good: 10,
  };

  StudySessionController({
    required List<StudyCard> cards,
    required ReviewSender sendReview,
  }) : _queue = List<StudyCard>.of(cards),
       total = cards.length,
       _sendReview = sendReview;

  final ReviewSender _sendReview;
  final List<StudyCard> _queue;

  /// Tổng số thẻ của phiên.
  final int total;
  int _graduated = 0;
  int _reviews = 0;
  final Map<int, int> _againCounts = {};

  /// Số thẻ đã bấm "Dễ".
  int get graduated => _graduated;

  /// Tổng số lượt đánh giá (kể cả thẻ lặp lại).
  int get reviews => _reviews;

  bool get isFinished => _queue.isEmpty;

  StudyCard? get current => _queue.isEmpty ? null : _queue.first;

  /// Số thẻ còn lại trong hàng đợi.
  int get remaining => _queue.length;

  /// Các thẻ bị bấm "Xem lại" nhiều nhất trong phiên (giảm dần).
  List<int> get hardestCardIds {
    final entries = _againCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  /// Cập nhật thẻ hiện tại (vd. gắn sao) mà không đổi vị trí.
  void replaceCurrent(StudyCard updated) {
    if (_queue.isEmpty) return;
    _queue[0] = updated;
    notifyListeners();
  }

  /// Ghi nhận đánh giá cho thẻ hiện tại.
  Future<void> rate(ReviewRating rating) async {
    if (_queue.isEmpty) return;
    final card = _queue.removeAt(0);
    _reviews++;

    if (rating.graduates) {
      _graduated++;
    } else {
      if (rating == ReviewRating.again) {
        _againCounts.update(card.card.cardId, (v) => v + 1, ifAbsent: () => 1);
      }
      final gap = repeatGap[rating] ?? repeatGap[ReviewRating.good]!;
      final at = gap < _queue.length ? gap : _queue.length;
      _queue.insert(at, card);
    }
    notifyListeners();

    try {
      await _sendReview(card.card.cardId, rating);
    } catch (e) {
      // Lỗi mạng không chặn việc học; lần mở sau thẻ sẽ được lên lịch lại.
      debugPrint('Không gửi được đánh giá thẻ ${card.card.cardId}: $e');
    }
  }
}
