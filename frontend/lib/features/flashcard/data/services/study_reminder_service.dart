import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_session_model.dart';

/// Hẹn nhắc ôn tập dựa trên thời điểm đến hạn gần nhất của thẻ.
///
/// Mỗi lần học xong chỉ giữ MỘT lịch nhắc (ngày có thẻ đến hạn sớm nhất, vào giờ
/// người dùng chọn) nên không bị dồn nhiều thông báo. Việc đặt thông báo hệ
/// thống do [platformScheduler] đảm nhận; mặc định chỉ lưu lịch để app hiển
/// thị huy hiệu "Cần ôn".
class StudyReminderService {
  StudyReminderService._();
  static final StudyReminderService instance = StudyReminderService._();

  static const String _enabledKey = 'srs_reminder_enabled';
  static const String _hourKey = 'srs_reminder_hour';
  static const String _nextAtKey = 'srs_reminder_next_at';
  static const int defaultHour = 20;

  /// Gắn bộ đặt thông báo hệ thống (vd. flutter_local_notifications).
  /// Truyền thời điểm cần nhắc và số thẻ; null để huỷ thông báo đã hẹn.
  Future<void> Function(DateTime? at, int cardCount)? platformScheduler;

  Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<int> reminderHour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_hourKey) ?? defaultHour;
    } catch (_) {
      return defaultHour;
    }
  }

  Future<void> configure({bool? enabled, int? hour}) async {
    final prefs = await SharedPreferences.getInstance();
    if (enabled != null) await prefs.setBool(_enabledKey, enabled);
    if (hour != null) await prefs.setInt(_hourKey, hour.clamp(0, 23));
  }

  /// Giờ nhắc cho lần đến hạn [due]: đúng giờ người dùng chọn trong ngày đó,
  /// nhưng nếu thẻ đến hạn muộn hơn giờ đó thì nhắc ngay lúc đến hạn.
  static DateTime reminderTimeFor(DateTime due, int hour) {
    final preferred = DateTime(due.year, due.month, due.day, hour);
    return due.isAfter(preferred) ? due : preferred;
  }

  Future<void> scheduleFor(DueSummary summary) async {
    final due = summary.nextDueAt;
    final enabled = await isEnabled();
    DateTime? at;
    if (enabled && due != null) {
      var candidate = reminderTimeFor(due, await reminderHour());
      if (candidate.isBefore(DateTime.now())) {
        candidate = DateTime.now().add(const Duration(minutes: 1));
      }
      at = candidate;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (at == null) {
        await prefs.remove(_nextAtKey);
      } else {
        await prefs.setString(_nextAtKey, at.toIso8601String());
      }
      await platformScheduler?.call(at, summary.dueAtNextCount);
    } catch (e) {
      debugPrint('Không hẹn được nhắc ôn tập: $e');
    }
  }
}
