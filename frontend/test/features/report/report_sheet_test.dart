import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/report/report_service.dart';
import 'package:frontend/features/report/report_sheet.dart';

/// Service giả: ghi lại lời gọi, có thể bắt buộc lỗi.
class _FakeReportService implements ReportService {
  final List<ReportReason> sent = [];
  final List<String?> details = [];
  ApiException? failWith;

  @override
  Future<void> submit({
    required ReportTarget target,
    required int targetId,
    required ReportReason reason,
    String? detail,
  }) async {
    if (failWith != null) throw failWith!;
    sent.add(reason);
    details.add(detail);
  }
}

void main() {
  late _FakeReportService service;

  /// Mở sheet bằng đúng route modal như app (không qua bước đăng nhập).
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => ReportSheet(
                  target: ReportTarget.comment,
                  targetId: 7,
                  subject: 'bình luận này',
                  service: service,
                ),
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  setUp(() => service = _FakeReportService());

  ElevatedButton submitButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Gửi báo cáo'));

  testWidgets('hiện đủ sáu lý do và nút gửi bị khóa khi chưa chọn', (tester) async {
    await openSheet(tester);

    expect(find.text('Báo cáo bình luận này'), findsOneWidget);
    for (final reason in ReportReason.values) {
      expect(find.text(reason.label), findsOneWidget);
    }
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('chọn lý do thì mở khóa nút gửi và gửi đúng dữ liệu rồi đóng sheet', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text(ReportReason.harassment.label));
    await tester.pump();
    expect(submitButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), '  lăng mạ  ');
    await tester.tap(find.text('Gửi báo cáo'));
    await tester.pumpAndSettle();

    expect(service.sent, [ReportReason.harassment]);
    expect(service.details.single, '  lăng mạ  ');
    // Sheet đã đóng.
    expect(find.text('Báo cáo bình luận này'), findsNothing);
    // Toast chờ hiệu ứng đóng xong mới hiện; để timer chạy hết trước khi kết thúc test.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('lỗi từ server không đóng sheet và cho gửi lại', (tester) async {
    service.failWith = ApiException(statusCode: 409, message: 'Bạn đã báo cáo nội dung này');
    await openSheet(tester);

    await tester.tap(find.text(ReportReason.spam.label));
    await tester.pump();
    await tester.tap(find.text('Gửi báo cáo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Báo cáo bình luận này'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
    expect(service.sent, isEmpty);

    // Chờ toast lỗi tự tắt.
    await tester.pump(const Duration(seconds: 5));
  });
}
