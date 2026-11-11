import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pack_card_bulk_actions.dart';
import 'package:flashcards/data/repositories/flashcards/tag_repository.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tags implements TagRepository {
  @override
  Future<Result<List<Tag>>> getAllTags() async =>
      Result.ok([Tag.fromId('cardio')]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cards implements FlashcardRepository {
  /// False: the server doesn't have the bulk change (not deployed).
  final bool bulkAvailable;
  _Cards({this.bulkAvailable = true});

  final bulkCalls = <(List<String>, List<String>, List<String>)>[];
  final oneByOne = <String>[];

  @override
  Future<({int updated, int failed})?> bulkUpdateTags({
    required List<Flashcard> cards,
    List<Tag> add = const [],
    List<Tag> remove = const [],
    required List<Tag> allAvailableTags,
    void Function(int finished, int total)? onProgress,
  }) async {
    if (!bulkAvailable) return null;
    bulkCalls.add((
      cards.map((c) => c.id).toList(),
      add.toIdList(),
      remove.toIdList(),
    ));
    onProgress?.call(cards.length, cards.length);
    return (updated: cards.length, failed: 0);
  }

  @override
  Future<Result<void>> updateFlashcardEverywhere({
    required String packId,
    required String flashcardId,
    required List<Tag> allAvailableTags,
    String? question,
    String? answer,
    List<Tag>? selectedTags,
    List<Tag>? oldTags,
    dynamic questionImageData,
    dynamic answerImageData,
  }) async {
    oneByOne.add(flashcardId);
    return Result.ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Flashcard _card(String id, List<String> tags) => Flashcard(
  id: id,
  packId: 'p',
  question: 'Q',
  answer: 'A',
  tags: tags.map(Tag.fromId).toList(),
);

void main() {
  final cards = [
    _card('a', ['cardio']),
    _card('b', []),
    _card('c', ['dara']),
  ];

  test('adding a tag to many cards is one bulk change', () async {
    final repo = _Cards();
    final progress = <(int, int)>[];
    final outcome =
        await PackCardBulkActions(flashcardRepo: repo, tagRepo: _Tags()).addTag(
          cards,
          Tag.fromId('dara'),
          onProgress: (f, t) => progress.add((f, t)),
        );
    // c already has it.
    final (ids, add, remove) = repo.bulkCalls.single;
    expect([ids, add, remove], [
      ['a', 'b'],
      ['dara'],
      isEmpty,
    ]);
    expect(repo.oneByOne, isEmpty);
    expect((outcome.done, outcome.skipped, outcome.failed), (2, 1, 0));
    expect(progress.last, (2, 2));
  });

  test('removing a tag only sends the cards that have it', () async {
    final repo = _Cards();
    final outcome = await PackCardBulkActions(
      flashcardRepo: repo,
      tagRepo: _Tags(),
    ).removeTag(cards, Tag.fromId('cardio'));
    final (ids, add, remove) = repo.bulkCalls.single;
    expect([ids, add, remove], [
      ['a'],
      isEmpty,
      ['cardio'],
    ]);
    expect((outcome.done, outcome.skipped), (1, 2));
  });

  test('an older server: cards are changed one by one', () async {
    final repo = _Cards(bulkAvailable: false);
    final outcome = await PackCardBulkActions(
      flashcardRepo: repo,
      tagRepo: _Tags(),
    ).addTag(cards, Tag.fromId('dara'));
    expect(repo.oneByOne, ['a', 'b']);
    expect(outcome.done, 2);
  });
}
