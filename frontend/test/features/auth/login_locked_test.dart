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

  Future<void> logInAgainst(WidgetTester tester, int status, String message) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.instance.clear();
    ApiClient.overrideForTesting(MockClient((_) async => http.Response(
          jsonEncode({'status': status, 'message': message}),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'sakura@example.com');
    await tester.enterText(fields.at(1), 'matkhau123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Đăng nhập'));
    await tester.pumpAndSettle();
  }

  testWidgets('tài khoản bị khóa thấy thông báo khóa, không có đường gửi OTP', (tester) async {
    await logInAgainst(tester, 423, 'Tài khoản của bạn đã bị khóa do vi phạm tiêu chuẩn cộng đồng');

    expect(find.text('Tài khoản đã bị khóa'), findsOneWidget);
    expect(find.text('Tài khoản của bạn đã bị khóa do vi phạm tiêu chuẩn cộng đồng'), findsOneWidget);
    expect(find.text('Gửi mã OTP'), findsNothing);
    expect(find.text('Tài khoản chưa kích hoạt'), findsNothing);
  });

  testWidgets('tài khoản chưa xác thực vẫn được mời nhập OTP', (tester) async {
    await logInAgainst(tester, 403, 'Tài khoản chưa được kích hoạt');

    expect(find.text('Tài khoản chưa kích hoạt'), findsOneWidget);
    expect(find.text('Gửi mã OTP'), findsOneWidget);
    expect(find.text('Tài khoản đã bị khóa'), findsNothing);
  });
}
