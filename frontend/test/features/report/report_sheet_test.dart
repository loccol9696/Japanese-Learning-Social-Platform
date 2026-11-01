import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/report/report_service.dart';
import 'package:frontend/features/report/report_sheet.dart';

/// Service giả: ghi lại lời gọi, có thể bắt buộc lỗi.
class _FakeReportService extends ReportService {
  final List<ReportReason> sent = [];
  final List<String?> details = [];
  int? segmentIndex;
  String? grammarPattern;
  ApiException? failWith;

  @override
  Future<void> submit({
    required ReportTarget target,
    required int targetId,
    required ReportReason reason,
    String? detail,
    int? segmentIndex,
    String? grammarPattern,
  }) async {
    if (failWith != null) throw failWith!;
    sent.add(reason);
    details.add(detail);
    this.segmentIndex = segmentIndex;
    this.grammarPattern = grammarPattern;
  }
}

void main() {
  late _FakeReportService service;

  /// Mở sheet bằng đúng route modal như app (không qua bước đăng nhập).
  Future<void> openSheet(
    WidgetTester tester, {
    ReportTarget target = ReportTarget.comment,
    String subject = 'bình luận này',
    int? segmentIndex,
    String? grammarPattern,
  }) async {
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
                  target: target,
                  targetId: 7,
                  subject: subject,
                  segmentIndex: segmentIndex,
                  grammarPattern: grammarPattern,
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
    expect(ReportTarget.comment.reasons, hasLength(6));
    for (final reason in ReportTarget.comment.reasons) {
      expect(find.text(reason.label), findsOneWidget);
    }
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('bản dịch có lý do dịch sai, không có lý do bản quyền', (tester) async {
    await openSheet(tester, target: ReportTarget.translation, subject: 'bản dịch này');

    expect(find.text(ReportReason.inaccurate.label), findsOneWidget);
    expect(find.text(ReportReason.copyright.label), findsNothing);
  });

  testWidgets('tin nhắn không có lý do dịch sai', (tester) async {
    await openSheet(tester, target: ReportTarget.message, subject: 'tin nhắn này');

    expect(find.text(ReportReason.harassment.label), findsOneWidget);
    expect(find.text(ReportReason.inaccurate.label), findsNothing);
  });

  testWidgets('báo cáo ngữ pháp gửi kèm vị trí câu và mẫu', (tester) async {
    await openSheet(
      tester,
      target: ReportTarget.grammar,
      subject: 'mẫu ngữ pháp này',
      segmentIndex: 3,
      grammarPattern: '〜ている',
    );

    await tester.tap(find.text(ReportReason.inaccurate.label));
    await tester.pump();
    await tester.tap(find.text('Gửi báo cáo'));
    await tester.pumpAndSettle();

    expect(service.sent, [ReportReason.inaccurate]);
    expect(service.segmentIndex, 3);
    expect(service.grammarPattern, '〜ている');
    await tester.pump(const Duration(seconds: 1));
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
