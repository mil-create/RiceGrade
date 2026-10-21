import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/services.dart';

class HistoryNotifier extends AsyncNotifier<List<HistoryEntry>> {
  HistoryRepository get _repo => ref.read(historyRepositoryProvider);

  @override
  Future<List<HistoryEntry>> build() => _repo.list();

  Future<HistoryEntry> add(String imagePath, AnalysisResult result) async {
    final entry = await _repo.add(imagePath, result);
    state = AsyncData([entry, ...?state.valueOrNull]);
    return entry;
  }

  /// Empty or blank labels are stored as null.
  Future<HistoryEntry> setLabel(HistoryEntry entry, String label) async {
    final trimmed = label.trim();
    final updated =
        await _repo.setLabel(entry, trimmed.isEmpty ? null : trimmed);
    state = AsyncData([
      for (final e in state.valueOrNull ?? <HistoryEntry>[])
        e.id == entry.id ? updated : e,
    ]);
    return updated;
  }

  Future<void> delete(HistoryEntry entry) async {
    await _repo.delete(entry);
    state = AsyncData([
      for (final e in state.valueOrNull ?? <HistoryEntry>[])
        if (e.id != entry.id) e,
    ]);
  }

  Future<void> clear() async {
    await _repo.clear();
    state = const AsyncData([]);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.list);
  }
}

final historyProvider =
    AsyncNotifierProvider<HistoryNotifier, List<HistoryEntry>>(
        HistoryNotifier.new);
