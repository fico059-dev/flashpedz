import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flashcards/data/repositories/algolia_search/flashcards_searcher_repository.dart';
import 'package:flashcards/data/services/api/algolia_search/flashcards_searcher_service.dart';
import 'package:flashcards/domain/models/algolia/algolia_flashcard/algolia_flashcard.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

const _cards = [
  AlgoliaFlashcard(
    objectID: '1',
    question: 'Palivizumab for ex-preterm infants',
    answer: 'RSV prophylaxis',
    isPaid: false,
    tags: [],
    packId: 'neo',
  ),
  AlgoliaFlashcard(
    objectID: '2',
    question: 'Palivizumab dose',
    answer: '15 mg/kg monthly',
    isPaid: false,
    tags: [],
    packId: 'neo-drugs',
  ),
  AlgoliaFlashcard(
    objectID: '3',
    question: 'Palivizumab in CHD',
    answer: 'Hemodynamically significant CHD',
    isPaid: false,
    tags: [],
    packId: 'cardio',
  ),
];

class _Service implements FlashcardsSearcherService {
  SearchCards? saved;
  final versionsAsked = <String?>[];
  int downloads = 0;
  bool offline = false;

  @override
  Future<Result<SearchCards?>> getAllFlashcards({String? version}) async {
    versionsAsked.add(version);
    if (offline) return Result.error(Exception('No connection'));
    if (version == 'v1') return Result.ok(null);
    downloads++;
    return Result.ok((version: 'v1', cards: _cards, images: const {}));
  }

  @override
  Future<SearchCards?> readSaved() async => saved;

  @override
  Future<void> forgetSavedOnWeb() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('searching while studying can stay inside the pack', () async {
    final repo = FlashcardsSearcherRepository(
      flashcardsSearcherService: _Service(),
    );
    Future<List<String>> ids(Set<String>? packs) async {
      final result = await repo.searchFlashcards(
        query: 'palivizumab',
        tags: const [],
        page: 0,
        packIds: packs,
      );
      return (result as Ok).value.hits
          .map<String>((card) => card.objectID as String)
          .toList();
    }

    // The pack and its sub-pack.
    expect(await ids({'neo', 'neo-drugs'}), ['1', '2']);
    expect(await ids(null), ['1', '2', '3']);
  });

  test(
    'saved cards are searched at once and only re-downloaded when changed',
    () async {
      final service = _Service()
        ..saved = (
          version: 'v1',
          cards: _cards.take(1).toList(),
          images: const {},
        )
        ..offline = true;
      final repo = FlashcardsSearcherRepository(
        flashcardsSearcherService: service,
      );
      // Offline, the copy on the device is still searched.
      final result = await repo.searchFlashcards(
        query: 'palivizumab',
        tags: const [],
        page: 0,
      );
      expect((result as Ok).value.hitCount, 1);
      expect(service.versionsAsked, ['v1']);

      // Online: the server says the device's copy is current.
      service.offline = false;
      final fresh = FlashcardsSearcherRepository(
        flashcardsSearcherService: service
          ..saved = (version: 'v1', cards: _cards, images: const {}),
      );
      await fresh.preload();
      await fresh.searchFlashcards(query: 'dose', tags: const [], page: 0);
      expect(service.downloads, 0);

      // Nothing kept on the device: downloaded once.
      final empty = FlashcardsSearcherRepository(
        flashcardsSearcherService: _Service(),
      );
      final first = await empty.searchFlashcards(
        query: 'chd',
        tags: const [],
        page: 0,
      );
      expect((first as Ok).value.hitCount, 1);
    },
  );

  test('the compressed list from the server is unpacked', () {
    final json = jsonEncode([
      {'id': 'b', 'question': 'Zinc', 'answer': 'Wound', 'packId': 'p'},
      {
        'id': 'a',
        'question': 'Apnea – caffeine',
        'answer': '<b>20 mg/kg</b>',
        'isPaid': true,
        'tags': ['neo'],
        'packId': 'p',
      },
    ]);
    final gzip = base64Encode(GZipEncoder().encodeBytes(utf8.encode(json)));
    final cards = decodeSearchCards(gzip);
    expect(cards.map((c) => c.objectID), ['a', 'b']);
    expect(cards.first.question, 'Apnea – caffeine');
    expect(cards.first.isPaid, isTrue);
    expect(cards.first.tags, ['neo']);
    expect(cards.last.tags, isEmpty);
  });

  test('pictures come with the list; cards are found by id', () async {
    final json = jsonEncode([
      {
        'id': 'a',
        'question': 'Q',
        'answer': 'A',
        'packId': 'p',
        'tags': ['topic--renal'],
        'answerImageUrl': 'https://x/a.png',
      },
      {'id': 'b', 'question': 'Q2', 'answer': 'A2', 'packId': 'p'},
    ]);
    final gzip = base64Encode(GZipEncoder().encodeBytes(utf8.encode(json)));
    final images = <String, CardImages>{};
    decodeSearchCards(gzip, images: images);
    expect(images.keys, ['a']);
    expect(images['a']!.answer, 'https://x/a.png');

    final service = _Service()
      ..saved = (
        version: 'img-1',
        cards: decodeSearchCards(gzip),
        images: images,
      )
      ..offline = true;
    final repo = FlashcardsSearcherRepository(
      flashcardsSearcherService: service,
    );
    final cards = await repo.cardsByIds(['b', 'missing', 'a']);
    expect(cards.map((c) => c.id), ['b', 'a']);
    expect(cards.last.answerImageUrl, 'https://x/a.png');
    expect(cards.last.tags.single.isTopic, isTrue);
  });

  test('an older list (no pictures) is not used for cards', () async {
    final repo = FlashcardsSearcherRepository(
      flashcardsSearcherService: _Service(),
    );
    expect(await repo.cardsByIds(['1']), isEmpty);
  });
}
