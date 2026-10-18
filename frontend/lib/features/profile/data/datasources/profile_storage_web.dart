// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class ProfileStorage {
  static void save(String key, String value) {
    try {
      html.window.localStorage[key] = value;
    } catch (_) {}
  }

  static String? get(String key) {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }
}
