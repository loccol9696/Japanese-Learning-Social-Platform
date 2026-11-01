import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/network/api_exception.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/report/report_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    requests = [];
  });

  void useServer(http.Response Function(http.Request request) handler) {
    ApiClient.overrideForTesting(MockClient((request) async {
      requests.add(request);
      return handler(request);
    }));
  }

  test('gửi đúng loại đối tượng, lý do và mô tả đã cắt khoảng trắng', () async {
    useServer((_) => _json(201, {'status': 201, 'data': {}}));

    await ReportService().submit(
      target: ReportTarget.comment,
      targetId: 42,
      reason: ReportReason.harassment,
      detail: '  lăng mạ người khác ',
    );

    expect(requests.single.method, 'POST');
    expect(requests.single.url.toString(), ApiConstants.reportsUrl);
    expect(jsonDecode(requests.single.body), {
      'targetType': 'COMMENT',
      'targetId': 42,
      'reason': 'HARASSMENT',
      'detail': 'lăng mạ người khác',
    });
  });

  test('bỏ trường detail khi mô tả trống', () async {
    useServer((_) => _json(201, {'status': 201, 'data': {}}));

    await ReportService().submit(
      target: ReportTarget.user,
      targetId: 7,
      reason: ReportReason.spam,
      detail: '   ',
    );

    expect(jsonDecode(requests.single.body), {
      'targetType': 'USER',
      'targetId': 7,
      'reason': 'SPAM',
    });
  });

  test('mã lý do khớp enum của backend', () {
    expect(
      ReportReason.values.map((r) => r.code),
      ['SPAM', 'INAPPROPRIATE', 'HARASSMENT', 'MISINFORMATION', 'COPYRIGHT', 'OTHER'],
    );
    expect(
      ReportTarget.values.map((t) => t.name.toUpperCase()),
      ['VIDEO', 'COMMENT', 'USER'],
    );
  });

  test('ném ApiException với thông điệp của server khi báo cáo trùng', () async {
    useServer((_) => _json(409, {
          'status': 409,
          'message': 'Bạn đã báo cáo nội dung này, báo cáo đang chờ xử lý',
        }));

    await expectLater(
      ReportService().submit(
        target: ReportTarget.video,
        targetId: 1,
        reason: ReportReason.spam,
      ),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 409)
          .having((e) => e.message, 'message', contains('đã báo cáo'))),
    );
  });
}
