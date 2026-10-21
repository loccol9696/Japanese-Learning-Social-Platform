import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/flashcard/presentation/widgets/study_options_bottom_sheet.dart';

void main() {
  late StudyOptions latest;
  late int resetCount;

  Future<void> pumpSheet(
    WidgetTester tester, {
    StudyOptions? options,
  }) async {
    latest = options ?? StudyOptions();
    resetCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: StudyOptionsBottomSheet(
              options: latest,
              onOptionsChanged: (o) => latest = o,
              onResetProgress: () => resetCount++,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('hiển thị đủ các nhóm và mục của bảng tùy chọn học', (tester) async {
    await pumpSheet(tester);

    expect(find.text('Tùy chọn học'), findsOneWidget);
    expect(find.text('CÀI ĐẶT ÔN TẬP'), findsOneWidget);
    expect(find.text('Trộn thẻ ngẫu nhiên'), findsOneWidget);
    expect(find.text('Chỉ học từ gắn sao'), findsOneWidget);
    expect(find.text('HIỂN THỊ'), findsOneWidget);
    expect(find.text('Mặt thẻ hiển thị trước'), findsOneWidget);
    expect(find.text('Thuật ngữ'), findsOneWidget);
    expect(find.text('Định nghĩa'), findsOneWidget);
    expect(find.text('Đặt lại tiến trình thẻ'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
  });

  testWidgets('bật công tắc và đổi mặt thẻ đều báo lại tùy chọn mới', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(latest.shuffle, isTrue);
    expect(latest.starredOnly, isFalse);

    // Bấm vào cả hàng cũng bật/tắt được công tắc
    await tester.tap(find.text('Chỉ học từ gắn sao'));
    await tester.pump();
    expect(latest.starredOnly, isTrue);
    expect(latest.shuffle, isTrue, reason: 'giữ nguyên lựa chọn trước đó');

    await tester.tap(find.text('Định nghĩa'));
    await tester.pump();
    expect(latest.displayFrontFace, 'definition');

    await tester.tap(find.text('Thuật ngữ'));
    await tester.pump();
    expect(latest.displayFrontFace, 'term');
  });

  testWidgets('đặt lại tiến trình cần xác nhận mới thực hiện', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Đặt lại tiến trình thẻ'));
    await tester.pumpAndSettle();
    expect(find.text('Đặt lại tiến trình'), findsOneWidget);
    expect(resetCount, 0);

    // Hủy -> không đặt lại
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(resetCount, 0);
  });

  testWidgets('khởi tạo theo tùy chọn đang có', (tester) async {
    await pumpSheet(
      tester,
      options: StudyOptions(shuffle: true, displayFrontFace: 'definition'),
    );

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches[0].value, isTrue);
    expect(switches[1].value, isFalse);
  });
}
