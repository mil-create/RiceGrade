import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }) {
    return ResultsState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      analysisResults: analysisResults ?? this.analysisResults,
      hasResults: hasResults ?? this.hasResults,
    );
  }
}

class ResultsNotifier extends StateNotifier<ResultsState> {
  ResultsNotifier() : super(const ResultsState());

  void setResults(Map<String, dynamic> results) {
    state = state.copyWith(
      isLoading: false,
      error: null,
      analysisResults: results,
      hasResults: true,
    );
  }

  void setLoading() {
    state = state.copyWith(isLoading: true, error: null, analysisResults: null);
  }

  void setError(String error) {
    state =
        state.copyWith(isLoading: false, error: error, analysisResults: null);
  }

  void clear() {
    state = const ResultsState();
  }
}

final resultsProvider =
    StateNotifierProvider<ResultsNotifier, ResultsState>((ref) {
  return ResultsNotifier();
});

// Provider to hold the base64 image data for display
final imageDataProvider = StateProvider<String?>((ref) => null);
