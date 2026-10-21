import 'package:flutter/material.dart';

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double thumbnail = 72;
  static const double radius = 12;
  static const double buttonHeight = 56;
  static const double contentMaxWidth = 720;
  static const double wideMaxWidth = 1100;
  static const double twoColumnBreakpoint = 600;
  static const double resultImageHeight = 240;
}

/// Background/foreground pairs for grade A (good), B (fair) and C (poor).
@immutable
class GradeColors extends ThemeExtension<GradeColors> {
  const GradeColors({
    required this.good,
    required this.onGood,
    required this.fair,
    required this.onFair,
    required this.poor,
    required this.onPoor,
  });

  final Color good;
  final Color onGood;
  final Color fair;
  final Color onFair;
  final Color poor;
  final Color onPoor;

  static const light = GradeColors(
    good: Color(0xFFC8E6C9),
    onGood: Color(0xFF1B5E20),
    fair: Color(0xFFFFF59D),
    onFair: Color(0xFF5D4300),
    poor: Color(0xFFFFCDD2),
    onPoor: Color(0xFFB71C1C),
  );

  static const dark = GradeColors(
    good: Color(0xFF1B5E20),
    onGood: Color(0xFFC8E6C9),
    fair: Color(0xFF5D4A00),
    onFair: Color(0xFFFFF59D),
    poor: Color(0xFF8E1C1C),
    onPoor: Color(0xFFFFCDD2),
  );

  @override
  GradeColors copyWith({
    Color? good,
    Color? onGood,
    Color? fair,
    Color? onFair,
    Color? poor,
    Color? onPoor,
  }) =>
      GradeColors(
        good: good ?? this.good,
        onGood: onGood ?? this.onGood,
        fair: fair ?? this.fair,
        onFair: onFair ?? this.onFair,
        poor: poor ?? this.poor,
        onPoor: onPoor ?? this.onPoor,
      );

  @override
  GradeColors lerp(GradeColors? other, double t) {
    if (other == null) return this;
    return GradeColors(
      good: Color.lerp(good, other.good, t)!,
      onGood: Color.lerp(onGood, other.onGood, t)!,
      fair: Color.lerp(fair, other.fair, t)!,
      onFair: Color.lerp(onFair, other.onFair, t)!,
      poor: Color.lerp(poor, other.poor, t)!,
      onPoor: Color.lerp(onPoor, other.onPoor, t)!,
    );
  }
}

class AppTheme {
  static const Color seed = Color(0xFFFFC080);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    final textTheme = Typography.material2021().englishLike;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          minimumSize: const Size(88, 50),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          textStyle: textTheme.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
          textStyle: textTheme.titleMedium,
        ),
      ),
      extensions: [
        brightness == Brightness.light ? GradeColors.light : GradeColors.dark,
      ],
    );
  }
}
