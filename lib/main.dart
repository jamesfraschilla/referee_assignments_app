import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    const seed = Colors.blueAccent;
    final lightScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    const darkSurface = Color.fromARGB(255, 20, 27, 38);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      surface: darkSurface,
      surfaceContainerHighest: darkSurface,
      surfaceTint: Colors.transparent,
      primaryContainer: darkSurface.withValues(alpha: 0.85),
    );
    return MaterialApp(
      title: 'NBA Referee Assignments',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: ThemeData(
        colorScheme: lightScheme,
        useMaterial3: true,
        fontFamily: 'DIN',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.transparent,
            elevation: 0,
            side: const BorderSide(width: 2, color: Colors.orange),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkSurface,
        useMaterial3: true,
        fontFamily: 'DIN',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.transparent,
            elevation: 0,
            side: const BorderSide(width: 2, color: Colors.orange),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: RefereeAssignmentsScreen(
        isDarkMode: _mode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
