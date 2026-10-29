import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flashcards/ui/widgets/editor/rich_card_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'clicking a table cell puts the cursor in that cell',
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = TextEditingController(
        text: 'Hello\n| a | b |\n|---|---|\n| c | d |\n| e | f |\nAfter',
      );
      final key = GlobalKey<RichCardEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
          home: Scaffold(
            body: RichCardEditor(key: key, controller: controller, label: 'A'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = key.currentState!.editorState;
      final table = editor.document.root.children[1];
      for (final cell in table.children) {
        final rect = cell.rect;
        await tester.tapAt(rect.center);
        await tester.pumpAndSettle(const Duration(milliseconds: 600));
        expect(editor.selection?.start.path, [...cell.path, 0]);
      }
    },
  );

  testWidgets(
    'cells of a table inserted from the toolbar can be clicked',
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = TextEditingController(text: 'Hello world');
      final key = GlobalKey<RichCardEditorState>();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                RichCardEditor(key: key, controller: controller, label: 'A'),
                const SizedBox(height: 600),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = key.currentState!.editorState;
      editor.selection = Selection.collapsed(Position(path: [0], offset: 11));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insert table…'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      final table = editor.document.root.children[1];
      for (final cell in table.children) {
        await tester.tapAt(cell.rect.center);
        await tester.pumpAndSettle(const Duration(milliseconds: 600));
        expect(editor.selection?.start.path, [...cell.path, 0]);
      }
    },
  );

  testWidgets('rows and columns are added and removed from the Table menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = TextEditingController(
      text: '| Drug | Dose |\n|------|------|\n| Amox | 50 |',
    );
    final key = GlobalKey<RichCardEditorState>();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
        home: Scaffold(
          body: RichCardEditor(key: key, controller: controller, label: 'A'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = key.currentState!.editorState;

    Future<void> menu(String item) async {
      await tester.tap(find.byTooltip('Table'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    // In "Amox" (row 2, column 1).
    final table = editor.document.root.children[0];
    final amox = table.children[2];
    await tester.tapAt(amox.rect.center);
    await tester.pumpAndSettle();

    await menu('Row below');
    expect(
      controller.text,
      '| Drug | Dose |\n|------|------|\n| Amox | 50 |\n|   |   |',
    );
    await menu('Column right');
    expect(controller.text.split('\n').first, '| Drug |   | Dose |');
    await menu('Delete column');
    expect(controller.text.split('\n').first, '| Drug | Dose |');
    await menu('Delete row');
    expect(controller.text, '| Drug | Dose |\n|------|------|\n| Amox | 50 |');
    await menu('Header row on/off');
    expect(controller.text, '| Drug | Dose |\n| Amox | 50 |');
    await menu('Delete table');
    expect(controller.text, '');
  });
}
