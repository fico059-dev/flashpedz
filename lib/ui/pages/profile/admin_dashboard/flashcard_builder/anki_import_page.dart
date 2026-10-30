import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flashcards/bloc/flashcards/anki_import/anki_import_cubit.dart';
import 'package:flashcards/bloc/flashcards/anki_import/anki_import_state.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/services/anki/anki_import_models.dart';
import 'package:flashcards/data/services/anki/anki_import_service.dart';
import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/ui/widgets/flashcard/card_content.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Lets an admin import a whole Anki deck into a pack at once.
@RoutePage()
class AnkiImportPage extends StatelessWidget {
  final AdminPack pack;

  const AnkiImportPage({super.key, required this.pack});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AnkiImportCubit(
        flashcardRepo: context.read<FlashcardRepository>(),
        ankiImportService: AnkiImportService(),
      ),
      child: _View(pack: pack),
    );
  }
}

class _View extends StatefulWidget {
  final AdminPack pack;

  const _View({required this.pack});

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  bool _importTags = false;

  Future<void> _pickFile() async {
    // FileType.any: iOS doesn't know the .apkg type, so the extension is
    // checked after picking.
    // Only the web gets the file's bytes; on mobile the file is read from
    // its path so large decks don't have to fit in memory.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: kIsWeb,
    );
    final file = result?.files.singleOrNull;
    if (file == null || !mounted) return;

    final extension = file.name.split('.').last.toLowerCase();
    final path = kIsWeb ? null : file.path;
    if (!ankiImportExtensions.contains(extension) ||
        (path == null && file.bytes == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Choose an Anki .apkg or .txt export file."),
        ),
      );
      return;
    }

    context.read<AnkiImportCubit>().readFile(
      fileName: file.name,
      path: path,
      bytes: path == null ? file.bytes : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnkiImportCubit, AnkiImportState>(
      builder: (context, state) {
        final isImporting = state is AnkiImportImporting;
        return PopScope(
          // Leaving mid-import would stop it half way.
          canPop: !isImporting,
          child: Scaffold(
            appBar: AppBar(
              title: const Text("Import from Anki"),
              automaticallyImplyLeading: !isImporting,
            ),
            body: ReadableWidth(
              maxWidth: 820,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalScreenPadding,
                  ),
                  child: switch (state) {
                    AnkiImportInitial() => _Instructions(
                      packName: widget.pack.packName,
                      onPickFile: _pickFile,
                    ),
                    AnkiImportReading(:final fileName) => _Loading(
                      message: "Reading $fileName…",
                    ),
                    AnkiImportPreview(:final fileName, :final result) =>
                      _Preview(
                        fileName: fileName,
                        result: result,
                        packName: widget.pack.packName,
                        importTags: _importTags,
                        onImportTagsChanged: (value) =>
                            setState(() => _importTags = value),
                        onImport: () =>
                            context.read<AnkiImportCubit>().importCards(
                              packId: widget.pack.packId,
                              importTags: _importTags,
                            ),
                        onPickAnother: _pickFile,
                      ),
                    AnkiImportImporting(:final processed, :final total) =>
                      _Progress(processed: processed, total: total),
                    AnkiImportDone(:final summary) => _Done(
                      summary: summary,
                      packName: widget.pack.packName,
                    ),
                    AnkiImportError(:final error) => _ReadError(
                      error: error,
                      onPickAnother: _pickFile,
                    ),
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Instructions extends StatelessWidget {
  final String packName;
  final VoidCallback onPickFile;

  const _Instructions({required this.packName, required this.onPickFile});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              Text("Add cards to \"$packName\"", style: textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                "Import a whole Anki deck at once instead of adding cards one by one.",
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 10,
                    children: [
                      Text("Export from Anki", style: textTheme.titleMedium),
                      const _Step(
                        number: 1,
                        text: "In Anki on your computer, go to File → Export.",
                      ),
                      const _Step(
                        number: 2,
                        text:
                            "Choose \"Anki Deck Package (.apkg)\" and tick "
                            "\"Include media\" and \"Support older Anki versions\".",
                      ),
                      const _Step(
                        number: 3,
                        text:
                            "Send the file to this device (AirDrop, Files, email…) "
                            "and choose it below.",
                      ),
                      Text(
                        "You can also export \"Notes in Plain Text (.txt)\", "
                        "but images won't be included.",
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 6,
                    children: [
                      Text(
                        "How cards are converted",
                        style: textTheme.titleMedium,
                      ),
                      const Text("• Front → question, back → answer."),
                      const Text(
                        "• Cloze notes become one card per cloze (c1, c2…), "
                        "just like in Anki.",
                      ),
                      const Text(
                        "• One image per side is kept, formatting becomes plain "
                        "text.",
                      ),
                      const Text(
                        "• Cards already in this pack are updated if they "
                        "changed in Anki (question, answer, tags or images), "
                        "and left alone if not. Students keep their progress.",
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: FilledButton.icon(
            onPressed: onPickFile,
            icon: const Icon(Icons.upload_file),
            label: const Text("Choose Anki file"),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: context.colors.primaryContainer,
          child: Text(
            "$number",
            style: TextStyle(
              fontSize: 12,
              color: context.colors.onPrimaryContainer,
            ),
          ),
        ),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  final String message;

  const _Loading({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          const CircularProgressIndicator(),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  static const _sampleSize = 30;

  final String fileName;
  final AnkiParseResult result;
  final String packName;
  final bool importTags;
  final ValueChanged<bool> onImportTagsChanged;
  final VoidCallback onImport;
  final VoidCallback onPickAnother;

  const _Preview({
    required this.fileName,
    required this.result,
    required this.packName,
    required this.importTags,
    required this.onImportTagsChanged,
    required this.onImport,
    required this.onPickAnother,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cards = result.cards;
    final clozeCount = cards.where((c) => c.isCloze).length;
    final occlusionCount = cards.where((c) => c.isOcclusion).length;
    final imageCount = cards
        .where((c) => c.questionImage != null || c.answerImage != null)
        .length;
    final hasTags = cards.any((c) => c.tags.isNotEmpty);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              Text(fileName, style: textTheme.titleMedium),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    _StatTile(
                      icon: Icons.style,
                      label: "Cards to import",
                      value: cards.length,
                    ),
                    if (clozeCount > 0)
                      _StatTile(
                        icon: Icons.text_fields,
                        label: "Cloze cards",
                        value: clozeCount,
                      ),
                    if (occlusionCount > 0)
                      _StatTile(
                        icon: Icons.layers,
                        label: "Image occlusion cards",
                        value: occlusionCount,
                      ),
                    if (imageCount > 0)
                      _StatTile(
                        icon: Icons.image,
                        label: "Cards with images",
                        value: imageCount,
                      ),
                    if (result.skippedNotes > 0)
                      _StatTile(
                        icon: Icons.block,
                        label: "Empty notes skipped",
                        value: result.skippedNotes,
                      ),
                    if (result.missingImages > 0)
                      _StatTile(
                        icon: Icons.broken_image,
                        label: "Images missing from the file",
                        value: result.missingImages,
                        isWarning: true,
                      ),
                    if (result.extraImagesDropped > 0)
                      _StatTile(
                        icon: Icons.photo_library,
                        label: "Sides with several images (joined into one)",
                        value: result.extraImagesDropped,
                      ),
                  ],
                ),
              ),
              if (hasTags)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Import Anki tags"),
                  subtitle: const Text(
                    "Adds the deck's tags to the cards (last level only, "
                    "e.g. Cardio::Valves → Valves).",
                  ),
                  value: importTags,
                  onChanged: onImportTagsChanged,
                ),
              const SizedBox(height: 12),
              Text(
                cards.length > _sampleSize
                    ? "First $_sampleSize cards"
                    : "Cards",
                style: textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final card in cards.take(_sampleSize))
                _CardPreview(card: card),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16, top: 8),
          child: Column(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: cards.isEmpty ? null : onImport,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text("Import ${cards.length} cards into \"$packName\""),
              ),
              TextButton(
                onPressed: onPickAnother,
                child: const Text("Choose another file"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final bool isWarning;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isWarning ? context.colors.error : context.colors.primary;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(
        "$value",
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _CardPreview extends StatelessWidget {
  final AnkiCard card;

  const _CardPreview({required this.card});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    if (card.occlusionImage != null) {
      return _OcclusionPreview(card: card);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    card.question,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (card.questionImage != null)
                  _ImageThumbnail(image: card.questionImage!),
              ],
            ),
            const Divider(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Expanded(
                  child: Text(
                    card.answer,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (card.answerImage != null)
                  _ImageThumbnail(image: card.answerImage!),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// An image-occlusion card: the picture with its boxes, the asked one in
/// orange, as it will look when studied.
class _OcclusionPreview extends StatelessWidget {
  final AnkiCard card;

  const _OcclusionPreview({required this.card});

  @override
  Widget build(BuildContext context) {
    final blocks = parseCardMarkup(card.question);
    final block = blocks.whereType<OcclusionBlock>().firstOrNull;
    final header = card.question
        .split('\n')
        .where((line) => !line.startsWith('[occlusion]('))
        .join('\n')
        .trim();
    final image = card.occlusionImage!;
    final picture = image.bytes != null
        ? Image.memory(image.bytes!, fit: BoxFit.fitWidth, cacheWidth: 640)
        : Image.file(File(image.path), fit: BoxFit.fitWidth, cacheWidth: 640);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            if (header.isNotEmpty)
              Text(
                header,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Stack(
                  children: [
                    picture,
                    if (block != null)
                      Positioned.fill(
                        child: CustomPaint(painter: OcclusionPainter(block)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  final AnkiImage image;

  const _ImageThumbnail({required this.image});

  @override
  Widget build(BuildContext context) {
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: image.bytes != null
          ? Image.memory(
              image.bytes!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              cacheWidth: 96,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.image),
              ),
            )
          : Image.file(
              File(image.path),
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              cacheWidth: 96,
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 48,
                height: 48,
                child: Icon(Icons.image),
              ),
            ),
    );
    if (image.count == 1) return thumbnail;
    return Badge(label: Text('${image.count}'), child: thumbnail);
  }
}

class _Progress extends StatelessWidget {
  final int processed;
  final int total;

  const _Progress({required this.processed, required this.total});

  @override
  Widget build(BuildContext context) {
    final value = total == 0 ? null : processed / total;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Text(
            "Importing cards…",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          LinearProgressIndicator(value: value, minHeight: 8),
          Text("$processed of $total"),
          const Text(
            "Keep the app open until the import is finished.",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Done extends StatelessWidget {
  final FlashcardImportSummary summary;
  final String packName;

  const _Done({required this.summary, required this.packName});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final error = summary.error;
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Icon(
              error == null ? Icons.check_circle : Icons.error,
              size: 72,
              color: error == null ? Colors.green : context.colors.error,
            ),
            Text(
              error == null ? "Import complete" : "Import stopped",
              style: textTheme.headlineSmall,
            ),
            Text(
              "${summary.imported} cards were added to \"$packName\".",
              textAlign: TextAlign.center,
            ),
            if (summary.updated > 0)
              Text(
                "${summary.updated} cards that changed in Anki were updated.",
                textAlign: TextAlign.center,
              ),
            if (summary.skippedDuplicates > 0)
              Text(
                "${summary.skippedDuplicates} cards were already in the pack "
                "with no changes.",
                textAlign: TextAlign.center,
              ),
            if (summary.failedUpdates > 0)
              Text(
                "${summary.failedUpdates} changed cards couldn't be updated. "
                "Import the file again to retry them.",
                textAlign: TextAlign.center,
              ),
            if (summary.failedImages > 0)
              Text(
                "${summary.failedImages} images couldn't be uploaded, those "
                "cards were added without them.",
                textAlign: TextAlign.center,
              ),
            if (error != null) ...[
              Text(
                extractErrorMessage(error),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.error),
              ),
              const Text(
                "Import the same file again to add the remaining cards. "
                "Cards already in the pack won't be added twice.",
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.router.pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text("Done"),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadError extends StatelessWidget {
  final Object error;
  final VoidCallback onPickAnother;

  const _ReadError({required this.error, required this.onPickAnother});

  @override
  Widget build(BuildContext context) {
    final message = error is AnkiImportException
        ? (error as AnkiImportException).message
        : extractErrorMessage(error);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          Icon(Icons.error_outline, size: 64, color: context.colors.error),
          Text(
            "This file couldn't be imported",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(message, textAlign: TextAlign.center),
          FilledButton(
            onPressed: onPickAnother,
            child: const Text("Choose another file"),
          ),
        ],
      ),
    );
  }
}
