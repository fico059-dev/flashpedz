// Image occlusion cards, and pictures of them:
// flutter test test/image_occlusion_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/ui/pages/profile/admin_dashboard/flashcard_builder/image_occlusion_page.dart';
import 'package:flashcards/ui/widgets/flashcard/card_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _masks = [
  OcclusionMask(0.1, 0.1, 0.3, 0.15),
  OcclusionMask(0.55, 0.4, 0.3, 0.15),
  OcclusionMask(0.2, 0.7, 0.4, 0.12),
];

Future<void> _save(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/screens')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  test('an occlusion card line is read back with its boxes', () {
    final question = [
      'What is hidden?',
      occlusionLine(url: 'https://x.org/heart.jpg', masks: _masks, target: 1),
    ].join('\n');
    expect(hasCardMarkup(question), isTrue);
    final blocks = parseCardMarkup(question);
    expect(blocks.first, isA<TextBlock>());
    final block = blocks.last as OcclusionBlock;
    expect(block.url, 'https://x.org/heart.jpg');
    expect(block.masks, _masks);
    expect(block.target, 1);
    expect(block.revealed, isFalse);

    final answer = occlusionLine(
      url: 'https://x.org/heart.jpg',
      masks: _masks,
      target: 1,
      revealed: true,
    );
    expect((parseCardMarkup(answer).single as OcclusionBlock).revealed, isTrue);
    expect(plainCardText(answer), '[image occlusion]');
    // Square brackets: cloze {braces} never touch it.
    expect(answer.contains('{'), isFalse);
  });

  testWidgets('question and answer pictures', (tester) async {
    tester.view.physicalSize = const Size(700, 320);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    Widget card(bool revealed) => Container(
      width: 320,
      height: 240,
      color: const Color(0xFFFFF8E1),
      child: CustomPaint(
        painter: OcclusionPainter(
          OcclusionBlock(
            url: 'https://x.org/heart.jpg',
            masks: _masks,
            target: 1,
            revealed: revealed,
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: Material(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [card(false), card(true)],
            ),
          ),
        ),
      ),
    );
    await _save(tester, key, 'occlusion_question_answer');
  });

  testWidgets('drawing boxes in the editor', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bytes = File('assets/images/happy_parrot.png').readAsBytesSync();
    final size = (await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    }))!;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: ImageOcclusionPage(
            pack: const AdminPack(
              packId: 'p',
              packName: 'Anatomy',
              flashcardsCount: 0,
              isPaid: false,
            ),
            initialImage: (bytes, size),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        MemoryImage(bytes),
        tester.element(find.byType(ImageOcclusionPage)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Draw at least one box'), findsOneWidget);

    final area = tester.getRect(find.byType(Image));
    Future<void> drag(Offset from, Offset to) async {
      final gesture = await tester.startGesture(area.topLeft + from);
      for (var step = 1; step <= 10; step++) {
        await gesture.moveTo(area.topLeft + Offset.lerp(from, to, step / 10)!);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await drag(const Offset(30, 30), const Offset(150, 90));
    await drag(const Offset(160, 160), const Offset(300, 220));
    expect(find.text('2 boxes'), findsOneWidget);
    expect(find.text('Make 2 cards'), findsOneWidget);

    // A tiny drag is not a box.
    await drag(const Offset(10, 300), const Offset(12, 302));
    expect(find.text('2 boxes'), findsOneWidget);

    await _save(tester, key, 'occlusion_editor');

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('1 box'), findsOneWidget);
  });
}
