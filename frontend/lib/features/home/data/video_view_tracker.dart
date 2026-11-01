import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

/// Báo cho server một lượt xem khi video bắt đầu phát. Server tự bỏ qua lượt lặp của cùng người trong 30 phút;
/// ở đây ghi nhớ thêm để một video bị phát lại nhiều lần (lướt qua lại, chuyển tab) không gọi mạng liên tục.
class VideoViewTracker {
  VideoViewTracker._();

  /// Khớp với cửa sổ chống đếm trùng của server.
  static const Duration window = Duration(minutes: 30);

  static final Map<String, DateTime> _recorded = {};

  /// Đếm một lượt xem cho [videoId]. Lỗi mạng chỉ bỏ qua, không làm phiền người xem.
  static Future<void> record(String videoId, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final last = _recorded[videoId];
    if (last != null && at.difference(last) < window) return;
    _recorded[videoId] = at;
    try {
      await ApiClient.instance.post('${ApiConstants.baseUrl}/videos/$videoId/views');
    } catch (error) {
      // Thử lại được ở lần phát sau.
      _recorded.remove(videoId);
      debugPrint('Không ghi nhận được lượt xem video $videoId: $error');
    }
  }

  @visibleForTesting
  static void reset() => _recorded.clear();
}
