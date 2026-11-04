import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/ui/widgets/flashcard/card_content.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/notebook/highlight_repository.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/highlight/highlight.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/core/images/image_preview.dart';
import 'package:flashcards/ui/widgets/notebook/highlightable_text.dart';
import 'package:flashcards/ui/dialogs/notebook/export_highlights_sheet.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The question as the student reads it once answered: clozes revealed.
String readableQuestion(String question) => question
    .replaceAllMapped(RegExp(r'\{([^}]*)\}'), (m) => m.group(1)!)
    .trim();

/// Highlights grouped by card, newest card first.
List<(String flashcardId, List<Highlight> highlights)> groupByCard(
  List<Highlight> highlights,
) {
  final groups = <String, List<Highlight>>{};
  for (final highlight in highlights) {
    groups.putIfAbsent(highlight.flashcardId, () => []).add(highlight);
  }
  return [for (final e in groups.entries) (e.key, e.value)];
}

class HighlightsList extends StatefulWidget {
  final HighlightRepository repository;

  const HighlightsList({super.key, required this.repository});

  @override
  State<HighlightsList> createState() => _HighlightsListState();
}

class _HighlightsListState extends State<HighlightsList> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.repository.load();
  }

  void _delete(Highlight highlight) {
    final messenger = ScaffoldMessenger.of(context);
    widget.repository.remove(
      [highlight],
      onError: (error) => messenger.showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't delete the highlight: ${extractErrorMessage(error)}",
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        if (!repo.isLoaded && repo.loadError == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!repo.isLoaded && repo.loadError != null) {
          return _Message(
            icon: Icons.cloud_off,
            title: "Highlights couldn't be loaded",
            message: extractErrorMessage(repo.loadError!),
            action: FilledButton.tonal(
              onPressed: () => repo.load(refresh: true),
              child: const Text('Try again'),
            ),
          );
        }
        if (repo.notebookHighlights.isEmpty) {
          return const _Message(
            icon: Icons.format_color_text,
            title: 'No highlights yet',
            message:
                'While studying, press and hold on a card\'s text, select '
                'the words you want and tap "Highlight". They are collected '
                'here so you can go back to them.',
          );
        }

        final query = _query.trim().toLowerCase();
        final filtered = query.isEmpty
            ? repo.notebookHighlights
            : repo.notebookHighlights
                  .where(
                    (h) =>
                        h.text.toLowerCase().contains(query) ||
                        h.question.toLowerCase().contains(query),
                  )
                  .toList();
        final groups = groupByCard(filtered);

        return RefreshIndicator(
          onRefresh: () => repo.load(refresh: true),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText:
                            'Search ${repo.notebookHighlights.length} highlights',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Export as PDF',
                    onPressed: () =>
                        showExportHighlightsSheet(context, repo.highlights),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No highlights match "$_query".',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final (flashcardId, highlights) in groups)
                _CardHighlights(
                  flashcardId: flashcardId,
                  highlights: highlights,
                  onDelete: _delete,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CardHighlights extends StatelessWidget {
  final String flashcardId;
  final List<Highlight> highlights;
  final ValueChanged<Highlight> onDelete;

  const _CardHighlights({
    required this.flashcardId,
    required this.highlights,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: context.colors.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showHighlightedCard(context, flashcardId),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.style_outlined,
                      size: 16,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        plainCardText(
                          readableQuestion(highlights.first.question),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.labelLarge?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final highlight in highlights)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      margin: const EdgeInsets.only(top: 6, right: 10),
                      decoration: BoxDecoration(
                        color: highlightBackground,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(highlight.text, style: context.text.bodyLarge),
                            Text(
                              highlight.side == HighlightSide.answer
                                  ? 'From the answer'
                                  : 'From the question',
                              style: context.text.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Delete highlight',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => onDelete(highlight),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the whole card with its highlights; more can be added here too.
Future<void> showHighlightedCard(BuildContext context, String flashcardId) {
  final repo = context.read<FlashcardRepository>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) => FutureBuilder(
        future: repo.getFlashcard(flashcardId),
        builder: (context, snapshot) {
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return switch (result) {
            Error<Flashcard>(:final error) => _Message(
              icon: Icons.error_outline,
              title: "This card couldn't be opened",
              message: extractErrorMessage(error),
            ),
            Ok<Flashcard>(:final value) => _CardView(
              flashcard: value,
              scrollController: scrollController,
            ),
          };
        },
      ),
    ),
  );
}

class _CardView extends StatelessWidget {
  final Flashcard flashcard;
  final ScrollController scrollController;

  const _CardView({required this.flashcard, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final question = readableQuestion(flashcard.question);
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('Question', style: context.text.labelLarge),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: CardContent(
            question,
            target: HighlightTarget.of(flashcard, HighlightSide.question),
            style: TextStyle(
              color: context.colors.onPrimaryContainer,
              fontSize: 18,
            ),
          ),
        ),
        if (flashcard.questionImageUrl?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          ImagePreview(downloadUrl: flashcard.questionImageUrl, height: 200),
        ],
        const SizedBox(height: 20),
        Text('Answer', style: context.text.labelLarge),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: CardContent(
            flashcard.answer,
            target: HighlightTarget.of(flashcard, HighlightSide.answer),
            style: context.text.bodyLarge?.copyWith(
              color: context.colors.onSecondaryContainer,
            ),
          ),
        ),
        if (flashcard.answerImageUrl?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          ImagePreview(downloadUrl: flashcard.answerImageUrl, height: 200),
        ],
        const SizedBox(height: 16),
        Text(
          'Tip: press and hold the text to highlight more or remove a '
          'highlight.',
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _Message({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
      children: [
        Icon(icon, size: 48, color: context.colors.outline),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.text.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          Center(child: action!),
        ],
      ],
    );
  }
}
