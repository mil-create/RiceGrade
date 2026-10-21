import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/services.dart';
import '../history/history_provider.dart';
import '../results/results_provider.dart';

class CaptureState {
  final File? image;
  final bool isLoading;
  final String? error;
  final bool permissionDenied;
  final bool
      showResults; // set after a successful analysis to trigger navigation

  const CaptureState({
    this.image,
    this.isLoading = false,
    this.error,
    this.permissionDenied = false,
    this.showResults = false,
  });

  CaptureState copyWith({
    File? image,
    bool? isLoading,
    String? error,
    bool? permissionDenied,
    bool? showResults,
    bool clearImage = false,
    bool clearError = false,
  }) {
    return CaptureState(
      image: clearImage ? null : (image ?? this.image),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      permissionDenied: permissionDenied ?? this.permissionDenied,
      showResults: showResults ?? this.showResults,
    );
  }
}

class CaptureNotifier extends StateNotifier<CaptureState> {
  CaptureNotifier(this._ref) : super(const CaptureState());

  final Ref _ref;

  Future<void> pickImage(ImageSource source) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      permissionDenied: false,
      showResults: false,
    );
    try {
      // Downscale phone photos so uploads stay under the backend's 5 MB limit.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) {
        state = state.copyWith(isLoading: false); // user cancelled
        return;
      }
      state = state.copyWith(image: File(picked.path), isLoading: false);
    } on PlatformException catch (e) {
      final denied = e.code.contains('access_denied');
      state = state.copyWith(
        isLoading: false,
        permissionDenied: denied,
        error: denied ? 'Permission denied' : (e.message ?? e.code),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> analyzeImage() async {
    final image = state.image;
    if (image == null) return;
    state =
        state.copyWith(isLoading: true, clearError: true, showResults: false);
    try {
      final result = await _ref.read(analyzerProvider).analyze(image.path);
      _ref.read(resultsProvider.notifier).setResults(result.toJson());
      _ref.read(imageDataProvider.notifier).state = result.annotatedImageBase64;
      await _saveToHistory(image.path, result);
      state = state.copyWith(
        isLoading: false,
        clearImage: true,
        showResults: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// A failed save must not hide a successful analysis.
  Future<void> _saveToHistory(String path, AnalysisResult result) async {
    _ref.read(currentHistoryEntryProvider.notifier).state = null;
    try {
      _ref.read(currentHistoryEntryProvider.notifier).state =
          await _ref.read(historyProvider.notifier).add(path, result);
    } catch (e) {
      debugPrint('Could not save to history: $e');
    }
  }

  void reset() => state = const CaptureState();

  /// Call after navigating so we don't navigate again.
  void clearShowResults() => state = state.copyWith(showResults: false);
}

final captureProvider =
    StateNotifierProvider<CaptureNotifier, CaptureState>((ref) {
  return CaptureNotifier(ref);
});
