import 'package:flutter/material.dart';

// Qalta's light mode: white ground, black text/buttons, light-gray card
// fill. Our existing dark mode (matching the web app's slate palette) stays
// the dark option. Both themes route every "muted text" / "track
// background" through onSurfaceVariant / surfaceContainerHighest instead of
// hardcoded Colors.white* so screens actually work in both modes.
ThemeData buildLightTheme() {
  const background = Color(0xFFFFFFFF);
  const surface = Color(0xFFF5F5F7);
  const onSurface = Color(0xFF111111);
  const onSurfaceVariant = Color(0xFF6B7280);
  const primary = Color(0xFF111111);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      primary: primary,
      onPrimary: background,
      surfaceContainerHighest: Color(0xFFE5E7EB),
      error: Color(0xFFDC2626),
    ),
    cardTheme: const CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: background, foregroundColor: onSurface, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: background,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  const background = Color(0xFF0F172A);
  const surface = Color(0xFF1E293B);
  const onSurface = Color(0xFFF1F5F9);
  const onSurfaceVariant = Color(0xFF94A3B8);
  const primary = Color(0xFFF1F5F9);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceVariant,
      primary: primary,
      onPrimary: background,
      surfaceContainerHighest: Color(0xFF334155),
      error: Color(0xFFEF4444),
    ),
    cardTheme: const CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    appBarTheme: const AppBarTheme(backgroundColor: background, foregroundColor: onSurface, elevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: background,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    ),
  );
}
