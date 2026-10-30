import 'package:flashcards/ui/widgets/tutorial/tutorial_page_template.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tutorials can be left from every slide but the last', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TutorialPageTemplate(
          slides: [
            TutorialSlide(title: 'One', description: 'First'),
            TutorialSlide(title: 'Two', description: 'Last'),
          ],
        ),
      ),
    );
    expect(find.text('Exit'), findsOneWidget);
    expect(find.text('Exit tutorial'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    // The last slide has Finish, and Exit at the top.
    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('Exit tutorial'), findsNothing);
    expect(find.text('Exit'), findsOneWidget);
  });
}
