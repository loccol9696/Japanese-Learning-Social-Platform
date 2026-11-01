import 'package:flutter/material.dart';

/// Phần trang của [PageView] mà thẻ hiện ra; nhỏ hơn 1 để chừa chỗ cho thẻ kế bên lấp ló ở hai mép.
const double kCarouselViewportFraction = 0.92;

/// Khe ngang mỗi bên giữa thẻ và mép trang, nên giữa hai thẻ liền kề luôn có khe, không dính nhau.
const double kCarouselCardGap = 6;

/// Hệ số thu nhỏ của thẻ nằm xa tâm (thẻ kế bên khi đang trượt).
const double kCarouselSideScale = 0.93;

/// Khung cho một thẻ trong carousel: chừa khe hai bên và thu nhỏ nhẹ khi thẻ rời tâm, theo vị trí trượt thực
/// của [controller] nên chuyển động mượt theo ngón tay.
class CarouselCardFrame extends StatelessWidget {
  const CarouselCardFrame({
    super.key,
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // Trước khi có kích thước, controller.page ném lỗi: dùng trang khởi tạo.
        final page = controller.hasClients && controller.position.haveDimensions
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();
        final distance = (page - index).abs().clamp(0.0, 1.0);
        final scale = 1 - (1 - kCarouselSideScale) * distance;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: kCarouselCardGap, vertical: 6),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }
}
