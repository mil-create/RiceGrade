import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/services.dart';
import '../results/result_summary.dart';

/// Broken % differences below this many percentage points count as "About the same".
const double sameQualityThreshold = 2.0;

/// Samples with fewer grains than this get a "Small sample" warning.
const int minReliableGrains = 100;

/// Side-by-side view of two saved analyses.
class Comparison {
  Comparison(this.first, this.second)
      : firstSummary = ResultSummary(first.toResultsJson()),
        secondSummary = ResultSummary(second.toResultsJson());

  final HistoryEntry first;
  final HistoryEntry second;
  final ResultSummary firstSummary;
  final ResultSummary secondSummary;

  String get firstName => first.label ?? 'Sample 1';
  String get secondName => second.label ?? 'Sample 2';

  /// 0 = first, 1 = second, null = equal broken %.
  int? get betterIndex {
    final a = firstSummary.brokenPercent;
    final b = secondSummary.brokenPercent;
    if (a == b) return null;
    return a < b ? 0 : 1;
  }

  String get verdict {
    final diff =
        (firstSummary.brokenPercent - secondSummary.brokenPercent).abs();
    if (diff < sameQualityThreshold) return 'About the same';
    final firstBetter = betterIndex == 0;
    final better = firstBetter ? firstSummary : secondSummary;
    final worse = firstBetter ? secondSummary : firstSummary;
    final name = firstBetter ? firstName : secondName;
    return '$name has fewer broken grains '
        '(${better.brokenPercentText}% vs ${worse.brokenPercentText}%)';
  }

  bool get isSmallSample =>
      firstSummary.totalGrains < minReliableGrains ||
      secondSummary.totalGrains < minReliableGrains;
}

/// Null when either entry no longer exists.
final compareProvider = FutureProvider.autoDispose
    .family<Comparison?, (int, int)>((ref, ids) async {
  final repo = ref.read(historyRepositoryProvider);
  final first = await repo.get(ids.$1);
  final second = await repo.get(ids.$2);
  if (first == null || second == null) return null;
  return Comparison(first, second);
});
