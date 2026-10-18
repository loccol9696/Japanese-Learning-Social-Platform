import 'package:flutter/foundation.dart';

/// TTS cho native/VM: chưa hỗ trợ, chỉ log và gọi lại [onComplete]
/// để UI không bị kẹt ở trạng thái "đang phát".
class TtsService {
  static void speak({
    required String text,
    String lang = 'ja-JP',
    double rate = 0.9,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) {
    debugPrint('[TTS] Native platforms not yet supported');
    onComplete?.call();
  }

  static void stop() {}
}
