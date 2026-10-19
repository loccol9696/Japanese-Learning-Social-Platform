import 'package:flutter/foundation.dart';

class TtsService {
  static void speak({
    required String text,
    String lang = 'ja-JP',
    double rate = 0.9,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) {
    onStart?.call();
    onComplete?.call();
  }

  static void stop() {}
}
