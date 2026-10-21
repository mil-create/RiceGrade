import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/services.dart';
import '../../theme/theme.dart';
import '../results/results_provider.dart';
import 'history_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const _maxSelection = 2;

  /// Insertion-ordered, so the first pick is the left column in Compare.
  final _selected = <int>{};

  bool get _selecting => _selected.isNotEmpty;

  void _startSelection(HistoryEntry entry) =>
      setState(() => _selected.add(entry.id));

  void _toggle(HistoryEntry entry) {
    setState(() {
      if (_selected.remove(entry.id)) return;
      if (_selected.length >= _maxSelection) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('You can compare 2 results at a time')));
        return;
      }
      _selected.add(entry.id);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  void _compare() {
    final [a, b] = _selected.toList();
    _clearSelection();
    context.push('/compare?a=$a&b=$b');
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final hasItems = history.valueOrNull?.isNotEmpty ?? false;

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: Scaffold(
        appBar: _selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Cancel',
                  icon: const Icon(Icons.close),
                  onPressed: _clearSelection,
                ),
                title: Text('${_selected.length} of $_maxSelection selected'),
              )
            : AppBar(
                title: const Text('History'),
                actions: [
                  if (hasItems)
                    IconButton(
                      tooltip: 'Clear all',
                      icon: const Icon(Icons.delete_sweep),
                      onPressed: () => _confirmClear(context),
                    ),
                ],
              ),
        floatingActionButton: _selected.length == _maxSelection
            ? FloatingActionButton.extended(
                onPressed: _compare,
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare'),
              )
            : null,
        body: SafeArea(
          child: history.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(
              message: e.toString(),
              onRetry: () => ref.read(historyProvider.notifier).reload(),
            ),
            data: (entries) => entries.isEmpty
                ? const _EmptyView()
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(historyProvider.notifier).reload(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        return _HistoryTile(
                          entry: entry,
                          selecting: _selecting,
                          selected: _selected.contains(entry.id),
                          onLongPress: () => _selecting
                              ? _toggle(entry)
                              : _startSelection(entry),
                          onSelectTap: () => _toggle(entry),
                        );
                      },
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('All saved analyses and images will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok ?? false) await ref.read(historyProvider.notifier).clear();
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({
    required this.entry,
    required this.selecting,
    required this.selected,
    required this.onLongPress,
    required this.onSelectTap,
  });

  final HistoryEntry entry;
  final bool selecting;
  final bool selected;
  final VoidCallback onLongPress;
  final VoidCallback onSelectTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(entry.id),
      // No swipe-to-delete while picking items to compare.
      direction:
          selecting ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => ref.read(historyProvider.notifier).delete(entry),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: selected ? theme.colorScheme.secondaryContainer : null,
        child: ListTile(
          contentPadding: const EdgeInsets.all(AppSpacing.sm),
          selected: selected,
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
            child: Image.file(
              File(entry.annotatedPath),
              width: AppSpacing.thumbnail,
              height: AppSpacing.thumbnail,
              fit: BoxFit.cover,
              cacheWidth: 256,
              errorBuilder: (_, __, ___) => SizedBox(
                width: AppSpacing.thumbnail,
                height: AppSpacing.thumbnail,
                child:
                    Icon(Icons.broken_image, color: theme.colorScheme.outline),
              ),
            ),
          ),
          title: Text(
            entry.label == null
                ? 'Grade ${entry.grade}'
                : '${entry.label} · Grade ${entry.grade}',
            style: theme.textTheme.titleMedium,
          ),
          subtitle: Text(
            '${entry.wholeCount} whole · ${entry.brokenCount} broken '
            '(${entry.brokenPercent}%)\n${_formatDate(entry.createdAt)}',
          ),
          isThreeLine: true,
          trailing: selecting
              ? Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked)
              : const Icon(Icons.chevron_right),
          onLongPress: onLongPress,
          onTap: selecting ? onSelectTap : () => _open(context, ref),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final file = File(entry.annotatedPath);
    final image =
        await file.exists() ? base64Encode(await file.readAsBytes()) : null;
    ref.read(resultsProvider.notifier).setResults(entry.toResultsJson());
    ref.read(imageDataProvider.notifier).state = image;
    ref.read(currentHistoryEntryProvider.notifier).state = entry;
    if (context.mounted) context.go('/results');
  }

  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: AppSpacing.md),
          Text('No analyses yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () => context.go('/capture'),
            child: const Text('Analyze a photo'),
          ),
        ],
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
                style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
