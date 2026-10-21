import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'capture_provider.dart';

class CaptureScreen extends ConsumerWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(captureProvider);

    ref.listen<CaptureState>(captureProvider, (previous, next) {
      if (next.showResults && !(previous?.showResults ?? false)) {
        context.go('/results');
        ref.read(captureProvider.notifier).clearShowResults();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Capture Rice')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _body(context, ref, state),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, CaptureState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.permissionDenied) return _buildPermissionDenied(context);
    if (state.error != null) return _buildErrorMessage(context, state, ref);
    if (state.image != null) return _buildPreview(state, ref);
    return _buildImageSelectionButtons(ref);
  }

  Widget _buildPermissionDenied(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          'Permission to access camera and gallery is denied.',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Please enable permissions in app settings to continue.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: open app settings (e.g. with the permission_handler package).
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enable permissions in Settings'),
              ),
            );
          },
          icon: const Icon(Icons.settings),
          label: const Text('Open Settings'),
        ),
      ],
    );
  }

  Widget _buildImageSelectionButtons(WidgetRef ref) {
    final notifier = ref.read(captureProvider.notifier);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => notifier.pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Pick from Gallery'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => notifier.pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Take Photo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(CaptureState state, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: Center(child: Image.file(state.image!, fit: BoxFit.contain)),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => ref.read(captureProvider.notifier).analyzeImage(),
            child: const Text('Analyze'),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(
      BuildContext context, CaptureState state, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: 16),
        Text(
          state.error ?? 'An error occurred',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => ref.read(captureProvider.notifier).reset(),
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}
