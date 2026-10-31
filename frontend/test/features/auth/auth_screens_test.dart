import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/storage/token_storage.dart';
import 'package:frontend/features/auth/screens/forgot_password_screen.dart';
import 'package:frontend/features/auth/screens/otp_verification_screen.dart';
import 'package:frontend/features/auth/screens/register_screen.dart';
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
        jsonEncode({'status': 200, 'message': 'ok', 'data': <String, dynamic>{}}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }));
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: home));
    await tester.pumpAndSettle();
  }

  group('Đăng ký', () {
    testWidgets('có Email, Họ và tên, Tên đăng nhập, Mật khẩu; Đăng nhập nằm ở đáy', (tester) async {
      await pump(tester, const RegisterScreen());

      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Tên đăng nhập'), findsOneWidget);
      expect(find.text('Mật khẩu'), findsOneWidget);
      expect(find.text('Họ và tên'), findsOneWidget);
      expect(find.text('Nhập lại mật khẩu'), findsNothing);
      expect(find.text('hoặc'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(tester.getTopLeft(find.text('Đăng nhập')).dy, greaterThan(1400));
    });

    testWidgets('đăng ký gửi Họ và tên đã nhập', (tester) async {
      await pump(tester, const RegisterScreen());

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Sakura@Example.com');
      await tester.enterText(fields.at(1), 'Nguyễn Văn_An9!');
      await tester.enterText(fields.at(2), 'sakura99');
      await tester.enterText(fields.at(3), 'matkhau123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo tài khoản'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final register = requests.where((r) => r.url.path.endsWith('/auth/register'));
      expect(register, hasLength(1));
      final body = jsonDecode(register.single.body) as Map<String, dynamic>;
      expect(body['email'], 'sakura@example.com');
      expect(body['username'], 'sakura99');
      // Ký tự đặc biệt và số bị loại ngay lúc gõ.
      expect(body['displayName'], 'Nguyễn VănAn');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('tên đăng nhập được dùng ký tự đặc biệt, chỉ cấm khoảng trắng', (tester) async {
      await pump(tester, const RegisterScreen());
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'sakura@example.com');
      await tester.enterText(fields.at(1), 'Sakura');
      await tester.enterText(fields.at(2), 'sakura.#_99!');
      await tester.enterText(fields.at(3), 'matkhau123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Tạo tài khoản'));
      await tester.pump();

      expect(find.textContaining('Chỉ dùng chữ cái'), findsNothing);
      expect(find.textContaining('Dấu chấm'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('Quên mật khẩu', () {
    testWidgets('bước nhập email theo thiết kế, không còn dòng "Nhớ mật khẩu?"', (tester) async {
      await pump(tester, const ForgotPasswordScreen());

      expect(find.text('Quên mật khẩu'), findsOneWidget);
      expect(find.text('Nhập email đã đăng ký để nhận mã đặt lại mật khẩu.'), findsOneWidget);
      expect(find.text('Gửi mã xác nhận'), findsOneWidget);
      expect(find.textContaining('Nhớ mật khẩu'), findsNothing);
    });
  });

  group('Xác thực OTP', () {
    testWidgets('6 ô số, nút Xác thực chỉ bật khi đủ 6 số', (tester) async {
      await pump(tester, const OtpVerificationScreen(email: 'name@example.com'));

      for (var i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('otp-box-$i')), findsOneWidget);
      }
      expect(find.textContaining('name@example.com', findRichText: true), findsOneWidget);
      ElevatedButton button() => tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Xác thực'));
      expect(button().onPressed, isNull);

      await tester.enterText(find.byType(TextField), '123');
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(button().onPressed, isNull);
    });

    testWidgets('nhập đủ 6 số thì tự gửi mã lên server', (tester) async {
      await pump(tester, const OtpVerificationScreen(email: 'name@example.com'));

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final verify = requests.where((r) => r.url.path.contains('verify'));
      expect(verify, hasLength(1));
      expect(jsonDecode(verify.single.body)['otp'], '123456');
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
