import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/password_policy.dart';

void main() {
  group('validateNewPassword', () {
    test('chấp nhận mật khẩu từ 8 ký tự có cả chữ và số', () {
      expect(validateNewPassword('abcd1234'), isNull);
      expect(validateNewPassword('Matkhau2026'), isNull);
      expect(validateNewPassword('p@ssw0rd!'), isNull);
    });

    test('chấp nhận chữ tiếng Việt và tiếng Nhật', () {
      expect(validateNewPassword('Mậtkhẩu123'), isNull);
      expect(validateNewPassword('にほんご12345'), isNull);
    });

    test('từ chối mật khẩu ngắn hơn 8 ký tự', () {
      expect(validateNewPassword('abc123'), contains('ít nhất 8'));
      expect(validateNewPassword('abcd123'), contains('ít nhất 8'));
    });

    test('từ chối mật khẩu thiếu chữ hoặc thiếu số', () {
      expect(validateNewPassword('12345678'), 'Mật khẩu phải gồm cả chữ và số');
      expect(validateNewPassword('abcdefgh'), 'Mật khẩu phải gồm cả chữ và số');
      expect(validateNewPassword('!!!!!!!!!'), 'Mật khẩu phải gồm cả chữ và số');
    });

    test('giới hạn 72 byte, không phải 72 ký tự', () {
      expect(validateNewPassword('a1' * 36), isNull); // đúng 72 byte
      expect(validateNewPassword('${'a1' * 36}b'), contains('72 byte'));
      // 30 ký tự tiếng Nhật (3 byte mỗi ký tự) + 2 ký tự = 92 byte dù chỉ 32 ký tự
      expect(validateNewPassword('${'あ' * 30}a1'), contains('72 byte'));
    });

    test('thông báo quy tắc khớp với backend', () {
      expect(passwordRuleMessage, 'Mật khẩu phải từ 8 đến 72 ký tự, gồm cả chữ và số');
    });
  });
}
