import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('speechSynthesis')
external SpeechSynthesis? get _speechSynthesis;

@JS()
extension type SpeechSynthesis(JSObject _) implements JSObject {
  external void cancel();
  external void speak(SpeechSynthesisUtterance utterance);
  external bool get speaking;
  external JSArray<SpeechSynthesisVoice> getVoices();
}

@JS('SpeechSynthesisVoice')
extension type SpeechSynthesisVoice(JSObject _) implements JSObject {
  external JSString get lang;
  external JSString get name;
}

@JS('SpeechSynthesisUtterance')
extension type SpeechSynthesisUtterance._(JSObject _) implements JSObject {
  external factory SpeechSynthesisUtterance([JSString? text]);
  external set lang(JSString value);
  external set rate(JSNumber value);
  external set pitch(JSNumber value);
  external set voice(SpeechSynthesisVoice? value);
  external set onend(JSFunction? callback);
  external set onerror(JSFunction? callback);
}

class TtsService {
  static void speak({
    required String text,
    String lang = 'ja-JP',
    double rate = 0.9,
    VoidCallback? onStart,
    VoidCallback? onComplete,
  }) {
    if (!kIsWeb) {
      debugPrint('[TTS] Native platforms not yet supported');
      return;
    }

    try {
      final synth = _speechSynthesis;
      if (synth == null) {
        debugPrint('[TTS] speechSynthesis is not available');
        return;
      }

      synth.cancel();

      final cleanText = text.trim();
      if (cleanText.isEmpty) {
        return;
      }

      final utterance = SpeechSynthesisUtterance(cleanText.toJS);
      utterance.lang = lang.toJS;
      utterance.rate = rate.toJS;

      try {
        final voices = synth.getVoices().toDart;
        final prefix = lang.split('-').first.toLowerCase();
        for (final v in voices) {
          if (v.lang.toDart.toLowerCase().startsWith(prefix)) {
            utterance.voice = v;
            break;
          }
        }
      } catch (e) {
        debugPrint('[TTS] Could not assign specific voice: $e');
      }

      if (onStart != null) {
        onStart();
      }

      if (onComplete != null) {
        final jsCallback = ([JSAny? _]) {
          onComplete();
        }.toJS;
        utterance.onend = jsCallback;
        utterance.onerror = jsCallback;
      }

      synth.speak(utterance);
    } catch (e) {
      debugPrint('[TTS] Error playing audio: $e');
      onComplete?.call();
    }
  }

  static void stop() {
    if (!kIsWeb) return;
    try {
      _speechSynthesis?.cancel();
    } catch (_) {}
  }
}
