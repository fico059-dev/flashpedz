import 'package:flashcards/data/services/api/algolia_search/flashcards_searcher_service.dart';
import 'package:flashcards/data/services/api/algolia_search/local_search.dart';
import 'package:flashcards/domain/models/algolia/algolia_flashcard/algolia_flashcard.dart';
import 'package:flashcards/domain/models/algolia/pack_search_result/search_result_with_tags.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/utils/result.dart';

class FlashcardsSearcherRepository {
  final FlashcardsSearcherService _flashcardsSearcherService;

  /// After this long the server is asked whether cards changed (in the
  /// background; the cards already here are searched meanwhile).
  static const _checkAfter = Duration(minutes: 10);
  List<LocalSearchItem<AlgoliaFlashcard>>? _items;
  Map<String, AlgoliaFlashcard> _byId = const {};
  Map<String, CardImages> _images = const {};
  String? _version;
  DateTime? _checkedAt;
  Future<Result<void>>? _refreshing;

  FlashcardsSearcherRepository({
    required FlashcardsSearcherService flashcardsSearcherService,
  }) : _flashcardsSearcherService = flashcardsSearcherService;

  void _use(SearchCards cards) {
    _version = cards.version;
    _byId = {for (final card in cards.cards) card.objectID: card};
    _images = cards.images;
    _items = cards.cards
        .map(
          (card) => LocalSearchItem(
            item: card,
            text: '${card.question}\n${card.answer}',
            tagIds: card.tags,
          ),
        )
        .toList();
  }

  /// Asks the server for the cards, downloading them only when changed.
  Future<Result<void>> _refresh() => _refreshing ??= () async {
    try {
      final result = await _flashcardsSearcherService.getAllFlashcards(
        version: _items == null ? null : _version,
      );
      switch (result) {
        case Error<SearchCards?>(:final error):
          return Result<void>.error(error);
        case Ok<SearchCards?>(:final value):
          if (value != null) _use(value);
          _checkedAt = DateTime.now();
          return Result<void>.ok(null);
      }
    } finally {
      _refreshing = null;
    }
  }();

  /// Gets the cards ready before the first search: the copy kept on the
  /// device straight away, then the latest from the server.
  Future<Result<void>> preload() async {
    if (_items == null) {
      try {
        await _flashcardsSearcherService.forgetSavedOnWeb();
        final saved = await _flashcardsSearcherService.readSaved();
        if (saved != null && _items == null) _use(saved);
      } catch (_) {
        // Downloaded instead.
      }
    }
    final checkedAt = _checkedAt;
    final fresh =
        checkedAt != null && DateTime.now().difference(checkedAt) < _checkAfter;
    if (fresh) return Result.ok(null);
    final refresh = _refresh();
    // With cards to search already, don't wait for the server.
    if (_items != null) return Result.ok(null);
    return refresh;
  }

  /// The cards with these ids that the search list has (in the same
  /// order), so they can be shown without reading each from the server.
  /// Missing ones (e.g. not in the list yet) are left out.
  Future<List<Flashcard>> cardsByIds(Iterable<String> ids) async {
    if (_items == null) {
      await preload().timeout(
        const Duration(seconds: 6),
        onTimeout: () => Result.ok(null),
      );
    }
    // Older lists have no pictures: the cards are read instead.
    if (!(_version ?? '').startsWith('img-')) return const [];
    return [
      for (final id in ids)
        if (_byId[id] case final card?)
          Flashcard(
            id: id,
            packId: card.packId,
            question: card.question,
            answer: card.answer,
            isPaid: card.isPaid,
            tags: card.tags.map(Tag.fromId).toList(),
            questionImageUrl: _images[id]?.question,
            answerImageUrl: _images[id]?.answer,
          ),
    ];
  }

  /// Searches flashcards by question, answer and tags.
  Future<Result<SearchResultWithTags<AlgoliaFlashcard>>> searchFlashcards({
    required String query,
    required List<Tag> tags,
    required int page,

    /// Only cards of these packs, when given.
    Set<String>? packIds,
  }) async {
    final ready = await preload();
    if (_items == null) {
      return switch (ready) {
        Error<void>(:final error) => Result.error(error),
        Ok<void>() => Result.error(Exception('No flashcards to search.')),
      };
    }

    final items = packIds == null
        ? _items!
        : _items!.where((i) => packIds.contains(i.item.packId)).toList();
    return Result.ok(
      searchLocally(
        items: items,
        query: query,
        tagIds: tags.map((tag) => tag.id).toList(),
        page: page,
      ),
    );
  }
}
