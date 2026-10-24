import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Bề rộng tối đa của nội dung các màn hình xác thực.
const double kAuthContentMaxWidth = 480;

/// Padding cho vùng cuộn của màn hình xác thực: 24px ở điện thoại, còn trên
/// màn hình rộng (web/tablet) thì căn nội dung vào giữa, rộng tối đa
/// [kAuthContentMaxWidth].
EdgeInsets authPagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = math.max(24.0, (width - kAuthContentMaxWidth) / 2);
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: 16);
}
