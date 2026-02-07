import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  const seed = Colors.blueAccent;
  final lightScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );
  return ThemeData(
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
  );
}

ThemeData buildDarkTheme() {
  const seed = Colors.blueAccent;
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
  return ThemeData(
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
  );
}
