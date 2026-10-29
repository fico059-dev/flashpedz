// The rich card editor; also renders it to build/screens/rich_editor.png.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'package:flashcards/ui/widgets/editor/rich_card_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
      '/bin/cache/artifacts/material_fonts/$file',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  testWidgets('formats text, inserts tables and keeps the card text', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await _loadFont('Roboto', [
        'Roboto-Regular.ttf',
        'Roboto-Medium.ttf',
        'Roboto-Bold.ttf',
      ]);
      await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
    });
    tester.view.physicalSize = const Size(900, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = TextEditingController(
      text:
          '[h2] Pertussis\n'
          'Risk factors for **death**:\n'
          '• Age under [color=#D32F2F]4 weeks[/color]\n'
          '• Prematurity\n'
          '| Vaccine | Timing |\n|------|------|\n| Tdap | 27–36 weeks |',
    );
    final key = GlobalKey<RichCardEditorState>();
    final shot = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: lightThemeData,
        localizationsDelegates: const [AppFlowyEditorLocalizations.delegate],
        home: Scaffold(
          body: RepaintBoundary(
            key: shot,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RichCardEditor(
                key: key,
                controller: controller,
                label: 'Answer',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Pertussis', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Tdap', findRichText: true), findsOneWidget);

    await tester.runAsync(() async {
      final boundary =
          shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/screens').createSync(recursive: true);
      File(
        'build/screens/rich_editor.png',
      ).writeAsBytesSync(data!.buffer.asUint8List());
    });

    // Select "Risk factors" and make it italic with the toolbar.
    final editor = key.currentState!.editorState;
    final line = editor.document.root.children[1];
    editor.selection = Selection(
      start: Position(path: line.path, offset: 0),
      end: Position(path: line.path, offset: 12),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Italic'));
    await tester.pumpAndSettle();
    expect(controller.text, contains('[i]Risk factors[/i] for **death**:'));

    // Strikethrough and superscript too.
    await tester.tap(find.byTooltip('Strikethrough'));
    await tester.pumpAndSettle();
    expect(controller.text, contains('[i][s]Risk factors[/s][/i]'));

    // Make the line a numbered list item.
    await tester.tap(find.byTooltip('Numbered list'));
    await tester.pumpAndSettle();
    expect(controller.text, contains('\n1. [i][s]Risk factors'));

    // Insert a 2 × 3 table from the grid.
    await tester.tap(find.byTooltip('Table'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insert table…'));
    await tester.pumpAndSettle();
    expect(find.text('Insert table'), findsOneWidget);
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();
    expect(
      RegExp(r'^\|.*\|$', multiLine: true).allMatches(controller.text).length,
      // The old table (2 rows + header line), the new one (3 rows + header
      // line).
      7,
    );

    // Editing the card as code updates the editor afterwards.
    await tester.tap(find.byTooltip('Edit as code'));
    await tester.pumpAndSettle();
    controller.text = 'Just **one** line';
    await tester.tap(find.byTooltip('Back to the editor'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Just one line', findRichText: true),
      findsOneWidget,
    );
  });
}
