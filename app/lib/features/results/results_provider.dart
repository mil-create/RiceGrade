import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/services.dart';

class ResultsState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? analysisResults;
  final bool hasResults;

  const ResultsState({
    this.isLoading = false,
    this.error,
    this.analysisResults,
    this.hasResults = false,
  });

  ResultsState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? analysisResults,
    bool? hasResults,
    bool clearError = false,
    bool clearResults = false,
  }) {
    return ResultsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      analysisResults:
          clearResults ? null : (analysisResults ?? this.analysisResults),
      hasResults: clearResults ? false : (hasResults ?? this.hasResults),
    );
  }
}

class ResultsNotifier extends StateNotifier<ResultsState> {
  ResultsNotifier() : super(const ResultsState());

  void setResults(Map<String, dynamic> results) {
    state = state.copyWith(
      isLoading: false,
      clearError: true,
      analysisResults: results,
      hasResults: true,
    );
  }

  void setLoading() {
    state =
        state.copyWith(isLoading: true, clearError: true, clearResults: true);
  }

  void setError(String error) {
    state = state.copyWith(isLoading: false, error: error, clearResults: true);
  }

  void clear() {
    state = const ResultsState();
  }
}

final resultsProvider =
    StateNotifierProvider<ResultsNotifier, ResultsState>((ref) {
  return ResultsNotifier();
});

// Holds the base64 annotated image for display
final imageDataProvider = StateProvider<String?>((ref) => null);

// History entry behind the shown results; null if it wasn't saved.
final currentHistoryEntryProvider = StateProvider<HistoryEntry?>((ref) => null);
