import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/theme.dart';
import '../history/history_provider.dart';
import 'result_summary.dart';
import 'results_provider.dart';
import 'widgets/grade_card.dart';
import 'widgets/save_label_dialog.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resultsProvider);
    final imageData = ref.watch(imageDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.contentMaxWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _body(context, ref, state, imageData),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
      BuildContext context, WidgetRef ref, ResultsState state, String? image) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) return _buildErrorMessage(context, ref, state);
    if (state.hasResults && state.analysisResults != null) {
      return _buildResultsContent(
          context, ref, ResultSummary(state.analysisResults!), image);
    }
    return _buildEmpty(context);
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No results yet',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () => context.go('/capture'),
            child: const Text('Analyze a photo'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(
      BuildContext context, WidgetRef ref, ResultsState state) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: AppSpacing.md),
        Text(
          state.error ?? 'An error occurred',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed: () => ref.read(resultsProvider.notifier).clear(),
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  Widget _buildResultsContent(BuildContext context, WidgetRef ref,
      ResultSummary summary, String? imageData) {
    final theme = Theme.of(context);
    final entry = ref.watch(currentHistoryEntryProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradeCard(summary: summary),
          const SizedBox(height: AppSpacing.md),
          Text(
            summary.grainsCheckedText,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          if (entry?.label != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              entry!.label!,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (imageData != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              child: Image.memory(
                base64Decode(imageData),
                height: AppSpacing.resultImageHeight,
                fit: BoxFit.contain,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              title: Text('Details', style: theme.textTheme.titleLarge),
              childrenPadding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              children: [
                _buildStatRow(
                    context, 'Whole grains', summary.wholeCount.toString()),
                _buildStatRow(
                    context, 'Broken grains', summary.brokenCount.toString()),
                _buildStatRow(context, 'Avg length/breadth ratio',
                    summary.ratio.toString()),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: entry == null ? null : () => _save(context, ref),
                  icon: const Icon(Icons.bookmark_add),
                  label: Text(entry?.label == null ? 'Save' : 'Rename'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _share(context, ref, summary),
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () {
              ref.read(resultsProvider.notifier).clear();
              ref.read(imageDataProvider.notifier).state = null;
              ref.read(currentHistoryEntryProvider.notifier).state = null;
              context.go('/capture');
            },
            child: Text('Analyze another', style: theme.textTheme.titleMedium),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final entry = ref.read(currentHistoryEntryProvider);
    if (entry == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final label = await showSaveLabelDialog(context, initial: entry.label);
    if (label == null) return;

    try {
      final updated =
          await ref.read(historyProvider.notifier).setLabel(entry, label);
      ref.read(currentHistoryEntryProvider.notifier).state = updated;
      messenger.showSnackBar(const SnackBar(content: Text('Saved')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _share(
      BuildContext context, WidgetRef ref, ResultSummary summary) async {
    final entry = ref.read(currentHistoryEntryProvider);
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: summary.shareText(label: entry?.label, date: entry?.createdAt),
      subject: 'Rice quality result',
      // Needed for the share sheet anchor on iPad.
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    final style = Theme.of(context).textTheme.titleLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
