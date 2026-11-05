import 'package:flashcards/data/repositories/algolia_search/flashcards_searcher_repository.dart';
import 'package:flashcards/data/repositories/flashcards/fast_cards.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pack_repository.dart';
import 'package:flashcards/data/services/local/pdf_export_service.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/highlight/highlight.dart';
import 'package:flashcards/domain/models/flashcards/simple_pack/simple_pack.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/ui/widgets/notebook/highlights_list.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Which highlights go into the PDF.
enum HighlightExportScope { all, packs, tags }

/// The highlights to export, grouped by pack (named by [packNames]),
/// oldest card first within a pack. With [packIds] only those packs; with
/// [tagIds] only cards that have one of those tags (or topics).
List<HighlightPdfSection> highlightSectionsForExport({
  required List<Highlight> highlights,
  required Map<String, Flashcard> cards,
  required Map<String, String> packNames,
  Set<String>? packIds,
  Set<String>? tagIds,
}) {
  final byPack = <String, Map<String, List<Highlight>>>{};
  // Oldest first reads like the order they were studied.
  for (final highlight in highlights.reversed) {
    if (highlight.isUnderline) continue;
    final card = cards[highlight.flashcardId];
    final packId = card?.packId ?? highlight.packId;
    if (packIds != null && !packIds.contains(packId)) continue;
    if (tagIds != null &&
        !(card?.tags.any((tag) => tagIds.contains(tag.id)) ?? false)) {
      continue;
    }
    byPack
        .putIfAbsent(packId, () => {})
        .putIfAbsent(highlight.flashcardId, () => [])
        .add(highlight);
  }
  final sections = [
    for (final MapEntry(key: packId, value: byCard) in byPack.entries)
      HighlightPdfSection(packNames[packId] ?? 'Other cards', [
        for (final MapEntry(key: cardId, value: marks) in byCard.entries)
          HighlightPdfCard(
            plainCardText(
              readableQuestion(cards[cardId]?.question ?? marks.first.question),
            ),
            [for (final mark in marks) mark.text],
          ),
      ]),
  ]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return sections;
}

/// Lets the student choose highlights (all, by pack or by tag) and shares
/// them as a PDF.
Future<void> showExportHighlightsSheet(
  BuildContext context,
  List<Highlight> highlights,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => MultiProvider(
      providers: [
        Provider.value(value: context.read<FlashcardRepository>()),
        Provider.value(value: context.read<FlashcardsSearcherRepository?>()),
        Provider.value(value: context.read<PackRepository>()),
      ],
      child: ExportHighlightsSheet(highlights: highlights),
    ),
  );
}

class ExportHighlightsSheet extends StatefulWidget {
  final List<Highlight> highlights;

  /// Makes and shares the PDF; replaced in tests.
  final Future<void> Function(
    String filterLabel,
    List<HighlightPdfSection> sections,
  )?
  onExport;

  const ExportHighlightsSheet({
    super.key,
    required this.highlights,
    this.onExport,
  });

  @override
  State<ExportHighlightsSheet> createState() => _ExportHighlightsSheetState();
}

class _ExportHighlightsSheetState extends State<ExportHighlightsSheet> {
  Map<String, Flashcard>? _cards;
  final _packNames = <String, String>{};
  var _scope = HighlightExportScope.all;
  final _packs = <String>{};
  final _tags = <String>{};
  var _busy = false;
  String? _error;

  List<Highlight> get _marks =>
      widget.highlights.where((h) => !h.isUnderline).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cardIds = _marks.map((h) => h.flashcardId).toSet().toList();
    final packRepo = context.read<PackRepository>();
    Future<void> name(String id) async {
      if (_packNames.containsKey(id)) return;
      final result = await packRepo.getPack(id);
      if (result case Ok<SimplePack>(:final value)) {
        _packNames[id] = value.packName;
      }
    }

    // The pack names and the cards at the same time.
    final naming = Future.wait(_marks.map((h) => h.packId).toSet().map(name));
    final cards = await loadCardsFast(context, cardIds);
    await Future.wait([
      naming,
      ...cards.map((c) => c.packId).toSet().map(name),
    ]);
    if (!mounted) return;
    setState(() => _cards = {for (final card in cards) card.id: card});
  }

  /// Highlights per pack and per tag, for the choices.
  (Map<String, int>, Map<Tag, int>) _counts(Map<String, Flashcard> cards) {
    final packs = <String, int>{};
    final tags = <Tag, int>{};
    for (final mark in _marks) {
      final card = cards[mark.flashcardId];
      final packId = card?.packId ?? mark.packId;
      packs[packId] = (packs[packId] ?? 0) + 1;
      for (final tag in card?.tags ?? const <Tag>[]) {
        tags[tag] = (tags[tag] ?? 0) + 1;
      }
    }
    return (packs, tags);
  }

  Future<void> _export(Map<String, Flashcard> cards) async {
    final sections = highlightSectionsForExport(
      highlights: widget.highlights,
      cards: cards,
      packNames: _packNames,
      packIds: _scope == HighlightExportScope.packs ? _packs : null,
      tagIds: _scope == HighlightExportScope.tags ? _tags : null,
    );
    final label = switch (_scope) {
      HighlightExportScope.all => 'All highlights',
      HighlightExportScope.packs =>
        _packs.map((id) => _packNames[id] ?? 'Other cards').join(', '),
      HighlightExportScope.tags =>
        'Tags: ${_tags.map((id) => Tag.fromId(id).name).join(', ')}',
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final export = widget.onExport ?? _shareAsPdf;
      await export(label, sections);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't make the PDF. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Future<void> _shareAsPdf(
    String label,
    List<HighlightPdfSection> sections,
  ) async {
    final service = await PdfExportService.create(
      text: [
        for (final section in sections)
          for (final card in section.cards) ...[
            card.question,
            ...card.passages,
          ],
      ].join('\n'),
    );
    final bytes = await service.generateHighlightsPdf(
      filterLabel: label,
      sections: sections,
    );
    await service.sharePdf(bytes, pdfFileName('FlashPedz highlights'));
  }

  @override
  Widget build(BuildContext context) {
    final cards = _cards;
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: cards == null
              ? const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _content(context, theme, cards),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    ThemeData theme,
    Map<String, Flashcard> cards,
  ) {
    final (packCounts, tagCounts) = _counts(cards);
    final packs = packCounts.keys.toList()
      ..sort(
        (a, b) => (_packNames[a] ?? '').toLowerCase().compareTo(
          (_packNames[b] ?? '').toLowerCase(),
        ),
      );
    final tags = tagCounts.keys.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final ready = switch (_scope) {
      HighlightExportScope.all => _marks.isNotEmpty,
      HighlightExportScope.packs => _packs.isNotEmpty,
      HighlightExportScope.tags => _tags.isNotEmpty,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Export highlights as PDF', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        SegmentedButton<HighlightExportScope>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: HighlightExportScope.all, label: Text('All')),
            ButtonSegment(
              value: HighlightExportScope.packs,
              label: Text('By pack'),
            ),
            ButtonSegment(
              value: HighlightExportScope.tags,
              label: Text('By tag'),
            ),
          ],
          selected: {_scope},
          onSelectionChanged: (value) => setState(() => _scope = value.first),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: switch (_scope) {
              HighlightExportScope.all => [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'All ${_marks.length} highlights, grouped by pack.',
                  ),
                ),
              ],
              HighlightExportScope.packs => [
                for (final id in packs)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_packNames[id] ?? 'Other cards'),
                    subtitle: Text('${packCounts[id]} highlights'),
                    value: _packs.contains(id),
                    onChanged: (on) => setState(
                      () => on == true ? _packs.add(id) : _packs.remove(id),
                    ),
                  ),
              ],
              HighlightExportScope.tags => [
                if (tags.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('The highlighted cards have no tags.'),
                  ),
                for (final tag in tags)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tag.name),
                    subtitle: Text('${tagCounts[tag]} highlights'),
                    value: _tags.contains(tag.id),
                    onChanged: (on) => setState(
                      () =>
                          on == true ? _tags.add(tag.id) : _tags.remove(tag.id),
                    ),
                  ),
              ],
            },
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: ready && !_busy ? () => _export(cards) : null,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Make PDF'),
        ),
      ],
    );
  }
}
