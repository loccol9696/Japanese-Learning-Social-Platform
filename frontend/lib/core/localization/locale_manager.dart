import 'package:flutter/material.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// Biến toàn cục (Global Variable) để truy cập nhanh toàn bộ chuỗi text đa ngôn ngữ:
/// Sử dụng trực tiếp trong UI: `appStrings.navHome`, `appStrings.following`, v.v.
AppStrings get appStrings => LocaleManager.instance.strings;

/// Biến toàn cục (Global Variable) quản lý trạng thái ngôn ngữ và kích hoạt thông báo đổi ngôn ngữ:
/// Sử dụng: `localeManager.changeLanguage(AppLanguage.en)` hoặc `localeManager.toggleLanguage()`
final LocaleManager localeManager = LocaleManager.instance;

class LocaleManager extends ChangeNotifier {
  LocaleManager._();
  static final LocaleManager instance = LocaleManager._();

  AppLanguage _currentLanguage = AppLanguage.vi;
  AppStrings _strings = ViStrings();

  AppLanguage get currentLanguage => _currentLanguage;
  AppStrings get strings => _strings;

  void changeLanguage(AppLanguage language) {
    if (_currentLanguage == language) return;
    _currentLanguage = language;
    switch (language) {
      case AppLanguage.vi:
        _strings = ViStrings();
        break;
      case AppLanguage.en:
        _strings = EnStrings();
        break;
      case AppLanguage.ja:
        _strings = JaStrings();
        break;
    }
    notifyListeners();
  }

  void toggleLanguage() {
    final next = switch (_currentLanguage) {
      AppLanguage.vi => AppLanguage.en,
      AppLanguage.en => AppLanguage.ja,
      AppLanguage.ja => AppLanguage.vi,
    };
    changeLanguage(next);
  }
}
