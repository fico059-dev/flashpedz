import 'package:flashcards/bloc/osces/osce/osce_bloc.dart';
import 'package:flashcards/bloc/osces/osce/osce_event.dart';
import 'package:flashcards/bloc/osces/osce/osce_state.dart';
import 'package:flashcards/data/repositories/osces/osce_repository.dart';
import 'package:flashcards/data/services/local/local_storage_service.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/domain/models/osce/osce.dart';
import 'package:flashcards/domain/models/osce/question/check/check.dart';
import 'package:flashcards/domain/models/osce/question/question.dart';
import 'package:flashcards/l10n/app_localizations.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/main_card/widgets/question_text.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/rating_buttons/rating_segments.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/rating_buttons/score_segmented_button.dart';
import 'package:flashcards/ui/widgets/osce/osce_checklist_review.dart';
import 'package:flashcards/ui/widgets/osce/osce_mode_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

class _FakeOsceRepository implements OsceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeLocalStorage implements LocalStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

Check _check(int i, String text, {bool title = false}) =>
    Check(text: text, isTitle: title, isChecked: false, index: i);

final _osce = Osce(
  id: 'o',
  name: 'Chest pain',
  scenario: '',
  questions: [
    Question(
      id: 'q1',
      index: 0,
      text: 'Take a history',
      checks: [
        _check(0, 'History', title: true),
        _check(1, 'Asks about onset'),
        _check(2, 'Asks about radiation'),
      ],
    ),
    Question(
      id: 'q2',
      index: 1,
      text: 'Examine the patient',
      checks: [_check(0, 'Checks pulse')],
    ),
  ],
);

void main() {
  testWidgets('rating buttons show when the card will be due again', (
    tester,
  ) async {
    late List<ScoreSegment<fsrs.Rating>> segments;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            segments = buildRatingSegments(context, fsrs.Card());
            return const SizedBox();
          },
        ),
      ),
    );

    final times = {for (final s in segments) s.value: s.time};
    expect(times.keys, [
      fsrs.Rating.easy,
      fsrs.Rating.good,
      fsrs.Rating.hard,
      fsrs.Rating.again,
    ]);
    // A new card: again/hard/good are short (minutes), easy is days.
    expect(times[fsrs.Rating.again], endsWith('m'));
    expect(times[fsrs.Rating.easy], endsWith('d'));
  });

  testWidgets('question shows tags and can be selected for copying', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        QuestionText(
          question: 'Most common arrhythmia?',
          tags: [Tag.fromName('Cardiology'), Tag.fromName('Arrhythmia')],
        ),
      ),
    );

    expect(find.text('Cardiology'), findsOneWidget);
    expect(find.text('Arrhythmia'), findsOneWidget);
    expect(
      find.widgetWithText(SelectableText, 'Most common arrhythmia?'),
      findsOneWidget,
    );
  });

  testWidgets('OSCE checklist appears at the end and ticks any question', (
    tester,
  ) async {
    final bloc = OsceBloc(
      osceRepo: _FakeOsceRepository(),
      localStorageService: _FakeLocalStorage(),
    )..emit(OsceLoaded(osce: _osce));

    bloc.add(OsceChecklistOpened());
    await tester.pump();
    expect((bloc.state as OsceLoaded).reviewingChecklist, isTrue);

    await tester.pumpWidget(
      BlocProvider.value(value: bloc, child: _app(const OsceChecklistReview())),
    );
    expect(find.text('1. Take a history'), findsOneWidget);
    expect(find.text('2. Examine the patient'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(3));

    // Tick a check of the second question while on the checklist.
    await tester.tap(find.text('Checks pulse'));
    await tester.pumpAndSettle();
    final questions = (bloc.state as OsceLoaded).osce.questions;
    expect(questions[1].checks[0].isChecked, isTrue);
    expect(questions[0].checks.any((c) => c.isChecked), isFalse);

    await tester.tap(find.text('Back to questions'));
    await tester.pump();
    expect((bloc.state as OsceLoaded).reviewingChecklist, isFalse);
  });

  testWidgets('Study mode shows each answer at once, Exam mode at the end', (
    tester,
  ) async {
    final bloc = OsceBloc(
      osceRepo: _FakeOsceRepository(),
      localStorageService: _FakeLocalStorage(),
    )..emit(OsceLoaded(osce: _osce));

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: _app(
          const Column(
            children: [
              OsceModeSwitch(),
              Expanded(
                child: SingleChildScrollView(child: OsceLearningAnswer()),
              ),
            ],
          ),
        ),
      ),
    );
    // Exam mode: no answers while answering.
    expect(find.text('Asks about onset'), findsNothing);

    await tester.tap(find.text('Study'));
    await tester.pumpAndSettle();
    expect((bloc.state as OsceLoaded).mode, OsceMode.learning);
    // The checklist shows straight away and can be ticked.
    expect(find.text('Asks about onset'), findsOneWidget);
    await tester.tap(find.text('Asks about onset'));
    await tester.pumpAndSettle();
    expect(
      (bloc.state as OsceLoaded).osce.questions[0].checks[1].isChecked,
      isTrue,
    );

    // The next question shows its own checklist.
    bloc.add(NextQuestionRequested());
    await tester.pumpAndSettle();
    expect(find.text('Checks pulse'), findsOneWidget);
    expect(find.text('Asks about onset'), findsNothing);

    // Back to Exam mode hides the answers.
    await tester.tap(find.text('Exam'));
    await tester.pumpAndSettle();
    expect(find.text('Checks pulse'), findsNothing);
  });
}
