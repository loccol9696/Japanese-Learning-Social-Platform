import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/screens/login_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    requests = [];
    ApiClient.overrideForTesting(MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({'status': 401, 'message': 'Sai email hoặc mật khẩu', 'data': null}),
        401,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('bố cục theo thiết kế: nhãn Email, hoặc, Đăng ký ở đáy, không còn đăng nhập bằng username', (tester) async {
    await pumpLogin(tester);

    expect(find.text('Email'), findsOneWidget);
    expect(find.textContaining('Tên đăng nhập'), findsNothing);
    expect(find.text('hoặc'), findsOneWidget);
    expect(find.text('Đăng ký'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    // Dòng đăng ký nằm sát đáy màn hình, dưới nút Google.
    expect(tester.getTopLeft(find.text('Đăng ký')).dy, greaterThan(1400));
  });

  testWidgets('nhập tên đăng nhập (không phải email) bị từ chối, không gọi server', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, 'sakura');
    await tester.enterText(find.byType(TextFormField).last, 'matkhau123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();

    expect(find.text('Định dạng email không hợp lệ'), findsOneWidget);
    expect(requests.where((r) => r.url.path.endsWith('/auth/login')), isEmpty);
  });

  testWidgets('email hợp lệ: gửi email viết thường lên server', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Sakura@Example.com');
    await tester.enterText(find.byType(TextFormField).last, 'matkhau123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final login = requests.where((r) => r.url.path.endsWith('/auth/login'));
    expect(login, hasLength(1));
    expect(jsonDecode(login.single.body)['usernameOrEmail'], 'sakura@example.com');
    await tester.pump(const Duration(seconds: 5));
  });
}
