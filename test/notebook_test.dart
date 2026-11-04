import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/data/repositories/notebook/highlight_repository.dart';
import 'package:flashcards/data/services/api/users/auth_service.dart';
import 'package:flashcards/domain/models/flashcards/highlight/highlight.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'package:flashcards/ui/widgets/notebook/highlightable_text.dart';
import 'package:flashcards/ui/widgets/notebook/highlights_list.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _User implements User {
  @override
  String get uid => 'u1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuth implements AuthService {
  @override
  User? getCurrentUser() => _User();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Stands in for the highlight Cloud Functions.
class FakeHighlightFunctions implements CloudFunctionService {
  final stored = <Map<String, dynamic>>[];
  final deleted = <String>[];
  bool failSaves = false;
  int _ids = 0;

  @override
  Future<String> saveHighlight(Map<String, dynamic> highlight) async {
    if (failSaves) throw Exception('No connection');
    final id = 'h${_ids++}';
    stored.insert(0, {
      ...highlight,
      'id': id,
      'createdAt': DateTime(2026, 10, 3).millisecondsSinceEpoch,
    });
    return id;
  }

  @override
  Future<void> deleteHighlight(String id) async {
    deleted.add(id);
    stored.removeWhere((h) => h['id'] == id);
  }

  @override
  Future<List<Map<String, dynamic>>> listHighlights() async => [...stored];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Highlight _h(String text, int start, {String id = 'x'}) => Highlight(
  id: id,
  flashcardId: 'c1',
  packId: 'p1',
  side: HighlightSide.answer,
  text: text,
  start: start,
  question: 'Q',
  createdAt: DateTime(2026),
);

HighlightRepository _repo(FakeHighlightFunctions functions) =>
    HighlightRepository(functions: functions, authService: FakeAuth());

const _target = HighlightTarget(
  flashcardId: 'c1',
  packId: 'p1',
  side: HighlightSide.answer,
  question: 'Which drug is first line for {AF rate control}?',
);

void main() {
  group('highlightRanges', () {
    const text = 'Beta blockers or calcium channel blockers.';

    test('uses the saved position when the text is still there', () {
      final ranges = highlightRanges(text, [_h('blockers', 33)]);
      expect(ranges.single.$1, 33);
    });

    test('falls back to the closest match when the text moved', () {
      final ranges = highlightRanges(text, [_h('blockers', 3)]);
      expect(ranges.single.$1, 5);
      expect(highlightRanges(text, [_h('missing', 0)]), isEmpty);
    });

    test('a selection cutting words is widened to whole words', () {
      const text = 'Beta blockers or calcium';
      expect(expandToWords(text, 1, 7), (0, 13));
      expect(text.substring(0, 13), 'Beta blockers');
      // Already on word edges: unchanged.
      expect(expandToWords(text, 5, 13), (5, 13));
      expect(expandToWords(text, 4, 6), (4, 13));
    });

    test('merges overlapping highlights', () {
      final ranges = highlightRanges(text, [
        _h('Beta blockers', 0),
        _h('blockers or', 5),
      ]);
      expect(ranges.map((r) => (r.$1, r.$2)), [(0, 16)]);
    });
  });

  test('repository: shows at once, saves, and undoes failed saves', () async {
    final functions = FakeHighlightFunctions();
    final repo = _repo(functions);
    await repo.load();
    expect(repo.isLoaded, isTrue);

    repo.add(
      flashcardId: 'c1',
      packId: 'p1',
      side: HighlightSide.answer,
      text: 'Beta blockers',
      start: 0,
      question: 'Q',
    );
    expect(repo.highlights.single.id, startsWith('local-'));
    await Future<void>.delayed(Duration.zero);
    expect(repo.highlights.single.id, 'h0');
    expect(functions.stored.single['text'], 'Beta blockers');

    functions.failSaves = true;
    Object? reported;
    repo.add(
      flashcardId: 'c1',
      packId: 'p1',
      side: HighlightSide.answer,
      text: 'calcium',
      start: 17,
      question: 'Q',
      onError: (e) => reported = e,
    );
    expect(repo.highlights, hasLength(2));
    await Future<void>.delayed(Duration.zero);
    expect(repo.highlights, hasLength(1));
    expect(reported, isNotNull);

    repo.remove(repo.highlights);
    await Future<void>.delayed(Duration.zero);
    expect(repo.highlights, isEmpty);
    expect(functions.deleted, ['h0']);
  });

  testWidgets('select text and tap Highlight, then remove it', (tester) async {
    final functions = FakeHighlightFunctions();
    final repo = _repo(functions);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: MaterialApp(
          theme: lightThemeData,
          home: const Scaffold(
            body: Center(
              child: HighlightableText(
                'Beta blockers or calcium channel blockers.',
                target: _target,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Long press selects a word and opens the selection menu.
    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    expect(find.text('Highlight'), findsOneWidget);
    await tester.tap(find.text('Highlight'));
    await tester.pumpAndSettle();

    expect(repo.highlights, hasLength(1));
    expect(functions.stored.single['side'], 'answer');
    expect(
      functions.stored.single['question'],
      'Which drug is first line for {AF rate control}?',
    );
    final span = tester.widget<SelectableText>(find.byType(SelectableText));
    final highlighted = span.textSpan!.children!.cast<TextSpan>().where(
      (s) => s.style?.backgroundColor == highlightBackground,
    );
    expect(highlighted.single.text, repo.highlights.single.text);

    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    expect(find.text('Remove highlight'), findsOneWidget);
    expect(find.text('Highlight'), findsNothing);
    await tester.tap(find.text('Remove highlight'));
    await tester.pumpAndSettle();
    expect(repo.highlights, isEmpty);
  });

  testWidgets('with a mouse, selecting text offers Highlight right away', (
    tester,
  ) async {
    final functions = FakeHighlightFunctions();
    final repo = _repo(functions);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: MaterialApp(
          theme: lightThemeData,
          home: const Scaffold(
            body: Center(
              child: HighlightableText(
                'Beta blockers or calcium channel blockers.',
                target: _target,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Drag across the first words with the mouse.
    final rect = tester.getRect(find.byType(SelectableText));
    final gesture = await tester.startGesture(
      rect.centerLeft + const Offset(2, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(rect.center);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Highlight'), findsOneWidget);
    await tester.tap(find.text('Highlight'));
    await tester.pumpAndSettle();
    expect(repo.highlights, hasLength(1));
    expect(repo.highlights.single.text, startsWith('Beta'));
  });

  testWidgets('underline marks the card but stays out of the notebook', (
    tester,
  ) async {
    final functions = FakeHighlightFunctions();
    final repo = _repo(functions);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: repo,
        child: MaterialApp(
          theme: lightThemeData,
          home: const Scaffold(
            body: Center(
              child: HighlightableText(
                'Beta blockers or calcium channel blockers.',
                target: _target,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    expect(find.text('Highlight'), findsOneWidget);
    expect(find.text('Underline'), findsOneWidget);
    await tester.tap(find.text('Underline'));
    await tester.pumpAndSettle();

    expect(repo.highlights.single.isUnderline, isTrue);
    expect(functions.stored.single['kind'], 'underline');
    expect(repo.notebookHighlights, isEmpty);
    final span = tester.widget<SelectableText>(find.byType(SelectableText));
    final underlined = span.textSpan!.children!.cast<TextSpan>().where(
      (s) => s.style?.decorationColor == underlineColor,
    );
    expect(underlined.single.text, repo.highlights.single.text);
    expect(underlined.single.style?.backgroundColor, isNull);

    // The same words can be highlighted too; the menu offers both.
    await tester.longPress(find.byType(SelectableText));
    await tester.pumpAndSettle();
    expect(find.text('Remove underline'), findsOneWidget);
    await tester.tap(find.text('Highlight'));
    await tester.pumpAndSettle();
    expect(repo.notebookHighlights, hasLength(1));
    expect(repo.highlights, hasLength(2));
  });

  testWidgets('notebook lists highlights by card and searches', (tester) async {
    final functions = FakeHighlightFunctions();
    final repo = _repo(functions);
    for (final (card, text) in [
      ('c1', 'Beta blockers'),
      ('c2', 'Kussmaul breathing'),
      ('c1', 'calcium channel blockers'),
    ]) {
      functions.stored.insert(0, {
        'id': 'id$text',
        'flashcardId': card,
        'packId': 'p',
        'side': 'answer',
        'text': text,
        'start': 0,
        'question': card == 'c1' ? 'AF {rate} control?' : 'DKA signs?',
        'createdAt': 0,
      });
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: lightThemeData,
        home: Scaffold(body: HighlightsList(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AF rate control?'), findsOneWidget);
    expect(find.text('DKA signs?'), findsOneWidget);
    expect(find.text('Beta blockers'), findsOneWidget);
    expect(find.text('Search 3 highlights'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'kussmaul');
    await tester.pumpAndSettle();
    expect(find.text('AF rate control?'), findsNothing);
    expect(find.text('Kussmaul breathing'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete highlight'));
    await tester.pumpAndSettle();
    expect(functions.deleted, ['idKussmaul breathing']);
  });

  testWidgets('notebook explains how to highlight when empty', (tester) async {
    final repo = _repo(FakeHighlightFunctions());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HighlightsList(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No highlights yet'), findsOneWidget);
  });
}
