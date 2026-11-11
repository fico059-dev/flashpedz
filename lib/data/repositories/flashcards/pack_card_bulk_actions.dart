import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/tag_repository.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/utils/result.dart';

/// How a change to many cards went.
class BulkOutcome {
  final int done;
  final int failed;
  final int skipped;

  const BulkOutcome({this.done = 0, this.failed = 0, this.skipped = 0});

  String describe(String verb) {
    final parts = ['$done $verb'];
    if (skipped > 0) parts.add('$skipped already done');
    if (failed > 0) parts.add('$failed failed, try them again');
    return parts.join(' · ');
  }
}

/// Changes to several cards of a pack at once, used by the pack editor.
class PackCardBulkActions {
  /// Cards changed at the same time; each change is a server call.
  static const _parallel = 6;

  final FlashcardRepository _flashcardRepo;
  final TagRepository _tagRepo;

  PackCardBulkActions({
    required FlashcardRepository flashcardRepo,
    required TagRepository tagRepo,
  }) : _flashcardRepo = flashcardRepo,
       _tagRepo = tagRepo;

  Future<BulkOutcome> delete(
    List<Flashcard> cards, {
    void Function(int finished, int total)? onProgress,
  }) => _run(
    cards,
    (card) => _flashcardRepo.deleteFlashcardEverywhere(card),
    onProgress,
  );

  Future<BulkOutcome> addTag(
    List<Flashcard> cards,
    Tag tag, {
    void Function(int finished, int total)? onProgress,
  }) async {
    final todo = cards
        .where((c) => !c.tags.any((t) => t.id == tag.id))
        .toList();
    final allTags = await _allTags();
    final fast = await _flashcardRepo.bulkUpdateTags(
      cards: todo,
      add: [tag],
      allAvailableTags: allTags,
      onProgress: onProgress,
    );
    if (fast != null) return _outcome(cards.length, fast);
    // Older server: one card at a time.
    final outcome = await _run(
      todo,
      (card) => _flashcardRepo.updateFlashcardEverywhere(
        packId: card.packId,
        flashcardId: card.id,
        allAvailableTags: allTags,
        selectedTags: [...card.tags, tag],
        oldTags: card.tags,
      ),
      onProgress,
      // A new tag is created by the first change; the others must not
      // create it again.
      afterFirst: () => allTags.add(tag),
    );
    return BulkOutcome(
      done: outcome.done,
      failed: outcome.failed,
      skipped: cards.length - todo.length,
    );
  }

  Future<BulkOutcome> removeTag(
    List<Flashcard> cards,
    Tag tag, {
    void Function(int finished, int total)? onProgress,
  }) async {
    final todo = cards.where((c) => c.tags.any((t) => t.id == tag.id)).toList();
    final allTags = await _allTags();
    final fast = await _flashcardRepo.bulkUpdateTags(
      cards: todo,
      remove: [tag],
      allAvailableTags: allTags,
      onProgress: onProgress,
    );
    if (fast != null) return _outcome(cards.length, fast);
    // Older server: one card at a time.
    final outcome = await _run(
      todo,
      (card) => _flashcardRepo.updateFlashcardEverywhere(
        packId: card.packId,
        flashcardId: card.id,
        allAvailableTags: allTags,
        selectedTags: card.tags.where((t) => t.id != tag.id).toList(),
        oldTags: card.tags,
      ),
      onProgress,
    );
    return BulkOutcome(
      done: outcome.done,
      failed: outcome.failed,
      skipped: cards.length - todo.length,
    );
  }

  static BulkOutcome _outcome(int total, ({int updated, int failed}) result) =>
      BulkOutcome(
        done: result.updated,
        failed: result.failed,
        skipped: total - result.updated - result.failed,
      );

  Future<List<Tag>> _allTags() async {
    final result = await _tagRepo.getAllTags();
    return switch (result) {
      Ok(:final value) => [...value],
      Error() => <Tag>[],
    };
  }

  Future<BulkOutcome> _run(
    List<Flashcard> cards,
    Future<Result<void>> Function(Flashcard card) change,
    void Function(int finished, int total)? onProgress, {
    void Function()? afterFirst,
  }) async {
    var done = 0;
    var failed = 0;
    var finished = 0;
    onProgress?.call(0, cards.length);

    Future<void> one(Flashcard card) async {
      Result<void> result;
      try {
        result = await change(card);
      } on Exception catch (error) {
        result = Result.error(error);
      }
      if (result is Ok<void>) {
        done++;
      } else {
        failed++;
      }
      onProgress?.call(++finished, cards.length);
    }

    var rest = cards;
    if (afterFirst != null && cards.isNotEmpty) {
      await one(cards.first);
      afterFirst();
      rest = cards.sublist(1);
    }
    for (var i = 0; i < rest.length; i += _parallel) {
      final end = i + _parallel > rest.length ? rest.length : i + _parallel;
      await Future.wait(rest.sublist(i, end).map(one));
    }
    return BulkOutcome(done: done, failed: failed);
  }
}
