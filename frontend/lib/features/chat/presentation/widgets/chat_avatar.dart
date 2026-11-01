import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../data/models/chat_models.dart';

/// Ảnh đại diện tròn; không có ảnh (hoặc tải lỗi) thì hiện chữ cái đầu.
class ChatAvatar extends StatelessWidget {
  final ChatUser user;
  final double radius;

  const ChatAvatar({super.key, required this.user, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isEmpty ? '?' : user.name[0].toUpperCase();
    final fallback = Text(
      initial,
      style: TextStyle(
        color: AppPalette.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: radius * 0.75,
      ),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppPalette.surfaceHigh,
      child: user.avatarUrl.isEmpty
          ? fallback
          : ClipOval(
              child: Image.network(
                user.avatarUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
            ),
    );
  }
}
