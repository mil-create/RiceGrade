import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/services.dart';
import '../../theme/theme.dart';
import '../results/result_summary.dart';
import '../results/widgets/grade_card.dart';
import 'compare_provider.dart';

class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key, this.firstId, this.secondId});

  final int? firstId;
  final int? secondId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = firstId;
    final b = secondId;

    return Scaffold(
      appBar: AppBar(title: const Text('Compare')),
      body: SafeArea(
        child: a == null || b == null
            ? const _EmptyView()
            : ref.watch(compareProvider((a, b))).when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorView(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(compareProvider((a, b))),
                  ),
                  data: (comparison) => comparison == null
                      ? const _EmptyView()
                      : _CompareContent(comparison: comparison),
                ),
      ),
    );
  }
}

class _CompareContent extends StatelessWidget {
  const _CompareContent({required this.comparison});

  final Comparison comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = comparison;
    final columns = [
      _SampleColumn(name: c.firstName, entry: c.first, summary: c.firstSummary),
      _SampleColumn(
          name: c.secondName, entry: c.second, summary: c.secondSummary),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSpacing.wideMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= AppSpacing.twoColumnBreakpoint
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: columns[0]),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: columns[1]),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              columns[0],
                              const SizedBox(height: AppSpacing.lg),
                              columns[1],
                            ],
                          ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                c.verdict,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (c.isSmallSample) ...[
                const SizedBox(height: AppSpacing.md),
                const _SmallSampleWarning(),
              ],
              const SizedBox(height: AppSpacing.lg),
              _MetricsTable(comparison: c),
            ],
          ),
        ),
      ),
    );
  }
}

class _SampleColumn extends StatelessWidget {
  const _SampleColumn({
    required this.name,
    required this.entry,
    required this.summary,
  });

  final String name;
  final HistoryEntry entry;
  final ResultSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(name, style: theme.textTheme.headlineSmall),
        Text(
          ResultSummary.formatDate(entry.createdAt),
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          child: Image.file(
            File(entry.annotatedPath),
            height: AppSpacing.resultImageHeight,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => SizedBox(
              height: AppSpacing.resultImageHeight,
              child: Icon(Icons.broken_image, color: theme.colorScheme.outline),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        GradeCard(summary: summary),
        const SizedBox(height: AppSpacing.md),
        Text('${summary.brokenPercentText}% broken',
            style: theme.textTheme.titleLarge),
        Text(summary.grainsCheckedText, style: theme.textTheme.titleLarge),
      ],
    );
  }
}

class _SmallSampleWarning extends StatelessWidget {
  const _SmallSampleWarning();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<GradeColors>()!;
    return Card(
      margin: EdgeInsets.zero,
      color: colors.fair,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: colors.onFair),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Small sample, results may vary',
                style:
                    theme.textTheme.titleLarge?.copyWith(color: colors.onFair),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsTable extends StatelessWidget {
  const _MetricsTable({required this.comparison});

  final Comparison comparison;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<GradeColors>()!;
    final c = comparison;
    final a = c.firstSummary;
    final b = c.secondSummary;
    final headerStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);
    final cellStyle = theme.textTheme.titleLarge;

    Widget cell(String text, {bool better = false, TextStyle? style}) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        color: better ? colors.good : null,
        child: Text(
          better ? '$text  (better)' : text,
          style: better
              ? cellStyle?.copyWith(
                  color: colors.onGood, fontWeight: FontWeight.bold)
              : (style ?? cellStyle),
        ),
      );
    }

    TableRow row(String label, String first, String second,
            {bool highlight = false}) =>
        TableRow(children: [
          cell(label),
          cell(first, better: highlight && c.betterIndex == 0),
          cell(second, better: highlight && c.betterIndex == 1),
        ]);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.4)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        children: [
          TableRow(
            decoration:
                BoxDecoration(color: theme.colorScheme.surfaceContainerHighest),
            children: [
              cell('', style: headerStyle),
              cell(c.firstName, style: headerStyle),
              cell(c.secondName, style: headerStyle),
            ],
          ),
          row('Broken %', '${a.brokenPercentText}%', '${b.brokenPercentText}%',
              highlight: true),
          row('Whole grains', '${a.wholeCount}', '${b.wholeCount}'),
          row('Broken grains', '${a.brokenCount}', '${b.brokenCount}'),
          row('Avg length/breadth', '${a.ratio}', '${b.ratio}'),
          row('Grains counted', '${a.totalGrains}', '${b.totalGrains}'),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.compare_arrows,
                size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: AppSpacing.md),
            Text(
              'These results are no longer available',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => context.go('/history'),
              child: const Text('Back to history'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
