import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'capture_provider.dart';

class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captureState = ref.watch(captureProvider);

    // Listen for showResults changes to navigate to results screen
    ref.listen<CaptureState>(captureProvider, (previous, next) {
      if (previous != null && next.showResults && !previous.showResults) {
        // Navigate to results
        Navigator.of(context).pushNamed('/results');
        // Clear the flag so that we don't navigate again on pop
        ref.read(captureProvider.notifier).clearShowResults();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Rice'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (captureState.permissionDenied)
                _buildPermissionDenied(context),
              if (captureState.image == null &&
                  !captureState.isLoading &&
                  !captureState.permissionDenied)
                _buildImageSelectionButtons(context, ref),
              if (captureState.image != null && !captureState.isLoading)
                _buildImagePreviewAndAnalyzeButton(context, captureState, ref),
              if (captureState.isLoading)
                const Center(child: CircularProgressIndicator()),
              if (captureState.error != null && !captureState.isLoading)
                _buildErrorMessage(context, captureState, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionDenied(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 64,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          'Permission to access camera and gallery is denied.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Please enable permissions in app settings to continue.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            // In a real app, we would open app settings.
            // For now, we just show a snackbar.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Please enable permissions in Settings')),
            );
          },
          icon: const Icon(Icons.settings),
          label: const Text('Open Settings'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildImageSelectionButtons(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton.icon(
          onPressed: () =>
              ref.read(captureProvider.notifier).pickImage(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('Pick from Gallery'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            minimumSize: const Size.fromHeight(50),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () =>
              ref.read(captureProvider.notifier).pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Take Photo'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            minimumSize: const Size.fromHeight(50),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreviewAndAnalyzeButton(
      BuildContext context, CaptureState state, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Center(
            child: Image.file(
              state.image!,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => ref.read(captureProvider.notifier).analyzeImage(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('Analyze'),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(
      BuildContext context, CaptureState state, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 16),
        Text(
          state.error ?? 'An error occurred',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => ref.read(captureProvider.notifier).reset(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}
