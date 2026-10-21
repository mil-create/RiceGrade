import 'package:flutter/material.dart';

import '../../theme/theme.dart';

enum Quality { good, fair, poor }

/// Plain-language view of an analysis result, shared by the screen and the share text.
class ResultSummary {
  ResultSummary(Map<String, dynamic> json)
      : wholeCount = json['whole_count'] as int,
        brokenCount = json['broken_count'] as int,
        brokenPercent = (json['broken_percent'] as num).toDouble(),
        ratio = (json['avg_length_breadth_ratio'] as num).toDouble(),
        grade = json['grade'] as String;

  final int wholeCount;
  final int brokenCount;
  final double brokenPercent;
  final double ratio;
  final String grade;

  int get totalGrains => wholeCount + brokenCount;

  Quality get quality => switch (grade) {
        'A' => Quality.good,
        'B' => Quality.fair,
        _ => Quality.poor,
      };

  /// 2.0 -> "2", 2.35 -> "2.35"
  String get brokenPercentText => brokenPercent == brokenPercent.roundToDouble()
      ? brokenPercent.toInt().toString()
      : brokenPercent.toString();

  String get headline => switch (quality) {
        Quality.good => 'Good quality: $brokenPercentText% broken',
        Quality.fair => 'Fair quality: $brokenPercentText% broken',
        Quality.poor => 'Low quality: $brokenPercentText% broken',
      };

  String get meaning => switch (quality) {
        Quality.good => 'Very few broken grains. Good for premium sale.',
        Quality.fair => 'Some broken grains. Fine for regular sale.',
        Quality.poor => 'Many broken grains. Sell at a lower price or sort it.',
      };

  String get grainsCheckedText =>
      '$totalGrains ${totalGrains == 1 ? 'grain' : 'grains'} checked';

  (Color, Color) colors(GradeColors c) => switch (quality) {
        Quality.good => (c.good, c.onGood),
        Quality.fair => (c.fair, c.onFair),
        Quality.poor => (c.poor, c.onPoor),
      };

  String shareText({String? label, DateTime? date}) {
    final lines = [
      'Rice quality check (RiceGrade)',
      if (label != null) 'Batch: $label',
      if (date != null) 'Date: ${formatDate(date)}',
      'Grade $grade - $headline',
      meaning,
      '$grainsCheckedText ($wholeCount whole, $brokenCount broken)',
      'Avg length/breadth: $ratio',
    ];
    return lines.join('\n');
  }

  static String formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}
