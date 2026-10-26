import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/flashcard/data/models/flashcard_item_model.dart';
import 'package:frontend/features/flashcard/data/models/study_session_model.dart';
import 'package:frontend/features/flashcard/data/services/study_reminder_service.dart';
import 'package:frontend/features/flashcard/data/services/study_session_controller.dart';

StudyCard _card(int id) => StudyCard(
  card: FlashcardItemModel(cardId: id, term: 't$id', meaning: 'm$id'),
  state: 'NEW',
  intervalLabels: const {},
);

void main() {
  late List<(int, ReviewRating)> sent;

  StudySessionController build(int n) {
    sent = [];
    return StudySessionController(
      cards: List.generate(n, (i) => _card(i + 1)),
      sendReview: (id, rating) async => sent.add((id, rating)),
    );
  }

  test('Dễ cho thẻ rời phiên và tăng tiến trình', () async {
    final c = build(2);
    await c.rate(ReviewRating.easy);

    expect(c.graduated, 1);
    expect(c.remaining, 1);
    expect(c.current!.card.cardId, 2);
    expect(sent.single, (1, ReviewRating.easy));
  });

  test('Xem lại / Khó / Ổn đều đưa thẻ quay lại hàng đợi', () async {
    for (final rating in [
      ReviewRating.again,
      ReviewRating.hard,
      ReviewRating.good,
    ]) {
      final c = build(3);
      await c.rate(rating);
      expect(c.graduated, 0, reason: '$rating không được kết thúc thẻ');
      expect(c.remaining, 3, reason: '$rating phải giữ thẻ trong hàng đợi');
    }
  });

  test('khoảng cách lặp: Xem lại sau 2 thẻ, Khó sau 5 thẻ', () async {
    final again = build(6);
    await again.rate(ReviewRating.again);
    expect(again.current!.card.cardId, 2);
    await again.rate(ReviewRating.easy);
    await again.rate(ReviewRating.easy);
    expect(again.current!.card.cardId, 1);

    final hard = build(8);
    await hard.rate(ReviewRating.hard);
    for (var i = 0; i < 5; i++) {
      expect(hard.current!.card.cardId, i + 2);
      await hard.rate(ReviewRating.easy);
    }
    expect(hard.current!.card.cardId, 1);
  });

  test('chỉ còn một thẻ thì thẻ lặp lại ngay', () async {
    final c = build(1);
    await c.rate(ReviewRating.good);
    expect(c.current!.card.cardId, 1);
    expect(c.isFinished, isFalse);
  });

  test('phiên xong khi mọi thẻ đã Dễ, kể cả sau nhiều lần lặp', () async {
    final c = build(2);
    await c.rate(ReviewRating.again);
    await c.rate(ReviewRating.good);
    await c.rate(ReviewRating.easy);
    await c.rate(ReviewRating.hard);
    expect(c.isFinished, isFalse);
    await c.rate(ReviewRating.easy);

    expect(c.isFinished, isTrue);
    expect(c.graduated, 2);
    expect(c.reviews, 5);
    expect(c.hardestCardIds.first, 1);
  });

  test('lỗi mạng khi gửi đánh giá không làm hỏng phiên học', () async {
    final c = StudySessionController(
      cards: [_card(1)],
      sendReview: (id, rating) async => throw Exception('offline'),
    );
    await c.rate(ReviewRating.easy);
    expect(c.isFinished, isTrue);
  });

  test('giờ nhắc: đúng giờ đã chọn, hoặc lúc đến hạn nếu muộn hơn', () {
    final morning = DateTime(2026, 10, 28, 9, 30);
    final night = DateTime(2026, 10, 28, 22, 15);
    expect(
      StudyReminderService.reminderTimeFor(morning, 20),
      DateTime(2026, 10, 28, 20),
    );
    expect(StudyReminderService.reminderTimeFor(night, 20), night);
  });
}
