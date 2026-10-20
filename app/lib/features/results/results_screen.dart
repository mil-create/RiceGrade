import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'results_provider.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsState = ref.watch(resultsProvider);
    final imageData = ref.watch(imageDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (resultsState.isLoading)
                const Center(child: CircularProgressIndicator()),
              if (resultsState.error != null && !resultsState.isLoading)
                _buildErrorMessage(context, ref, resultsState),
              if (resultsState.hasResults &&
                  resultsState.analysisResults != null)
                _buildResultsContent(context, ref, resultsState, imageData),
              if (!resultsState.hasResults &&
                  !resultsState.isLoading &&
                  resultsState.error == null)
                const Center(child: Text('No results available')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorMessage(
      BuildContext context, WidgetRef ref, ResultsState state) {
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
          onPressed: () => ref.read(resultsProvider.notifier).clear(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  Widget _buildResultsContent(BuildContext context, WidgetRef ref,
      ResultsState state, String? imageData) {
    final results = state.analysisResults!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageData != null)
            Center(
              child: Image.network(
                'data:image/png;base64,$imageData',
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          const SizedBox(height: 24),
          _buildStatRow(
              context, 'Whole Grains', results['whole_count'].toString()),
          _buildStatRow(
              context, 'Broken Grains', results['broken_count'].toString()),
          _buildStatRow(
              context, 'Broken Percentage', '${results['broken_percent']}%'),
          _buildStatRow(context, 'Avg Length/Breadth Ratio',
              results['avg_length_breadth_ratio'].toString()),
          _buildStatRow(context, 'Grade', results['grade']),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              // Optionally, we can go back to capture or clear results
              ref.read(resultsProvider.notifier).clear();
              // We could also navigate back to capture, but for now just clear.
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Analyze Another'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
