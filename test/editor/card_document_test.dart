import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flashcards/ui/widgets/editor/card_document.dart';
import 'package:flutter_test/flutter_test.dart';

String roundTrip(String text) => documentToMarkup(markupToDocument(text));

void main() {
  test('card text comes back unchanged from the editor', () {
    for (final text in [
      'Plain question?',
      'First line\n\nAfter an empty line',
      'Give **vitamin K** and __watch__ the [size=22]baby[/size]',
      '[i]italic[/i], [s]gone[/s], H[sub]2[/sub]O, x[sup]2[/sup]',
      '[color=#D32F2F]red[/color] and [bg=#FFF59D]highlighted[/bg]',
      '• Sepsis\n• Hypoxia\n\n1. Airway\n2. Breathing',
      'Intro\n3. Third point',
      '[h1] Title\n[quote] A quote\n[center] Middle\n[right] Right\n[hr]',
      '| Drug | Dose |\n|------|------|\n| **Amox** | 50 mg/kg |',
      '| a | b |\n| c | d |',
      '![image](https://x.org/a.png)',
      '[occlusion](https://x.org/h.jpg)[0.1000,0.1000,0.2000,0.2000]#0',
      'Cloze {kept} as typed',
    ]) {
      expect(roundTrip(text), text, reason: text);
    }
  });

  test('editor formatting becomes card codes', () {
    final delta = Delta()
      ..insert('Bold ', attributes: {'bold': true})
      ..insert('and ')
      ..insert('red', attributes: {'font_color': '0xFFD32F2F', 'italic': true});
    expect(
      deltaToInline(delta),
      '**Bold** and [color=#D32F2F][i]red[/i][/color]',
    );
  });

  test('a new table has a header row and empty cells', () {
    final doc = Document(root: pageNode(children: [emptyTableNode(2, 3)]));
    expect(
      documentToMarkup(doc),
      '|   |   |   |\n|------|------|------|\n|   |   |   |',
    );
  });
}
