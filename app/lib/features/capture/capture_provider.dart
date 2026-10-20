import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/services.dart';
import '../../features/results/results_provider.dart';

class CaptureState {
  final File? image;
  final bool isLoading;
  final String? error;
  final bool permissionDenied;
  final bool showResults; // Flag to indicate we should show results screen

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
  }) {
    return CaptureState(
      image: image ?? this.image,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      showResults: showResults ?? this.showResults,
    );
  }
}

class CaptureNotifier extends StateNotifier<CaptureState> {
  final Ref _ref;

  CaptureNotifier(this._ref) : super(const CaptureState());

  Future<void> pickImage(ImageSource source) async {
    try {
      state = state.copyWith(
          isLoading: true,
          error: null,
          permissionDenied: false,
          showResults: false);
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile == null) {
        // User cancelled
        state = state.copyWith(isLoading: false);
        return;
      }
      state = state.copyWith(image: File(pickedFile.path), isLoading: false);
    } catch (e) {
      if (e is PlatformException && e.code == 'access_denied') {
        state = state.copyWith(
          isLoading: false,
          permissionDenied: true,
          error: 'Permission denied',
          showResults: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
          showResults: false,
        );
      }
    }
  }

  Future<void> analyzeImage() async {
    if (state.image == null) return;
    state = state.copyWith(isLoading: true, error: null, showResults: false);
    try {
      final apiService = ApiService();
      final result = await apiService.analyzeImage(state.image!.path);
      // Update the results provider
      _ref.read(resultsProvider.notifier).setResults(result.toJson());
      // Update the image data provider
      _ref
          .read(imageDataProvider.notifier)
          .update((state) => result.annotatedImageBase64);
      // Reset the capture state (clear the image) and set showResults to true
      state = state.copyWith(isLoading: false, image: null, showResults: true);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: e.toString(), showResults: false);
    }
  }

  void reset() {
    state = const CaptureState();
  }

  // Call this to reset the showResults flag after navigation
  void clearShowResults() {
    state = state.copyWith(showResults: false);
  }
}

final captureProvider =
    StateNotifierProvider<CaptureNotifier, CaptureState>((ref) {
  return CaptureNotifier(ref);
});
