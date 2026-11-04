import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/data/repositories/card_sets/card_set_repository.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/services/api/users/auth_service.dart';
import 'package:flashcards/domain/models/flashcards/custom_session_summary/custom_session_summary.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/ui/pages/card_browser/card_browser_page.dart';
import 'package:flashcards/ui/widgets/card_sets/my_sets_section.dart';
import 'package:flashcards/ui/widgets/previous_sessions/previous_session_card.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _User implements User {
  @override
  String get uid => 'u1';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements AuthService {
  @override
  User? getCurrentUser() => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The server: keeps sets in memory.
class _Functions implements CloudFunctionService {
  final sets = <Map<String, dynamic>>[
    {
      'id': 's1',
      'name': 'Cardio weak',
      'flashcardIds': ['c1', 'c2'],
    },
  ];
  bool failNext = false;

  @override
  Future<List<Map<String, dynamic>>> listCardSets() async => [
    for (final set in sets) Map.of(set),
  ];

  @override
  Future<String> saveCardSet({
    String? id,
    required String name,
    List<String>? flashcardIds,
  }) async {
    if (id == null) {
      if (sets.length >= 5) throw Exception('You can have up to 5 sets.');
      final newId = 's${sets.length + 1}';
      sets.add({'id': newId, 'name': name, 'flashcardIds': flashcardIds ?? []});
      return newId;
    }
    sets.firstWhere((s) => s['id'] == id)['name'] = name;
    return id;
  }

  @override
  Future<void> setCardInSet({
    required String setId,
    required String flashcardId,
    required bool inSet,
  }) async {
    if (failNext) {
      failNext = false;
      throw Exception('offline');
    }
    final ids = sets.firstWhere((s) => s['id'] == setId)['flashcardIds']
        as List<String>;
    inSet ? ids.add(flashcardId) : ids.remove(flashcardId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cards implements FlashcardRepository {
  @override
  Future<List<Flashcard>> getFlashcardsByIds(List<String> ids) async => [
    for (final id in ids)
      Flashcard(
        id: id,
        packId: 'p',
        question: 'Question $id',
        answer: 'Answer $id',
        tags: const [],
      ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Functions functions;
  late CardSetRepository repo;

  setUp(() {
    functions = _Functions();
    repo = CardSetRepository(functions: functions, authService: _Auth());
  });

  test('sets load, get cards and new sets, up to five', () async {
    await repo.load();
    expect(repo.sets.single.name, 'Cardio weak');
    expect(repo.sets.single.cardCount, 2);

    await repo.setCard('s1', 'c3', true);
    expect(repo.byId('s1')!.contains('c3'), isTrue);
    await repo.setCard('s1', 'c1', false);
    expect(repo.byId('s1')!.flashcardIds, ['c2', 'c3']);

    // A failed save is undone.
    functions.failNext = true;
    await expectLater(repo.setCard('s1', 'c9', true), throwsException);
    expect(repo.byId('s1')!.contains('c9'), isFalse);

    final made = await repo.create('Renal', flashcardIds: ['r1', 'r1', 'r2']);
    expect(made.flashcardIds, ['r1', 'r2']);
    for (final name in ['A', 'B', 'C']) {
      await repo.create(name);
    }
    expect(repo.sets.length, 5);
    expect(repo.canAddSet, isFalse);
    await expectLater(repo.create('Too many'), throwsException);
  });

  testWidgets('card list: answers on tap, search, take out of the set', (
    tester,
  ) async {
    await repo.load();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FlashcardRepository>.value(value: _Cards()),
          ChangeNotifierProvider.value(value: repo),
        ],
        child: MaterialApp(
          home: CardBrowserPage(
            title: 'Cardio weak',
            setId: 's1',
            loadIds: () async => repo.byId('s1')!.flashcardIds,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Question c1'), findsOneWidget);
    expect(find.text('Answer c1'), findsNothing);

    await tester.tap(find.text('Question c1'));
    await tester.pump();
    expect(find.text('Answer c1'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'c2');
    await tester.pump();
    expect(find.text('Question c1'), findsNothing);
    expect(find.text('Question c2'), findsOneWidget);

    await tester.tap(find.byTooltip('Card options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from this set'));
    await tester.pumpAndSettle();
    expect(find.text('Question c2'), findsNothing);
    expect(repo.byId('s1')!.flashcardIds, ['c1']);
  });

  testWidgets('My Sets lists the sets', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: MySetsSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My Sets (1/5)'), findsOneWidget);
    expect(find.text('Cardio weak'), findsOneWidget);
    expect(find.text('2 cards'), findsOneWidget);
    expect(find.byTooltip('Study'), findsOneWidget);
  });

  testWidgets('session options are in a menu, not behind a swipe', (
    tester,
  ) async {
    var browsed = false;
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightThemeData,
        home: Scaffold(
          body: PreviousSessionCard(
            hasCards: true,
            session: CustomSessionSummary(
              id: 'x',
              createdAt: DateTime(2026, 11, 1),
              isPaid: false,
              cardCount: 10,
              correctCount: 0,
              currentIndex: 2,
              name: 'Neo',
            ),
            onBrowsePressed: () => browsed = true,
            onDeletePressed: () => deleted = true,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Exam options'));
    await tester.pumpAndSettle();
    expect(find.text('Browse cards'), findsOneWidget);
    expect(find.text('Save as set'), findsOneWidget);
    await tester.tap(find.text('Browse cards'));
    await tester.pumpAndSettle();
    expect(browsed, isTrue);

    await tester.tap(find.byTooltip('Exam options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // Asks first.
    expect(deleted, isFalse);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);
  });
}
