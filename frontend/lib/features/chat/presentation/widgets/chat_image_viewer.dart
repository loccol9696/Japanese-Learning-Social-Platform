import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';

/// Xem ảnh toàn màn hình: chụm hai ngón hoặc chạm đúp để phóng to, vuốt xuống để đóng.
class ChatImageViewer extends StatefulWidget {
  final String url;

  const ChatImageViewer({super.key, required this.url});

  @override
  State<ChatImageViewer> createState() => _ChatImageViewerState();
}

class _ChatImageViewerState extends State<ChatImageViewer> {
  static const double _doubleTapScale = 2.5;
  static const double _closeDistance = 100;

  final _transform = TransformationController();
  Offset _doubleTapAt = Offset.zero;

  // Theo dõi con trỏ bằng Listener vì InteractiveViewer đã giành cử chỉ kéo.
  int _pointers = 0;
  bool _multiTouch = false;
  double? _startY;

  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    const scale = _doubleTapScale;
    _transform.value = _zoomed
        ? Matrix4.identity()
        : (Matrix4.diagonal3Values(scale, scale, 1)..setTranslationRaw(
            (1 - scale) * _doubleTapAt.dx,
            (1 - scale) * _doubleTapAt.dy,
            0,
          ));
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers++;
    if (_pointers == 1) {
      _multiTouch = false;
      _startY = event.position.dy;
    } else {
      _multiTouch = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _pointers--;
    final startY = _startY;
    if (_pointers == 0 &&
        !_multiTouch &&
        !_zoomed &&
        startY != null &&
        event.position.dy - startY > _closeDistance) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: AppPalette.background,
      child: Stack(
        children: [
          Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            onPointerCancel: (_) => _pointers = 0,
            child: GestureDetector(
              onDoubleTapDown: (details) =>
                  _doubleTapAt = details.localPosition,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 4,
                child: Center(child: Image.network(widget.url)),
              ),
            ),
          ),
          SafeArea(
            child: IconButton(
              tooltip: 'Đóng',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: AppPalette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
