import 'package:flashcards/ui/widgets/flashcard/card_content.dart';
import 'package:flashcards/ui/widgets/profile/admin_dashboard/flashcard_builder/card_format_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toolbar edits', () {
    test('bold wraps the selected words', () {
      final c = TextEditingController(text: 'Give vitamin K at birth');
      c.selection = const TextSelection(baseOffset: 5, extentOffset: 14);
      wrapSelection(c, '**', '**');
      expect(c.text, 'Give **vitamin K** at birth');
      expect(c.selection.textInside(c.text), 'vitamin K');
    });

    test('with nothing selected, the cursor goes between the codes', () {
      final c = TextEditingController(text: 'abc');
      c.selection = const TextSelection.collapsed(offset: 3);
      wrapSelection(c, '[size=22]', '[/size]');
      expect(c.text, 'abc[size=22][/size]');
      expect(c.selection.baseOffset, 'abc[size=22]'.length);
    });

    test('tables and images go on their own lines', () {
      final c = TextEditingController(text: 'Before after');
      c.selection = const TextSelection.collapsed(offset: 6);
      insertBlock(c, '![image](https://a.com/x.jpg)');
      expect(c.text, 'Before\n![image](https://a.com/x.jpg)\nafter');
    });
  });

  testWidgets('a formatted card shows its table and every image', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CardContent(
              'Which **drug**?\n'
              '![a](https://a.com/1.jpg)\n'
              '![b](https://a.com/2.jpg)\n'
              '| Drug | Dose |\n|---|---|\n| Amox | 50 |',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Table), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(2));
    expect(find.text('Amox', findRichText: true), findsOneWidget);
  });

  testWidgets('plain cards render as before (one text, no table)', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: CardContent('Cause of ______ ?'))),
    );
    expect(find.byType(Table), findsNothing);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  group('lists', () {
    test('bullets the selected lines, then removes them again', () {
      final c = TextEditingController(text: 'Causes:\nSepsis\nHypoxia\nEnd');
      c.selection = const TextSelection(baseOffset: 9, extentOffset: 20);
      toggleList(c, numbered: false);
      expect(c.text, 'Causes:\n• Sepsis\n• Hypoxia\nEnd');
      c.selection = const TextSelection(baseOffset: 9, extentOffset: 22);
      toggleList(c, numbered: false);
      expect(c.text, 'Causes:\nSepsis\nHypoxia\nEnd');
    });

    test('numbers lines in order and replaces bullets', () {
      final c = TextEditingController(
        text: '• Airway\n• Breathing\n\nCirculation',
      );
      c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
      toggleList(c, numbered: true);
      expect(c.text, '1. Airway\n2. Breathing\n\n3. Circulation');
    });

    test('with no selection, the cursor line becomes a list item', () {
      final c = TextEditingController(text: 'First\nSecond');
      c.selection = const TextSelection.collapsed(offset: 8);
      toggleList(c, numbered: false);
      expect(c.text, 'First\n• Second');
    });
  });

  testWidgets('the preview shows a table while it is being written', (
    tester,
  ) async {
    final c = TextEditingController(text: 'Plain text');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: CardMarkupPreview(controller: c)),
        ),
      ),
    );
    expect(find.text('Preview'), findsNothing);

    c.text = '| Drug | Dose |\n|---|---|\n| Amox | 50 mg/kg |';
    await tester.pump();
    expect(find.text('Preview'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.textContaining('Amox'), findsOneWidget);

    c.text = '• one\n• two';
    await tester.pump();
    expect(find.text('Preview'), findsOneWidget);
  });
}
