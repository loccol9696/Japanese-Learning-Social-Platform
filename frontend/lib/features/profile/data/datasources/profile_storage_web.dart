import 'dart:js_interop';

@JS('localStorage')
external _Storage get _localStorage;

extension type _Storage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
}

class ProfileStorage {
  static void save(String key, String value) {
    try {
      _localStorage.setItem(key.toJS, value.toJS);
    } catch (_) {}
  }

  static String? get(String key) {
    try {
      return _localStorage.getItem(key.toJS)?.toDart;
    } catch (_) {
      return null;
    }
  }
}
