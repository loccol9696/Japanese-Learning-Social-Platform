import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_palette.dart';

/// Biến toàn cục quản lý chế độ giao diện (hệ thống / sáng / tối):
/// `themeManager.setMode(ThemeMode.light)`, đọc bộ màu hiện tại qua
/// `themeManager.palette` (UI nên dùng [AppColors] / [AppPalette]).
final ThemeManager themeManager = ThemeManager.instance;

class ThemeManager extends ChangeNotifier with WidgetsBindingObserver {
  ThemeManager._();
  static final ThemeManager instance = ThemeManager._();

  static const _prefsKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.dark;
  Brightness _platformBrightness =
      PlatformDispatcher.instance.platformBrightness;

  ThemeMode get mode => _mode;

  /// Sáng hay tối thực tế sau khi đã xét chế độ "theo hệ thống".
  Brightness get brightness => switch (_mode) {
    ThemeMode.light => Brightness.light,
    ThemeMode.dark => Brightness.dark,
    ThemeMode.system => _platformBrightness,
  };

  ThemePalette get palette =>
      brightness == Brightness.dark ? ThemePalette.dark : ThemePalette.light;

  /// Gọi 1 lần lúc khởi động app: khôi phục lựa chọn đã lưu và theo dõi thay
  /// đổi giao diện của hệ điều hành.
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      final restored = [ThemeMode.light, ThemeMode.dark].where((m) => m.name == saved); // bỏ lựa chọn "theo hệ thống" cũ
      if (restored.isNotEmpty) _apply(restored.first);
    } catch (_) {
      // Không đọc được bộ nhớ thì dùng mặc định.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _apply(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Lưu thất bại không ảnh hưởng việc đổi theme trong phiên này.
    }
  }

  void _apply(ThemeMode mode) {
    _mode = mode;
    // Luôn thông báo để UI chọn theme cập nhật dấu tick, kể cả khi sáng/tối
    // thực tế không đổi.
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    _platformBrightness = PlatformDispatcher.instance.platformBrightness;
    if (_mode == ThemeMode.system) notifyListeners();
  }
}
