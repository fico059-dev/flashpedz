import 'dart:io';
import 'dart:math';

import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/services/anki/anki_apkg_bytes_parser.dart';
import 'package:flashcards/data/services/anki/anki_occlusion.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flutter_test/flutter_test.dart';

OcclusionBlock occlusionOf(String text) =>
    parseCardMarkup(text).whereType<OcclusionBlock>().single;

void main() {
  // Made with Anki 26.09's own Image Occlusion code: a "hide all, guess one"
  // note (rectangle, ellipse, a rectangle and polygon grouped as c3, and a
  // text label) and a "hide one, guess one" note with two rectangles.
  final apkg = File('test/fixtures/image_occlusion.apkg').readAsBytesSync();

  test('an Anki image occlusion deck becomes occlusion cards', () {
    final result = parseAnkiPackageBytes(apkg);
    expect(result.cards.length, 5);
    expect(result.cards.every((c) => c.isOcclusion), isTrue);
    expect(result.missingImages, 0);

    final first = result.cards.first;
    expect(first.occlusionImage!.bytes, isNotNull);
    expect(first.tags, ['cardio::heart']);
    expect(first.question.split('\n').first, 'Label the **heart**');
    expect(first.answer.split('\n').last, 'Back extra note');

    // Hide all, guess one: every card shows the four boxes.
    final hideAll = result.cards.take(3).toList();
    final blocks = [for (final c in hideAll) occlusionOf(c.question)];
    expect(blocks.map((b) => b.masks.length), [4, 4, 4]);
    expect(blocks[0].masks[0], const OcclusionMask(.1, .2, .25, .1));
    // The ellipse is covered by the box around it.
    expect(blocks[0].masks[1].w, closeTo(.2, 1e-9));
    expect(blocks[0].masks[1].h, closeTo(.1, 1e-9));
    // The polygon too.
    final polygon = blocks[0].masks[3];
    expect(polygon.x, closeTo(.05, 1e-9));
    expect(polygon.y, closeTo(.65, 1e-9));
    expect(polygon.w, closeTo(.15, 1e-9));
    expect(polygon.h, closeTo(.25, 1e-9));

    expect(blocks.map((b) => b.target), [0, 1, 2]);
    // c3 asks the rectangle and the polygon together.
    expect(blocks[2].alsoAsked, [3]);
    expect(blocks[2].asks(3), isTrue);
    expect(blocks[2].asks(0), isFalse);
    expect(occlusionOf(hideAll[2].answer).revealed, isTrue);
    expect(hideAll.map((c) => c.sourceKey!.split(':').last), [
      'c1',
      'c2',
      'c3',
    ]);

    // Hide one, guess one: a card shows only its own box.
    final hideOne = result.cards.skip(3).toList();
    expect(occlusionOf(hideOne[0].question).masks, [
      const OcclusionMask(.3, .3, .2, .2),
    ]);
    expect(occlusionOf(hideOne[1].question).masks, [
      const OcclusionMask(.6, .6, .2, .2),
    ]);
    // No header or back extra: only the picture.
    expect(hideOne[0].question.split('\n'), hasLength(1));
  });

  test('older Anki versions stored pixels', () {
    final shapes = parseAnkiOcclusionShapes(
      '{{c1::image-occlusion:rect:left=40:top=60:width=100:height=30:oi=1}}',
    );
    final card = ankiOcclusionCards(
      shapes,
      imageSize: const Point(400, 300),
    ).single;
    expect(
      occlusionOf(card.question).masks.single,
      const OcclusionMask(.1, .2, .25, .1),
    );
  });

  test('escaped colons and text labels', () {
    final shapes = parseAnkiOcclusionShapes(
      r'{{c0::image-occlusion:text:text=a\:b:left=.1:top=.1}}'
      r'{{c2::image-occlusion:rect:left=.5:top=.5:width=.1:height=.1:fill=#ff\:00}}',
    );
    expect(shapes.single.ordinal, 2);
  });

  test('the uploaded picture replaces the stand-in address', () {
    final card = parseAnkiPackageBytes(apkg).cards.first;
    expect(card.question, contains(ankiOcclusionImageUrl));
    final uploaded = card.withOcclusionUrl('https://example.com/heart.jpg');
    expect(occlusionOf(uploaded.question).url, 'https://example.com/heart.jpg');
    expect(occlusionOf(uploaded.answer).url, 'https://example.com/heart.jpg');
    expect(uploaded.sourceKey, card.sourceKey);
  });

  test('importing the deck again reuses the uploaded picture', () {
    final card = parseAnkiPackageBytes(apkg).cards.first;
    final uploaded = card.withOcclusionUrl('https://example.com/heart.jpg');
    final existing = Flashcard(
      id: 'f1',
      packId: 'p1',
      question: uploaded.question,
      answer: uploaded.answer,
      tags: const [],
      sourceKey: card.sourceKey,
      sourceImages: card.imagesKey,
    );
    expect(
      reusableOcclusionUrl(card, existing),
      'https://example.com/heart.jpg',
    );
    final again = card.withOcclusionUrl(reusableOcclusionUrl(card, existing)!);
    expect(
      decideImportAction(again, existing, importTags: false),
      ImportAction.unchanged,
    );
    // A different picture in the deck is uploaded again.
    expect(
      reusableOcclusionUrl(
        card,
        existing.copyWith(sourceImages: '//other.png'),
      ),
      isNull,
    );
  });

  test('grouped boxes survive a round trip through the card text', () {
    final line = occlusionLine(
      url: 'https://example.com/a.jpg',
      masks: const [OcclusionMask(0, 0, .1, .1), OcclusionMask(.5, .5, .1, .1)],
      target: 0,
      alsoAsked: const [1],
      revealed: true,
    );
    expect(line, endsWith('#0+1!'));
    final block = occlusionOf(line);
    expect(block.target, 0);
    expect(block.alsoAsked, [1]);
    expect(block.revealed, isTrue);
    // Cards made in FlashPedz keep their old form.
    expect(
      occlusionLine(
        url: 'https://example.com/a.jpg',
        masks: const [OcclusionMask(0, 0, .1, .1)],
        target: 0,
      ),
      endsWith('#0'),
    );
  });
}
