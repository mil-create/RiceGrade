import 'package:flutter/material.dart';

class AppTheme {
  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: Color(0xFFC080),
    brightness: Brightness.light,
  );
  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: Color(0xFFC080),
    brightness: Brightness.dark,
  );

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
      );
}
