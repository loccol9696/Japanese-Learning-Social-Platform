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
    required void Function(String code) onError,
  });

  /// Dừng nghe; [onFinal] sẽ nhận phần đã nhận dạng được.
  Future<void> stop();

  Future<void> cancel();
}

/// Dùng nhận dạng giọng nói của hệ điều hành / trình duyệt (miễn phí) qua gói speech_to_text.
class DeviceSpeechRecognizer implements SpeechRecognizer {
  /// Các lỗi chỉ có nghĩa là "không nghe thấy gì": coi như kết quả rỗng, không phải lỗi thiết bị.
  static const _silenceErrors = {'no-speech', 'error_no_match', 'error_speech_timeout', 'no_match'};

  final SpeechToText _speech = SpeechToText();

  bool _ready = false;
  bool _sawListening = false;
  bool _delivered = false;
  String _lastText = '';
  Timer? _deliverTimer;
  void Function(String text)? _onFinal;
  void Function(String code)? _onError;

  @override
  Future<bool> initialize() async {
    if (_ready) return true;
    try {
      _ready = await _speech.initialize(
        onStatus: (status) {
          debugPrint('[STT] trạng thái: $status');
          if (status == 'listening') {
            _sawListening = true;
          } else if (_sawListening &&
              (status == 'notListening' || status == 'done' || status == 'doneNoResult')) {
            // Chờ ngắn để kết quả cuối kịp về trước khi chốt.
            _scheduleDeliver();
          }
        },
        onError: (error) {
          debugPrint('[STT] lỗi: ${error.errorMsg} (permanent: ${error.permanent})');
          if (_silenceErrors.contains(error.errorMsg)) {
            _scheduleDeliver();
            return;
          }
          if (_delivered) return;
          _delivered = true;
          _deliverTimer?.cancel();
          final callback = _onError;
          _onFinal = null;
          _onError = null;
          callback?.call(error.errorMsg);
        },
      );
    } catch (e) {
      debugPrint('[STT] không khởi tạo được: $e');
      _ready = false;
    }
    return _ready;
  }

  void _scheduleDeliver([Duration delay = const Duration(milliseconds: 500)]) {
    if (_delivered) return;
    _deliverTimer?.cancel();
    _deliverTimer = Timer(delay, _deliver);
  }

  void _deliver() {
    if (_delivered) return;
    _delivered = true;
    _deliverTimer?.cancel();
    final callback = _onFinal;
    _onFinal = null;
    _onError = null;
    debugPrint('[STT] kết quả cuối: "$_lastText"');
    callback?.call(_lastText);
  }

  @override
  Future<void> start({
    required Duration listenFor,
    required void Function(String text) onPartial,
    required void Function(String text) onFinal,
    required void Function(double level) onLevel,
    required void Function(String code) onError,
  }) async {
    _deliverTimer?.cancel();
    _lastText = '';
    _delivered = false;
    _sawListening = false;
    _onFinal = onFinal;
    _onError = onError;
    await _speech.listen(
      onResult: (result) {
        _lastText = result.recognizedWords;
        debugPrint('[STT] nghe được: "$_lastText" (final: ${result.finalResult})');
        onPartial(_lastText);
        if (result.finalResult) _scheduleDeliver(const Duration(milliseconds: 150));
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
        pauseFor: const Duration(milliseconds: 2500),
      ),
    );
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    // Một số nền tảng không gửi trạng thái kết thúc sau stop: tự chốt sau một lúc.
    _scheduleDeliver(const Duration(milliseconds: 1200));
  }

  @override
  Future<void> cancel() async {
    _delivered = true;
    _deliverTimer?.cancel();
    _onFinal = null;
    _onError = null;
    await _speech.cancel();
  }
}
