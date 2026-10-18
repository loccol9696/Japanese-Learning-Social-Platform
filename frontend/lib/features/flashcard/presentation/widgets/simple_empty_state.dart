import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Component hiển thị trạng thái rỗng tối giản (Minimalist Empty State)
/// Dùng chung cho các màn hình học tập khi danh sách thẻ/câu hỏi bằng 0.
class SimpleEmptyState extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  final String backButtonText;

  const SimpleEmptyState({
    super.key,
    this.message = 'Không có từ vựng nào được gắn sao.',
    required this.onBack,
    this.backButtonText = 'Quay lại',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.socialTextMuted,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: onBack,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.socialTextMuted,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                backButtonText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
