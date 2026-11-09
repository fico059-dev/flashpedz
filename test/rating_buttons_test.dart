// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashcards/bloc/flashcards/flashcard/flashcard_bloc.dart';
import 'package:flashcards/bloc/flashcards/flashcard/flashcard_event.dart';
import 'package:flashcards/bloc/flashcards/flashcard/flashcard_state.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_cubit.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_state.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pp_repository.dart';
import 'package:flashcards/data/repositories/users/auth_repository.dart';
import 'package:flashcards/data/repositories/users/profile_repository.dart';
import 'package:flashcards/data/services/local/local_storage_service.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/stat_record/stat_record.dart';
import 'package:flashcards/domain/models/profile/education_level.dart';
import 'package:flashcards/domain/models/profile/profile.dart';
import 'package:flashcards/domain/models/profile/profile_settings/profile_settings.dart';
import 'package:flashcards/domain/models/profile/streak/streak.dart';
import 'package:flashcards/l10n/app_localizations.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/rating_buttons/flashcard_rating_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

class _Fake implements FlashcardRepository, FcpRepository, PpRepository,
    ProfileRepository, LocalStorageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  @override
  String get uid => 'u1';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements AuthRepository {
  @override
  User? getCurrentUser() => _User();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}


StatRecord _record(String id) => StatRecord(
  packId: 'p',
  flashcardId: id,
  isPaid: false,
  card: fsrs.Card(),
  flashcard: Flashcard(
    id: id,
    packId: 'p',
    question: 'Q $id',
    answer: 'A $id',
    tags: const [],
  ),
);

void main() {
  testWidgets('rating buttons work again on the next card', (tester) async {
    // Saving isn't available here; it runs in the background and its
    // failures don't stop the review.
    final bloc = FlashcardBloc(
      flashcardRepo: _Fake(),
      fcpRepo: _Fake(),
      authRepo: _Auth(),
      profileRepo: _Fake(),
      ppRepo: _Fake(),
      localStorageService: _Fake(),
    );
    final profile = ProfileReaderCubit(profileRepo: _Fake())
      ..emit(
        ProfileReaderState.isLoaded(
          profile: Profile(
            name: 'A',
            surname: 'B',
            username: 'ab',
            email: 'a@b.c',
            phoneNumber: '',
            educationLevel: EducationLevel.values.first,
            streak: Streak(count: 0, lastStreakDate: DateTime(2026)),
            profileSettings: const ProfileSettings(),
          ),
        ),
      );
    final records = [_record('c1'), _record('c2')];
    bloc.emit(
      FlashcardState(
        status: FlashcardStatus.loaded,
        statRecords: records,
        flashcard: records[0].flashcard,
        answerVisible: true,
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FlashcardBloc>.value(value: bloc),
          BlocProvider.value(value: profile),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FlashcardRatingButtons()),
        ),
      ),
    );

    await tester.tap(find.text('Hard'));
    await tester.pump();
    // The next card is shown right away, without a loading step.
    expect(bloc.state.currentCardIndex, 1);
    expect(bloc.state.status, FlashcardStatus.loaded);
    expect(bloc.state.statRecords[0].card.reps, 1);

    bloc.emit(bloc.state.copyWith(answerVisible: true));
    await tester.pump();

    // Before the fix the buttons stayed locked here.
    await tester.tap(find.text('Good'));
    await tester.pump();
    expect(bloc.state.status, FlashcardStatus.sessionEnded);
    expect(bloc.state.statRecords[1].card.reps, 1);

    // Let the background saves finish.
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('undo shows the last card again with its old progress', (
    tester,
  ) async {
    final bloc = FlashcardBloc(
      flashcardRepo: _Fake(),
      fcpRepo: _Fake(),
      authRepo: _Auth(),
      profileRepo: _Fake(),
      ppRepo: _Fake(),
      localStorageService: _Fake(),
    );
    final records = [_record('c1'), _record('c2'), _record('c3')];
    bloc.emit(
      FlashcardState(
        status: FlashcardStatus.loaded,
        statRecords: records,
        flashcard: records[0].flashcard,
        answerVisible: true,
      ),
    );
    final streak = Streak(count: 0, lastStreakDate: DateTime(2026));
    expect(bloc.canUndo, isFalse);

    bloc.add(FlashcardRatingGiven(rating: fsrs.Rating.good, userStreak: streak));
    await tester.pump(const Duration(milliseconds: 10));
    expect(bloc.state.currentCardIndex, 1);
    expect(bloc.state.statRecords[0].card.reps, 1);
    expect(bloc.canUndo, isTrue);
    // The score at the top: one right.
    expect((bloc.score.correct, bloc.score.wrong), (1, 0));

    bloc.add(FlashcardUndoPressed());
    await tester.pump(const Duration(milliseconds: 10));
    expect((bloc.score.correct, bloc.score.wrong), (0, 0));
    expect(bloc.state.currentCardIndex, 0);
    expect(bloc.state.flashcard?.id, 'c1');
    expect(bloc.state.answerVisible, isFalse);
    expect(bloc.state.statRecords[0].card.reps, 0);
    expect(bloc.canUndo, isFalse);
    await tester.pump(const Duration(milliseconds: 10));
  });
}
