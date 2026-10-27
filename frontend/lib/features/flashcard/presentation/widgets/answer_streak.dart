/// Đếm số câu trả lời đúng liên tiếp trong một phiên luyện tập.
class AnswerStreak {
  /// Từ chuỗi này trở lên thì thanh tiến trình đổi màu và hiện ngọn lửa kèm số.
  static const int highlightFrom = 2;

  /// Cứ mỗi bội số của số này thì chơi hiệu ứng lửa lớn (5, 10, 15...).
  static const int fireEvery = 5;

  int _count = 0;

  /// Số câu đúng liên tiếp hiện tại.
  int get count => _count;

  /// Có nên làm nổi bật (đổi màu thanh tiến trình, hiện lửa) ở chuỗi hiện tại không.
  bool get isHighlighted => _count >= highlightFrom;

  /// Ghi nhận một câu trả lời. Trả về true khi vừa chạm mốc cần chơi hiệu ứng lửa lớn.
  bool record({required bool correct}) {
    if (!correct) {
      _count = 0;
      return false;
    }
    _count++;
    return _count % fireEvery == 0;
  }

  /// Đứt chuỗi (bỏ qua câu, làm lại...).
  void reset() => _count = 0;
}
