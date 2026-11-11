import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/tag_repository.dart';
import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/ui/pages/profile/admin_dashboard/flashcard_builder/manage_pack_flashcards_page.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'pack_card_filter_test.dart' show card;

class _FakeCards implements FlashcardRepository {
  List<Flashcard> cards;
  final updates = <String, List<String>>{};
  final deleted = <String>[];

  _FakeCards(this.cards);

  @override
  Future<Result<List<Flashcard>>> getAllFlashcardsInPack(String packId) async =>
      Result.ok(List.of(cards));

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
    updates[flashcardId] = selectedTags!.map((t) => t.id).toList();
    cards = [
      for (final c in cards)
        c.id == flashcardId ? c.copyWith(tags: selectedTags) : c,
    ];
    return Result.ok(null);
  }

  /// The fast way: all the cards in one request.
  @override
  Future<({int updated, int failed})?> bulkUpdateTags({
    required List<Flashcard> cards,
    List<Tag> add = const [],
    List<Tag> remove = const [],
    required List<Tag> allAvailableTags,
    void Function(int finished, int total)? onProgress,
  }) async {
    bulkRequests++;
    final removeIds = remove.map((t) => t.id).toSet();
    for (final card in cards) {
      final tags = [
        for (final t in [...card.tags, ...add])
          if (!removeIds.contains(t.id)) t,
      ];
      await updateFlashcardEverywhere(
        packId: card.packId,
        flashcardId: card.id,
        allAvailableTags: allAvailableTags,
        selectedTags: {for (final t in tags) t.id: t}.values.toList(),
      );
    }
    onProgress?.call(cards.length, cards.length);
    return (updated: cards.length, failed: 0);
  }

  int bulkRequests = 0;

  @override
  Future<Result<void>> deleteFlashcardEverywhere(Flashcard flashcard) async {
    deleted.add(flashcard.id);
    cards = cards.where((c) => c.id != flashcard.id).toList();
    return Result.ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTags implements TagRepository {
  @override
  Future<Result<List<Tag>>> getAllTags() async =>
      Result.ok([Tag.fromName('neoreview'), Tag.fromName('2025')]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeCards repo;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = _FakeCards([
      card('1', 'Neonatal jaundice causes', tags: ['neoreview', '2025']),
      card('2', 'Kawasaki disease criteria', tags: ['neoreview']),
      card('3', 'Asthma steps', tags: ['2025']),
      card('4', 'Croup management'),
    ]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FlashcardRepository>.value(value: repo),
          Provider<TagRepository>.value(value: _FakeTags()),
        ],
        child: MaterialApp(
          theme: lightThemeData,
          home: const ManagePackFlashcardsPage(
            pack: AdminPack(
              packId: 'p',
              packName: 'Pediatrics',
              flashcardsCount: 4,
              isPaid: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('search, select all shown, add a tag to them', (tester) async {
    await pump(tester);
    expect(find.text('4 cards'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'kawasaki');
    await tester.pumpAndSettle();
    expect(find.text('1 of 4 cards'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.text('No tags'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 4 cards'), findsOneWidget);
    await tester.tap(find.text('No tags'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(find.text('Select all'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('4 selected'), findsOneWidget);

    // Unselect one card by tapping it while selecting.
    await tester.tap(find.text('Croup management'));
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);

    await tester.tap(find.text('Add tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Board review');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    expect(repo.updates.keys.toSet(), {'1', '2', '3'});
    // One request for all of them.
    expect(repo.bulkRequests, 1);
    expect(repo.updates['2'], contains(Tag.fromName('Board review').id));
    expect(find.textContaining('3 tagged'), findsOneWidget);
    expect(find.textContaining('#Board'), findsNWidgets(3));
  });

  testWidgets('delete selected cards after confirming', (tester) async {
    await pump(tester);
    await tester.longPress(find.text('Asthma steps'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Croup management'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(repo.deleted.toSet(), {'3', '4'});
    expect(find.text('2 cards'), findsOneWidget);
  });
}
