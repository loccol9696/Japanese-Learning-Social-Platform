import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Nút "Tiếp tục với Google" chính thức của Google (bắt buộc dùng trên web).
Widget buildWebGoogleButton(double width) {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      type: web.GSIButtonType.standard,
      theme: web.GSIButtonTheme.outline,
      size: web.GSIButtonSize.large,
      text: web.GSIButtonText.continueWith,
      shape: web.GSIButtonShape.rectangular,
      minimumWidth: width.clamp(200, 400).toDouble(),
      locale: 'vi',
    ),
  );
}
