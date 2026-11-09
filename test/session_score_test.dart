import 'package:flashcards/bloc/flashcards/session_score/session_score.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'package:flashcards/ui/widgets/flashcard/session_score_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('answers are counted and undo takes one back', () {
    final score = SessionScore();
    var changes = 0;
    score.addListener(() => changes++);
    score
      ..add(correct: true)
      ..add(correct: true)
      ..add(correct: false);
    expect((score.correct, score.wrong), (2, 1));
    score.remove(correct: false);
    expect((score.correct, score.wrong), (2, 0));
    score.remove(correct: false);
    expect(score.wrong, 0);
    expect(changes, 5);
  });

  for (final width in [320.0, 800.0]) {
    testWidgets('shows right, wrong and the share (width $width)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: lightThemeData,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SessionScoreBar(correct: 128, wrong: 32),
            ),
          ),
        ),
      );
      expect(find.text(width < 400 ? '128' : '128 correct'), findsOneWidget);
      expect(find.text(width < 400 ? '32' : '32 wrong'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('before any answer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightThemeData,
        home: const Scaffold(
          body: SizedBox(
            width: 600,
            child: SessionScoreBar(correct: 0, wrong: 0),
          ),
        ),
      ),
    );
    expect(find.text('0 correct'), findsOneWidget);
    expect(find.text('0 wrong'), findsOneWidget);
  });
}
