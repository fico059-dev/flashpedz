import 'dart:io';

import 'package:flashcards/data/services/local/pdf_export_service.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/highlight/highlight.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/ui/dialogs/notebook/export_highlights_sheet.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pack_repository.dart';
import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

class _Cards implements FlashcardRepository {
  final Map<String, Flashcard> cards;
  _Cards(this.cards);
  @override
  Future<List<Flashcard>> getFlashcardsByIds(List<String> ids) async => [
    for (final id in ids)
      if (cards[id] case final card?) card,
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Packs implements PackRepository {
  final Map<String, String> names;
  _Packs(this.names);
  @override
  Future<Result<AdminPack>> getPack(String packId) async => Result.ok(
    AdminPack(
      packId: packId,
      packName: names[packId] ?? '?',
      flashcardsCount: 1,
      isPaid: false,
      tagCounts: const {},
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Highlight _mark(
  String card,
  String text, {
  String pack = 'p1',
  HighlightKind kind = HighlightKind.highlight,
  int day = 1,
}) => Highlight(
  id: '$card-$text',
  flashcardId: card,
  packId: pack,
  side: HighlightSide.answer,
  text: text,
  start: 0,
  question: 'Q $card',
  createdAt: DateTime(2026, 11, day),
  kind: kind,
);

Flashcard _card(String id, String pack, List<String> tags) => Flashcard(
  id: id,
  packId: pack,
  question: 'What about {$id}?',
  answer: 'A',
  tags: tags.map(Tag.fromId).toList(),
);

void main() {
  // Newest first, like the repository.
  final highlights = [
    _mark('c3', 'Kussmaul breathing', pack: 'p2', day: 4),
    _mark('c1', 'not in the PDF', kind: HighlightKind.underline, day: 3),
    _mark('c1', 'calcium channel blockers', day: 2),
    _mark('c1', 'Beta blockers', day: 1),
  ];
  final cards = {
    'c1': _card('c1', 'p1', ['topic--cardiology', '2025']),
    'c3': _card('c3', 'p2', ['topic--endocrine']),
  };
  const names = {'p1': 'Neonatology', 'p2': 'Endocrine'};

  test('all highlights, by pack, oldest first, no underlines', () {
    final sections = highlightSectionsForExport(
      highlights: highlights,
      cards: cards,
      packNames: names,
    );
    expect(sections.map((s) => s.title), ['Endocrine', 'Neonatology']);
    final neo = sections[1].cards.single;
    expect(neo.question, 'What about c1?');
    expect(neo.passages, ['Beta blockers', 'calcium channel blockers']);
  });

  test('only some packs, or cards with some tags', () {
    expect(
      highlightSectionsForExport(
        highlights: highlights,
        cards: cards,
        packNames: names,
        packIds: {'p2'},
      ).single.title,
      'Endocrine',
    );
    final byTopic = highlightSectionsForExport(
      highlights: highlights,
      cards: cards,
      packNames: names,
      tagIds: {'topic--cardiology'},
    );
    expect(byTopic.single.title, 'Neonatology');
    expect(byTopic.single.cards.single.passages, hasLength(2));
  });

  test('the PDF is made', () async {
    final service = PdfExportService(theme: pw.ThemeData.base());
    final bytes = await service.generateHighlightsPdf(
      filterLabel: 'All highlights',
      sections: highlightSectionsForExport(
        highlights: highlights,
        cards: cards,
        packNames: names,
      ),
      date: DateTime(2026, 11, 4),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final out = Platform.environment['HIGHLIGHTS_PDF_OUT'];
    if (out != null) File(out).writeAsBytesSync(bytes);
  });

  testWidgets('choose a topic, then Make PDF', (tester) async {
    String? label;
    List<HighlightPdfSection>? exported;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FlashcardRepository>.value(value: _Cards(cards)),
          Provider<PackRepository>.value(value: _Packs(names)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ExportHighlightsSheet(
              highlights: highlights,
              onExport: (l, sections) async {
                label = l;
                exported = sections;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('All 3 highlights, grouped by pack.'), findsOneWidget);

    await tester.tap(find.text('By tag'));
    await tester.pumpAndSettle();
    expect(find.text('Topic: Cardiology'), findsOneWidget);
    // Nothing chosen yet.
    final button = find.widgetWithText(FilledButton, 'Make PDF');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.text('Topic: Cardiology'));
    await tester.pump();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(label, 'Tags: Topic: Cardiology');
    expect(exported!.single.title, 'Neonatology');
  });

  test('the PDF uses the fonts built into the app', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final service = await PdfExportService.create(text: 'No Arabic here');
    final bytes = await service.generateHighlightsPdf(
      filterLabel: 'All highlights',
      sections: highlightSectionsForExport(
        highlights: highlights,
        cards: cards,
        packNames: names,
      ),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(String.fromCharCodes(bytes), contains('Roboto'));
  });
}
