import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/subscription_model.dart';
import '../../../core/theme/app_palette.dart';

class SubscriptionSuccessDialog extends StatelessWidget {
  final PaymentResponse payment;
  final SubscriptionPlan plan;
  final VoidCallback onDismiss;

  const SubscriptionSuccessDialog({
    super.key,
    required this.payment,
    required this.plan,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      elevation: 10,
      backgroundColor: AppPalette.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.sakuraPink, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 46,
                color: AppPalette.onAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nâng Cấp Kotoba Premium Thành Công!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Chúc mừng bạn đã trở thành Hội viên Kotoba Premium. Toàn bộ tính năng cao cấp đã được mở khóa!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppPalette.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _buildDetailRow('Gói kích hoạt:', plan.name),
                  const SizedBox(height: 8),
                  _buildDetailRow('Thời hạn:', plan.durationLabel),
                  const SizedBox(height: 8),
                  _buildDetailRow('Số tiền:', plan.formattedPrice),
                  const SizedBox(height: 8),
                  _buildDetailRow('Mã giao dịch:', payment.transactionRef),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.accent,
                  foregroundColor: AppPalette.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onDismiss();
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Xem thông tin gói trong Hồ sơ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppPalette.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppPalette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
