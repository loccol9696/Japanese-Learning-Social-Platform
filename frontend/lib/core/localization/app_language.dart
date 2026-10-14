enum AppLanguage {
  vi(code: 'vi', name: 'Tiếng Việt', flag: '🇻🇳'),
  en(code: 'en', name: 'English', flag: '🇺🇸'),
  ja(code: 'ja', name: '日本語', flag: '🇯🇵');

  final String code;
  final String name;
  final String flag;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.flag,
  });
}
