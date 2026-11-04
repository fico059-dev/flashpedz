import 'package:flashcards/data/repositories/card_sets/card_set_repository.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/ui/dialogs/card_sets/card_set_dialogs.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flashcards/ui/widgets/core/images/image_preview.dart';
import 'package:flashcards/ui/widgets/flashcard/card_content.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Opens the list of cards of a custom session or a set.
Future<void> openCardBrowser(
  BuildContext context, {
  required String title,
  required Future<List<String>> Function() loadIds,
  String? setId,
  Future<void> Function(BuildContext context)? onStudy,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CardBrowserPage(
        title: title,
        loadIds: loadIds,
        setId: setId,
        onStudy: onStudy,
      ),
    ),
  );
}

/// The cards of a custom session or a set, to look through like a pack:
/// tap a card to see its answer.
class CardBrowserPage extends StatefulWidget {
  final String title;
  final Future<List<String>> Function() loadIds;

  /// The set shown, so its cards can be taken out of it.
  final String? setId;
  final Future<void> Function(BuildContext context)? onStudy;

  const CardBrowserPage({
    super.key,
    required this.title,
    required this.loadIds,
    this.setId,
    this.onStudy,
  });

  @override
  State<CardBrowserPage> createState() => _CardBrowserPageState();
}

class _CardBrowserPageState extends State<CardBrowserPage> {
  static const _pageSize = 30;

  List<String>? _ids;
  final _cards = <Flashcard>[];
  var _loadedIds = 0;
  var _loading = false;
  Object? _error;
  final _open = <String>{};
  final _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _ids = await widget.loadIds();
      await _loadMore();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final ids = _ids;
    if (ids == null || _loadedIds >= ids.length) return;
    setState(() => _loading = true);
    final next = ids.skip(_loadedIds).take(_pageSize).toList();
    final cards = await context.read<FlashcardRepository>().getFlashcardsByIds(
      next,
    );
    if (!mounted) return;
    setState(() {
      _cards.addAll(cards);
      _loadedIds += next.length;
      _loading = false;
    });
  }

  Future<void> _removeFromSet(Flashcard card) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<CardSetRepository>().setCard(
        widget.setId!,
        card.id,
        false,
      );
      setState(() => _cards.removeWhere((c) => c.id == card.id));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(extractErrorMessage(error))),
      );
    }
  }

  bool _matches(Flashcard card) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return card.question.toLowerCase().contains(q) ||
        card.answer.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final ids = _ids;
    final shown = _cards.where(_matches).toList();
    final hasMore = ids != null && _loadedIds < ids.length;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: widget.onStudy == null || (ids?.isEmpty ?? true)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => widget.onStudy!(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Study'),
            ),
      body: ReadableWidth(
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 12,
                    children: [
                      Text(extractErrorMessage(_error!)),
                      FilledButton(
                        onPressed: _start,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            : ids == null
            ? const Center(child: CircularProgressIndicator())
            : ids.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No cards here yet. While studying, use ⋮ → Add to set.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                itemCount: shown.length + 2,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _search,
                        onChanged: (value) =>
                            setState(() => _query = value.trim()),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: hasMore
                              ? 'Search the loaded cards'
                              : 'Search ${ids.length} cards',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                      ),
                    );
                  }
                  if (index == shown.length + 1) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _loading
                            ? const CircularProgressIndicator()
                            : hasMore
                            ? OutlinedButton(
                                onPressed: _loadMore,
                                child: Text(
                                  'Show more ($_loadedIds of ${ids.length})',
                                ),
                              )
                            : Text('${_cards.length} cards'),
                      ),
                    );
                  }
                  final card = shown[index - 1];
                  return _BrowsedCard(
                    card: card,
                    isOpen: _open.contains(card.id),
                    onToggle: () => setState(
                      () => _open.contains(card.id)
                          ? _open.remove(card.id)
                          : _open.add(card.id),
                    ),
                    onRemoveFromSet: widget.setId == null
                        ? null
                        : () => _removeFromSet(card),
                  );
                },
              ),
      ),
    );
  }
}

enum _CardAction { addToSet, removeFromSet }

class _BrowsedCard extends StatelessWidget {
  final Flashcard card;
  final bool isOpen;
  final VoidCallback onToggle;
  final VoidCallback? onRemoveFromSet;

  const _BrowsedCard({
    required this.card,
    required this.isOpen,
    required this.onToggle,
    this.onRemoveFromSet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      // Taps open the card instead of selecting text.
                      child: IgnorePointer(
                        child: CardContent(
                          revealClozeQuestion(card.question),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  PopupMenuButton<_CardAction>(
                    tooltip: 'Card options',
                    onSelected: (action) => switch (action) {
                      _CardAction.addToSet => showAddToSetSheet(
                        context,
                        card.id,
                      ),
                      _CardAction.removeFromSet => onRemoveFromSet?.call(),
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _CardAction.addToSet,
                        child: ListTile(
                          leading: Icon(Icons.playlist_add),
                          title: Text('Add to set…'),
                        ),
                      ),
                      if (onRemoveFromSet != null)
                        const PopupMenuItem(
                          value: _CardAction.removeFromSet,
                          child: ListTile(
                            leading: Icon(Icons.playlist_remove),
                            title: Text('Remove from this set'),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (card.questionImageUrl?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 10),
                  child: ImagePreview(
                    downloadUrl: card.questionImageUrl,
                    height: 160,
                  ),
                ),
              if (isOpen) ...[
                const Divider(height: 20),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: CardContent(card.answer),
                ),
                if (card.answerImageUrl?.isNotEmpty ?? false)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: ImagePreview(
                      downloadUrl: card.answerImageUrl,
                      height: 160,
                    ),
                  ),
              ] else
                Text(
                  'Tap to show the answer',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
