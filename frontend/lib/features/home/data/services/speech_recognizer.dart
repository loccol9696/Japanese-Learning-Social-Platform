import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Nhận dạng giọng nói tiếng Nhật trên thiết bị. Tách thành interface để kiểm thử bằng bản giả.
abstract class SpeechRecognizer {
  /// false nếu thiết bị / trình duyệt không hỗ trợ hoặc người dùng từ chối quyền micro.
  Future<bool> initialize();

  /// Bắt đầu nghe. [onFinal] được gọi đúng một lần khi kết thúc (dừng tay, im lặng hoặc hết giờ).
  Future<void> start({
    required Duration listenFor,
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(double level) onLevel,
  });

  /// Dừng nghe; [onFinal] sẽ nhận phần đã nhận dạng được.
  Future<void> stop();

  Future<void> cancel();
}

/// Dùng nhận dạng giọng nói của hệ điều hành / trình duyệt (miễn phí) qua gói speech_to_text.
class DeviceSpeechRecognizer implements SpeechRecognizer {
  final SpeechToText _speech = SpeechToText();

  bool _ready = false;
  String _lastText = '';
  bool _delivered = false;
  void Function(String text)? _onFinal;

  @override
  Future<bool> initialize() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _deliver();
          }
        },
        onError: (error) {
          debugPrint('Lỗi nhận dạng giọng nói: ${error.errorMsg}');
          _deliver();
        },
      );
    } catch (e) {
      debugPrint('Không khởi tạo được nhận dạng giọng nói: $e');
      _ready = false;
    }
    return _ready;
  }

  void _deliver() {
    if (_delivered) return;
    _delivered = true;
    final callback = _onFinal;
    _onFinal = null;
    callback?.call(_lastText);
  }

  @override
  Future<void> start({
    required Duration listenFor,
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(double level) onLevel,
  }) async {
    _lastText = '';
    _delivered = false;
    _onFinal = onFinal;
    await _speech.listen(
      onResult: (result) {
        _lastText = result.recognizedWords;
        onPartial(_lastText);
        if (result.finalResult) _deliver();
      },
      onSoundLevelChange: (level) {
        // Android ~ -2..10, iOS là dB: chuẩn hoá thô về 0..1 để vẽ sóng âm.
        final normalized = level < -20
            ? ((level + 60) / 60).clamp(0.0, 1.0)
            : ((level + 2) / 12).clamp(0.0, 1.0);
        onLevel(normalized);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: 'ja_JP',
        listenFor: listenFor,
        pauseFor: const Duration(milliseconds: 2000),
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    // Một số nền tảng không gửi trạng thái "done" sau stop: chờ ngắn rồi tự trả kết quả.
    Future.delayed(const Duration(milliseconds: 900), _deliver);
  }

  @override
  Future<void> cancel() async {
    _delivered = true;
    _onFinal = null;
    await _speech.cancel();
  }
}
