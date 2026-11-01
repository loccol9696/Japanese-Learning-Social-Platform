class ProfileStorage {
  static final Map<String, String> _memory = {};

  static void save(String key, String value) {
    _memory[key] = value;
  }

  static String? get(String key) {
    return _memory[key];
  }
}
