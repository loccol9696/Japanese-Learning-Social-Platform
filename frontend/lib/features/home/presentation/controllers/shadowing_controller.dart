import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/services/speech_recognizer.dart';
import '../../domain/models/ruby_segment.dart';
import '../../domain/models/shadowing_models.dart';

enum ShadowingPhase {
  /// Chờ người dùng bấm micro.
  ready,

  /// Đang phát câu mẫu.
  playingSample,

  /// Đang nghe người dùng nói.
  listening,

  /// Đã có câu nhận dạng, đang chờ server chấm.
  scoring,

  /// Có điểm.
  result,

  /// Lỗi (không hỗ trợ, không nghe thấy, mạng...), có thể thử lại.
  error,

  /// Đã đi hết các câu: tổng kết.
  summary,
}

typedef ScoreLine = Future<ShadowingLineScore> Function(int lineIndex, String recognizedText);
typedef PlaySample = Future<void> Function(SubtitleCue cue);

/// Điều phối một phiên luyện nói: phát mẫu → nghe → chấm → câu tiếp theo.
class ShadowingController extends ChangeNotifier {
  /// Điểm từ mức này trở lên là đạt; dưới mức này câu được xếp vào "câu yếu".
  static const int passScore = 70;

  ShadowingController({
    required this.cues,
    required this.recognizer,
    required this.scoreLine,
    required this.playSample,
    int startIndex = 0,
    Map<int, int>? bestScores,
  }) : _bestScores = Map<int, int>.of(bestScores ?? const {}) {
    _order = [for (var i = startIndex; i < cues.length; i++) i];
  }

  final List<SubtitleCue> cues;
  final SpeechRecognizer recognizer;
  final ScoreLine scoreLine;
  final PlaySample playSample;

  final Map<int, int> _bestScores;
  late List<int> _order;
  int _position = 0;

  /// Điểm các câu đã luyện trong phiên này (lần gần nhất).
  final Map<int, int> _sessionScores = {};

  ShadowingPhase _phase = ShadowingPhase.ready;
  ShadowingLineScore? _result;
  String? _error;
  double _level = 0;
  String _partialText = '';
  bool _disposed = false;

  ShadowingPhase get phase => _phase;
  ShadowingLineScore? get result => _result;
  String? get error => _error;
  double get level => _level;
  String get partialText => _partialText;

  int get lineIndex => _order.isEmpty ? 0 : _order[_position];
  SubtitleCue? get cue => _order.isEmpty ? null : cues[lineIndex];
  bool get isLast => _position >= _order.length - 1;

  /// Điểm cao nhất mọi lần (gồm cả các phiên trước).
  Map<int, int> get bestScores => Map.unmodifiable(_bestScores);

  /// Trung bình điểm các câu đã luyện trong phiên này.
  int get sessionAverage {
    if (_sessionScores.isEmpty) return 0;
    final sum = _sessionScores.values.reduce((a, b) => a + b);
    return (sum / _sessionScores.length).round();
  }

  /// Các câu đã luyện trong phiên nhưng chưa đạt, theo thứ tự câu.
  List<int> get weakLines =>
      (_sessionScores.entries.where((e) => e.value < passScore).map((e) => e.key).toList()..sort());

  int get practicedCount => _sessionScores.length;

  void _set(ShadowingPhase phase, {String? error}) {
    _phase = phase;
    _error = error;
    if (!_disposed) notifyListeners();
  }

  /// Phát câu mẫu rồi quay về trạng thái sẵn sàng.
  Future<void> listenSample() async {
    final current = cue;
    if (current == null || _phase == ShadowingPhase.listening || _phase == ShadowingPhase.scoring) {
      return;
    }
    final before = _phase;
    _set(ShadowingPhase.playingSample);
    try {
      await playSample(current);
    } catch (e) {
      debugPrint('Không phát được câu mẫu: $e');
    }
    if (_phase == ShadowingPhase.playingSample) {
      _set(before == ShadowingPhase.result ? ShadowingPhase.result : ShadowingPhase.ready);
    }
  }

  /// Bắt đầu nghe người dùng nói.
  Future<void> startListening() async {
    final current = cue;
    if (current == null || _phase == ShadowingPhase.listening || _phase == ShadowingPhase.scoring) {
      return;
    }

    final ok = await recognizer.initialize();
    if (!ok) {
      _set(
        ShadowingPhase.error,
        error: 'Thiết bị hoặc trình duyệt chưa hỗ trợ nhận dạng giọng nói, '
            'hoặc bạn chưa cho phép dùng micro. Hãy thử Chrome / Edge và bật quyền micro.',
      );
      return;
    }

    _partialText = '';
    _level = 0;
    _result = null;
    _set(ShadowingPhase.listening);

    // Hết giờ: gấp đôi độ dài câu cộng 2 giây.
    final limit = current.end - current.start;
    final listenFor = Duration(milliseconds: (limit.inMilliseconds * 2) + 2000);

    try {
      await recognizer.start(
        listenFor: listenFor,
        onPartial: (text) {
          _partialText = text;
          if (_phase == ShadowingPhase.listening && !_disposed) notifyListeners();
        },
        onFinal: _onFinal,
        onError: _onRecognizerError,
        onLevel: (level) {
          if (_phase != ShadowingPhase.listening) return;
          _level = level;
          if (!_disposed) notifyListeners();
        },
      );
    } catch (e) {
      _set(ShadowingPhase.error, error: 'Không bắt đầu nghe được. Vui lòng thử lại.');
    }
  }

  /// Người dùng chủ động dừng nói.
  Future<void> stopListening() async {
    if (_phase != ShadowingPhase.listening) return;
    await recognizer.stop();
  }

  void _onRecognizerError(String code) {
    if (_phase != ShadowingPhase.listening) return;
    _set(ShadowingPhase.error, error: describeSpeechError(code));
  }

  /// Thông báo dễ hiểu cho các mã lỗi của trình duyệt (web) và Android / iOS.
  static String describeSpeechError(String code) {
    final c = code.toLowerCase();
    if (c.contains('not-allowed') || c.contains('permission') || c.contains('service-not-allowed')) {
      return 'Chưa được phép dùng micro. Hãy bấm biểu tượng ổ khóa cạnh thanh địa chỉ và bật micro, rồi thử lại. ($code)';
    }
    if (c.contains('network')) {
      return 'Không kết nối được dịch vụ nhận dạng giọng nói. Trình duyệt cần có mạng để nhận dạng. ($code)';
    }
    if (c.contains('audio') || c.contains('capture')) {
      return 'Không tìm thấy micro. Hãy kiểm tra micro đã cắm và đang bật. ($code)';
    }
    if (c.contains('language')) {
      return 'Thiết bị chưa hỗ trợ nhận dạng tiếng Nhật. ($code)';
    }
    if (c.contains('busy')) {
      return 'Bộ nhận dạng đang bận, thử lại sau vài giây. ($code)';
    }
    return 'Lỗi nhận dạng giọng nói ($code). Vui lòng thử lại.';
  }

  Future<void> _onFinal(String text) async {
    if (_phase != ShadowingPhase.listening) return;
    final spoken = text.trim();
    if (spoken.isEmpty) {
      _set(ShadowingPhase.error, error: 'Không nghe thấy giọng nói, thử lại nhé.');
      return;
    }

    _set(ShadowingPhase.scoring);
    final index = lineIndex;
    try {
      final score = await scoreLine(index, spoken);
      if (_disposed) return;
      _result = score;
      _sessionScores[index] = score.score;
      final previousBest = _bestScores[index] ?? 0;
      _bestScores[index] = score.bestScore > previousBest ? score.bestScore : previousBest;
      _set(ShadowingPhase.result);
    } catch (e) {
      debugPrint('Không chấm được dòng $index: $e');
      _set(ShadowingPhase.error, error: 'Không chấm được điểm. Kiểm tra kết nối rồi thử lại.');
    }
  }

  /// Nói lại cùng câu.
  void retry() {
    _result = null;
    _partialText = '';
    _set(ShadowingPhase.ready);
  }

  /// Sang câu kế tiếp, hoặc tới màn tổng kết nếu đã hết.
  void next() {
    if (isLast) {
      _set(ShadowingPhase.summary);
      return;
    }
    _position++;
    _result = null;
    _partialText = '';
    _set(ShadowingPhase.ready);
  }

  /// Luyện lại chỉ các câu yếu của phiên vừa rồi.
  void practiceWeakLines() {
    final weak = weakLines;
    if (weak.isEmpty) return;
    _order = weak;
    _position = 0;
    _sessionScores.clear();
    _result = null;
    _partialText = '';
    _set(ShadowingPhase.ready);
  }

  @override
  void dispose() {
    _disposed = true;
    recognizer.cancel();
    super.dispose();
  }
}
