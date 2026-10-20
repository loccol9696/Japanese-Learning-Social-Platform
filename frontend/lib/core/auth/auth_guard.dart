import 'package:flutter/material.dart';

import '../../features/auth/data/auth_session.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';

Future<bool> requireAuthentication(
  BuildContext context, {
  String message = 'Vui lòng đăng nhập để sử dụng tính năng này.',
}) async {
  if (AuthSession.instance.isAuthenticated) return true;

  final shouldLogin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Yêu cầu đăng nhập'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Để sau'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Đăng nhập ngay'),
        ),
      ],
    ),
  );

  if (shouldLogin != true || !context.mounted) return false;

  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
  return AuthSession.instance.isAuthenticated;
}

Future<void> navigateToGuestHome(BuildContext context) {
  return Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const HomeScreen()),
    (route) => false,
  );
}
