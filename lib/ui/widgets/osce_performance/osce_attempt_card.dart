import 'package:flashcards/domain/models/osce/osce_performance/osce_attempt/osce_attempt.dart';
import 'package:flashcards/ui/constants/placeholders.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class OsceAttemptCard extends StatelessWidget {
  final OsceAttempt attempt;
  final VoidCallback onDelete;

  const OsceAttemptCard({
    super.key,
    required this.attempt,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatted = formatSmartDate(attempt.attemptDate);
    final progress = attempt.achievedScore / attempt.maxScore;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Builder(
        builder: (context) => Card(
          margin: const EdgeInsets.all(0),
          color: context.colors.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Datum pokušaja
                Text(
                  dateFormatted,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),

                // Rezultat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Result",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${attempt.achievedScore} / ${attempt.maxScore}",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          width: 36,
                          height: 28,
                          child: PopupMenuButton<int>(
                            tooltip: 'Attempt options',
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (_) => onDelete(),
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 0,
                                child: ListTile(
                                  leading: Icon(Icons.delete_outline),
                                  title: Text('Delete attempt'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: context.colors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 0.7
                          ? Colors.green
                          : (progress >= 0.2 ? Colors.orange : Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OsceAttemptsShimmer extends StatelessWidget {
  const OsceAttemptsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Shimmer.fromColors(
        baseColor: shimmerBaseColor(context),
        highlightColor: shimmerHighlightColor(context),
        child: Column(
          children: [
            BannerPlaceholder(width: double.infinity, height: 90),
            BannerPlaceholder(width: double.infinity, height: 90),
            BannerPlaceholder(width: double.infinity, height: 90),
            BannerPlaceholder(width: double.infinity, height: 90),
            BannerPlaceholder(width: double.infinity, height: 90),
            BannerPlaceholder(width: double.infinity, height: 90),
            BannerPlaceholder(width: double.infinity, height: 90),
          ],
        ),
      ),
    );
  }
}
