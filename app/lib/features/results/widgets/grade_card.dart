import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../result_summary.dart';

/// Large card colored by grade with a plain-language headline.
class GradeCard extends StatelessWidget {
  const GradeCard({super.key, required this.summary});

  final ResultSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground) =
        summary.colors(theme.extension<GradeColors>()!);

    return Card(
      margin: EdgeInsets.zero,
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Text(
              summary.grade,
              style: theme.textTheme.displayLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.headline,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    summary.meaning,
                    style:
                        theme.textTheme.titleLarge?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
