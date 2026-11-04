import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/ui/widgets/flashcard/picture_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pictures below the top of the card', () {
    const card = Flashcard(
      id: 'c',
      packId: 'p',
      question: 'Rash?\n![image](https://x.com/q.jpg)',
      answer: 'Measles\n[occlusion](https://x.com/o.jpg)[0,0,1,1]#0!',
      questionImageUrl: 'https://x.com/top.jpg',
      answerImageUrl: 'https://x.com/a.jpg',
      tags: [],
    );
    expect(cardPictureUrls(card, answerShown: false), ['https://x.com/q.jpg']);
    expect(cardPictureUrls(card, answerShown: true), [
      'https://x.com/q.jpg',
      'https://x.com/a.jpg',
      'https://x.com/o.jpg',
    ]);
  });

  testWidgets('a picture further down shows a button that scrolls to it', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PictureHint(
            pictureUrls: const ['https://example.com/a.jpg'],
            controller: controller,
            child: SingleChildScrollView(
              controller: controller,
              child: const SizedBox(height: 3000),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });

  testWidgets('no button without pictures', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PictureHint(
            pictureUrls: const [],
            controller: controller,
            child: SingleChildScrollView(
              controller: controller,
              child: const SizedBox(height: 3000),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.arrow_downward), findsNothing);
  });
}
