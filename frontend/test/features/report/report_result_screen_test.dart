import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/features/chat/presentation/screens/shared_video_screen.dart';
import 'package:frontend/features/report/report_result_screen.dart';
import 'package:frontend/features/report/report_service.dart';

class _FakeReportService extends ReportService {
  _FakeReportService(this.answer);

  final Future<ReportResult> Function() answer;
  int calls = 0;

  @override
  Future<ReportResult> fetchResult(int reportId) {
    calls++;
    return answer();
  }
}

ReportResult _result(Map<String, dynamic> overrides) => ReportResult.fromJson({
      'targetType': 'MESSAGE',
      'content': 'tin xúc phạm',
      'reason': 'HARASSMENT',
      'status': 'RESOLVED',
      'outcome': 'Đã gỡ tin nhắn',
      'createdAt': '2026-11-01T10:05:00',
      ...overrides,
    });

void main() {
  Future<void> pump(WidgetTester tester, ReportService service, {int? videoId}) async {
    await tester.pumpWidget(MaterialApp(
      home: ReportResultScreen(reportId: 5, videoId: videoId, service: service),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('hiện kết quả, nội dung, lý do và mô tả của người báo cáo', (tester) async {
    await pump(tester, _FakeReportService(() async => _result({'detail': 'lăng mạ tôi'})));

    expect(find.text('Đã gỡ tin nhắn'), findsOneWidget);
    expect(find.text('Nội dung bị báo cáo (Tin nhắn)'), findsOneWidget);
    expect(find.text('tin xúc phạm'), findsOneWidget);
    expect(find.text('Quấy rối hoặc thù ghét'), findsOneWidget);
    expect(find.text('Mô tả của bạn'), findsOneWidget);
    expect(find.text('lăng mạ tôi'), findsOneWidget);
    expect(find.text('Ghi chú của kiểm duyệt viên'), findsNothing);
  });

  testWidgets('hiện ghi chú khi có, ẩn mục mô tả khi trống (chủ nội dung xem)', (tester) async {
    await pump(tester, _FakeReportService(() async => _result({'note': 'lần đầu nhắc nhở'})));

    expect(find.text('lần đầu nhắc nhở'), findsOneWidget);
    expect(find.text('Mô tả của bạn'), findsNothing);
  });

  testWidgets('nội dung đã mất vẫn mở được màn kết quả', (tester) async {
    await pump(tester, _FakeReportService(() async => _result({'content': null})));

    expect(find.text('Nội dung không còn tồn tại'), findsOneWidget);
  });

  testWidgets('chỉ có nút xem video khi thông báo gắn với video, bấm thì mở video', (tester) async {
    final service = _FakeReportService(() async => _result({}));
    await pump(tester, service);
    expect(find.text('Xem video'), findsNothing);

    await pump(tester, service, videoId: 12);
    await tester.scrollUntilVisible(find.text('Xem video'), 100);
    await tester.tap(find.text('Xem video'));
    await tester.pump();

    final video = find.byType(SharedVideoScreen, skipOffstage: false);
    expect(tester.widget<SharedVideoScreen>(video).videoId, 12);
  });

  testWidgets('lỗi thì báo lỗi và thử lại được', (tester) async {
    var fail = true;
    final service = _FakeReportService(() async {
      if (fail) throw ApiException(statusCode: 404, message: 'Không tìm thấy báo cáo');
      return _result({});
    });
    await pump(tester, service);
    expect(find.text('Không tìm thấy báo cáo'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Đã gỡ tin nhắn'), findsOneWidget);
    expect(service.calls, 2);
  });

  test('đọc đúng trạng thái, loại đối tượng và lý do; giá trị lạ không làm hỏng', () {
    expect(_result({'status': 'DISMISSED'}).status, ReportResultStatus.dismissed);
    expect(_result({'status': 'PENDING'}).status, ReportResultStatus.pending);
    expect(_result({'targetType': 'GRAMMAR'}).targetLabel, 'Ngữ pháp');
    expect(_result({'reason': 'LY_DO_MOI'}).reasonLabel, isEmpty);
  });
}
