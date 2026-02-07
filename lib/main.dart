import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ref_assignments/app_theme.dart';
import 'ref_assignments/background.dart';
import 'ref_assignments/screens/assignments_screen.dart';
import 'ref_assignments/theme_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final background = RefereeAssignmentsBackgroundService.instance;
    if (background.isSupported) {
      await background.ensureInitialized();
      await background.scheduleDailyFetch();
    }
  } catch (e, stack) {
    debugPrint('Background scheduler init failed: $e\n$stack');
  }
  runApp(const RefereeAssignmentsApp());
}

class RefereeAssignmentsApp extends StatefulWidget {
  const RefereeAssignmentsApp({super.key});

  @override
  State<RefereeAssignmentsApp> createState() => _RefereeAssignmentsAppState();
}

class _RefereeAssignmentsAppState extends State<RefereeAssignmentsApp> {
  ThemeMode _mode = ThemeMode.dark;
  final ThemeStorage _themeStorage = ThemeStorage();

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final value = await _themeStorage.readMode();
      if (value == null || !mounted) return;
      setState(() {
        _mode = value == 'light'
            ? ThemeMode.light
            : value == 'dark'
                ? ThemeMode.dark
                : ThemeMode.dark;
      });
    } catch (e) {
      debugPrint('Failed to load theme preference: $e');
    }
  }

  Future<void> _toggleTheme() async {
    final next = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() => _mode = next);
    try {
      await _themeStorage.writeMode(
        next == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = buildLightTheme();
    final darkTheme = buildDarkTheme();
    return MaterialApp(
      title: 'NBA Referee Assignments',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: RefereeAssignmentsScreen(
        isDarkMode: _mode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
