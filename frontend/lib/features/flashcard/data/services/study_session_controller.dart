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

  /// Đánh giá chưa gửi được (mất mạng...), gửi lại theo đúng thứ tự ở lần gửi kế tiếp hoặc khi [flushUnsent].
  final List<(int, ReviewRating)> _unsent = [];

  /// Các lần gửi chạy lần lượt, không chồng nhau, để thứ tự đánh giá của cùng một thẻ không bị đảo.
  Future<void> _tail = Future<void>.value();

  /// Số đánh giá còn chưa gửi lên server.
  int get unsentCount => _unsent.length;

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

  /// Nhãn dưới nút chấm điểm cho thẻ hiện tại: thẻ "Xem lại / Khó / Ổn" quay lại theo số thẻ xen giữa (không theo
  /// phút), hoặc "Ngay" nếu hàng đợi không còn đủ thẻ khác. Null với mức "Dễ" (thẻ rời phiên, dùng nhãn ngày của server).
  String? repeatLabel(ReviewRating rating) {
    if (rating.graduates) return null;
    final gap = repeatGap[rating] ?? repeatGap[ReviewRating.good]!;
    final others = _queue.isEmpty ? 0 : _queue.length - 1;
    final n = gap < others ? gap : others;
    return n <= 0 ? 'Ngay' : 'Sau $n thẻ';
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

    await _enqueue(() {
      _unsent.add((card.card.cardId, rating));
      return _flush();
    });
  }

  /// Gửi lại các đánh giá còn tồn (gọi khi hết phiên hoặc rời màn học).
  Future<void> flushUnsent() => _enqueue(_flush);

  Future<void> _enqueue(Future<void> Function() job) {
    _tail = _tail.then((_) => job());
    return _tail;
  }

  /// Gửi lần lượt; gặp lỗi thì giữ lại phần còn lại cho lần sau. Lỗi mạng không chặn việc học.
  Future<void> _flush() async {
    while (_unsent.isNotEmpty) {
      final (cardId, rating) = _unsent.first;
      try {
        await _sendReview(cardId, rating);
        _unsent.removeAt(0);
      } catch (e) {
        debugPrint('Không gửi được đánh giá thẻ $cardId, sẽ thử lại: $e');
        return;
      }
    }
  }
}
