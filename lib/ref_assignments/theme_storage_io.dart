import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ThemeStorage {
  static const _themeFileName = 'theme_mode.txt';

  Future<String?> readMode() async {
    final file = await _themeFile();
    if (!await file.exists()) {
      return null;
    }
    final value = (await file.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  Future<void> writeMode(String value) async {
    final file = await _themeFile();
    await file.writeAsString(value);
  }

  Future<File> _themeFile() async {
    final baseDir = await getApplicationSupportDirectory();
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }
    return File(p.join(baseDir.path, _themeFileName));
  }
}
