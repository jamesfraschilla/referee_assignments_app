import 'package:web/web.dart' as web;

class ThemeStorage {
  static const _storageKey = 'theme_mode';

  Future<String?> readMode() async {
    final value = web.window.localStorage.getItem(_storageKey)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> writeMode(String value) async {
    web.window.localStorage.setItem(_storageKey, value);
  }
}
