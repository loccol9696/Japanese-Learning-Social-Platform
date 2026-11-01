import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/count_format.dart';

void main() {
  test('rút gọn số đếm theo kiểu 8,4K / 12K / 1,2M', () {
    expect(formatCompactCount(0), '0');
    expect(formatCompactCount(952), '952');
    expect(formatCompactCount(1000), '1K');
    expect(formatCompactCount(1200), '1,2K');
    expect(formatCompactCount(8400), '8,4K');
    expect(formatCompactCount(12000), '12K');
    expect(formatCompactCount(14000), '14K');
    expect(formatCompactCount(123456), '123K');
    expect(formatCompactCount(1200000), '1,2M');
  });
}
