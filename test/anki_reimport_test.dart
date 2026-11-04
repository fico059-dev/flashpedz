import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/services/anki/anki_import_models.dart';
import 'package:flashcards/data/services/anki/anki_tags.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flutter_test/flutter_test.dart';

Flashcard existing({
  String question = 'Q',
  String answer = 'A',
  List<String> tags = const [],
  String? questionImageUrl,
  String? answerImageUrl,
  String? sourceKey,
  String? sourceImages,
}) => Flashcard(
  id: 'f1',
  packId: 'p',
  question: question,
  answer: answer,
  tags: ankiTagsToTags(tags),
  questionImageUrl: questionImageUrl,
  answerImageUrl: answerImageUrl,
  sourceKey: sourceKey,
  sourceImages: sourceImages,
);

AnkiCard card({
  String question = 'Q',
  String answer = 'A',
  List<String> tags = const [],
  AnkiImage? questionImage,
  AnkiImage? answerImage,
  String? sourceKey = 'anki:g1',
}) => AnkiCard(
  question: question,
  answer: answer,
  tags: tags,
  questionImage: questionImage,
  answerImage: answerImage,
  sourceKey: sourceKey,
);

ImportAction decide(AnkiCard c, Flashcard? e, {bool tags = true}) =>
    decideImportAction(c, e, importTags: tags);

void main() {
  test('new note: added', () {
    expect(decide(card(), null), ImportAction.add);
  });

  test('same note, nothing changed: left alone', () {
    expect(
      decide(card(), existing(sourceKey: 'anki:g1', sourceImages: '/')),
      ImportAction.unchanged,
    );
  });

  test('answer or question edited in Anki: updated', () {
    final e = existing(sourceKey: 'anki:g1', sourceImages: '/');
    expect(decide(card(answer: 'A, more detail'), e), ImportAction.update);
    expect(decide(card(question: 'Q fixed'), e), ImportAction.update);
  });

  test('tags changed: updated only when tags are imported', () {
    final e = existing(sourceKey: 'anki:g1', sourceImages: '/');
    expect(decide(card(tags: ['nicu']), e), ImportAction.update);
    expect(decide(card(tags: ['nicu']), e, tags: false), ImportAction.unchanged);
  });

  test('cards imported before ids were kept get linked, not changed', () {
    expect(decide(card(), existing()), ImportAction.link);
  });

  test('image added in Anki is uploaded; a changed image replaced', () {
    const pic = AnkiImage(name: 'a.png', names: ['a.png']);
    const other = AnkiImage(name: 'b.png', names: ['b.png']);
    final noImage = existing(sourceKey: 'anki:g1', sourceImages: '/');
    expect(decide(card(answerImage: pic), noImage), ImportAction.update);
    expect(
      ImportImagePlan.of(card(answerImage: pic), noImage).uploadAnswer,
      isTrue,
    );

    final withImage = existing(
      sourceKey: 'anki:g1',
      answerImageUrl: 'https://x/a.jpg',
      sourceImages: '/a.png',
    );
    expect(decide(card(answerImage: pic), withImage), ImportAction.unchanged);
    expect(decide(card(answerImage: other), withImage), ImportAction.update);
  });

  test('image removed in Anki is removed; images added by hand are kept', () {
    final fromDeck = existing(
      sourceKey: 'anki:g1',
      questionImageUrl: 'https://x/q.jpg',
      sourceImages: 'q.png/',
    );
    expect(ImportImagePlan.of(card(), fromDeck).deleteQuestion, isTrue);

    final byHand = existing(questionImageUrl: 'https://x/q.jpg');
    expect(ImportImagePlan.of(card(), byHand).deleteQuestion, isFalse);
    expect(decide(card(), byHand), ImportAction.link);
  });

  test('a topic for the import is added to the cards', () {
    final cardio = Tag.topic('Cardiology');
    expect(
      importedCardTags(
        card(tags: ['Neo']),
        null,
        importTags: true,
        topic: cardio,
      ).map((t) => t.id),
      ['neo', 'topic--cardiology'],
    );
    // Without importing tags, the card's own tags are kept and its old
    // topic replaced.
    final e = existing(
      sourceKey: 'anki:g1',
      sourceImages: '/',
      tags: ['Mine', 'topic--renal'],
    );
    expect(
      importedCardTags(card(), e, importTags: false, topic: cardio)
          .map((t) => t.id),
      ['mine', 'topic--cardiology'],
    );
    expect(
      decideImportAction(card(), e, importTags: false, topic: cardio),
      ImportAction.update,
    );
    expect(
      decideImportAction(card(), e, importTags: false),
      ImportAction.unchanged,
    );
  });
}
