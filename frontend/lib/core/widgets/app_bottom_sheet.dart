import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Bottom sheet tối dùng chung (thanh kéo + tiêu đề + nội dung).
///
/// [builder] nhận `ctx` của sheet (dùng cho `Navigator.pop(ctx)`) và trả về
/// các phần tử nằm dưới tiêu đề.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required String title,
  required List<Widget> Function(BuildContext ctx) builder,
  EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  double handleGap = 16,
  double titleGap = 16,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: AppColors.socialSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: handleGap),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: titleGap),
              ...builder(ctx),
            ],
          ),
        ),
      );
    },
  );
}
