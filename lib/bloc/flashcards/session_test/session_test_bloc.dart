import 'dart:async';

import 'package:flashcards/bloc/flashcards/session_test/session_test_event.dart';
import 'package:flashcards/bloc/flashcards/session_test/session_test_state.dart';
import 'package:flashcards/data/repositories/flashcards/custom_session_repository.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/data/repositories/users/profile_repository.dart';
import 'package:flashcards/data/services/local/daily_target.dart';
import 'package:flashcards/data/services/local/session_progress_store.dart';
import 'package:flashcards/data/services/api/exceptions/document_doesnt_exist_exception.dart';
import 'package:flashcards/domain/models/flashcards/custom_session/custom_session.dart';
import 'package:flashcards/domain/models/flashcards/stat_record/stat_record.dart';
import 'package:flashcards/domain/models/profile/streak/streak.dart';
import 'package:flashcards/utils/background_save.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs/fsrs.dart';

class SessionTestBloc extends Bloc<SessionTestEvent, SessionTestState> {
  final CustomSessionRepository _sessionRepo;
  final FcpRepository _fcpRepo;
  final ProfileRepository _profileRepo;
  final SessionProgressStore? _sessionProgress;
  final DailyTargetService? _dailyTarget;

  SessionTestBloc({
    required CustomSessionRepository sessionRepo,
    required FcpRepository fcpRepo,
    required ProfileRepository profileRepo,
    SessionProgressStore? sessionProgress,
    DailyTargetService? dailyTarget,
  }) : _sessionRepo = sessionRepo,
       _fcpRepo = fcpRepo,
       _profileRepo = profileRepo,
       _sessionProgress = sessionProgress,
       _dailyTarget = dailyTarget,
       super(SessionTestInitial()) {
    on<SessionTestDataLoaded>(_onLoaded);
    on<SessionTestNextPressed>(_onNextPressed);
    on<SessionTestBookmarkToggled>(_onBookmarkToggled);
    on<SessionTestAnswerShown>(_onAnswerShown);
    on<SessionTestCardEdited>(_onCardEdited);
    on<SessionTestStreakChanged>((event, emit) {
      final state = this.state;
      if (state is SessionTestLoaded) {
        emit(state.copyWith(newStreak: event.streak));
      }
    });
  }

  /// Saves progress without making the student wait for the server.
  final _saver = BackgroundSaver();

  /// Saves that failed, shown to the student without stopping the session.
  Stream<Exception> get saveErrors => _saver.errors;

  /// Upcoming cards, downloaded while the current one is studied.
  final _prefetched = <String, Future<Result<StatRecord>>>{};
  final _readyRecords = <String, StatRecord>{};
  static const _prefetchCount = 3;

  /// Image URLs of downloaded upcoming cards, so the page can load the
  /// pictures before they are shown.
  final _upcomingImages = StreamController<String>.broadcast();
  Stream<String> get upcomingImages => _upcomingImages.stream;

  Future<Result<StatRecord>> _getRecord(String flashcardId) {
    final future = _prefetched.putIfAbsent(
      flashcardId,
      () => _fcpRepo
          .getStatRecordForFlashcardId(flashcardId)
          .withReadTimeout()
          .then((result) {
            if (result case Ok(:final value)) {
              _readyRecords[flashcardId] = value;
              final flashcard = value.flashcard;
              for (final url in [
                flashcard?.questionImageUrl,
                flashcard?.answerImageUrl,
              ]) {
                if (url != null &&
                    url.isNotEmpty &&
                    !_upcomingImages.isClosed) {
                  _upcomingImages.add(url);
                }
              }
            } else {
              // A failed download is tried again next time.
              _prefetched.remove(flashcardId);
            }
            return result;
          }),
    );
    return future;
  }

  /// Starts downloading the cards after [index].
  void _prefetchAfter(CustomSession session, int index) {
    final ids = session.flashcardIds;
    for (
      var i = index + 1;
      i < ids.length && i <= index + _prefetchCount;
      i++
    ) {
      _getRecord(ids[i]);
    }
    // Records of cards already studied aren't needed any more.
    for (var i = 0; i < index && i < ids.length; i++) {
      _prefetched.remove(ids[i]);
      _readyRecords.remove(ids[i]);
    }
  }

  void _updateStreakInBackground(Future<Result<Streak?>> Function() update) {
    _saver.run('streak', () async {
      final result = await update();
      switch (result) {
        case Error<Streak?>(:final error):
          return Result.error(error);
        case Ok<Streak?>(:final value):
          if (value != null && !isClosed) add(SessionTestStreakChanged(value));
          return Result.ok(null);
      }
    });
  }

  @override
  Future<void> close() {
    _saver.dispose();
    _upcomingImages.close();
    return super.close();
  }

  void _onCardEdited(
    SessionTestCardEdited event,
    Emitter<SessionTestState> emit,
  ) {
    final state = this.state;
    if (state is! SessionTestLoaded ||
        state.statRecord.flashcardId != event.flashcard.id) {
      return;
    }
    final edited = event.flashcard;
    _readyRecords.remove(edited.id);
    _prefetched.remove(edited.id);
    emit(
      state.copyWith(
        unformattedQuestion: edited.question,
        statRecord: state.statRecord.copyWith(
          flashcard: edited.copyWith(
            question: state.answerShown
                ? revealClozeQuestion(edited.question)
                : redactClozeQuestion(edited.question),
          ),
        ),
      ),
    );
  }

  void _onAnswerShown(
    SessionTestAnswerShown event,
    Emitter<SessionTestState> emit,
  ) {
    final state = this.state;
    if (state is! SessionTestLoaded) return;
    if (state.status.isLoading) return;

    // format cloze question, if cloze is present
    final updatedFlashcard = state.statRecord.flashcard!.copyWith(
      question: revealClozeQuestion(state.unformattedQuestion),
    );
    //print(updatedFlashcard.question);
    emit(
      state.copyWith(
        answerShown: true,
        statRecord: state.statRecord.copyWith(flashcard: updatedFlashcard),
      ),
    );
  }

  void _onLoaded(
    SessionTestDataLoaded event,
    Emitter<SessionTestState> emit,
  ) async {
    if (state is! SessionTestInitial && state is! SessionTestError) return;

    emit(SessionTestLoading());

    final sessionResult = await _sessionRepo
        .getCustomSessionFlashcardIds(sessionSummary: event.sessionSummary)
        .withReadTimeout();
    switch (sessionResult) {
      case Error<CustomSession>(:final error):
        emit(SessionTestError(error));
        return;
      case Ok<CustomSession>():
    }
    final customSession = sessionResult.value;
    if (customSession.isFinished) {
      emit(
        SessionTestLoaded(
          unformattedQuestion: "",
          status: SessionTestStatus.finished,
          session: customSession,
          statRecord: StatRecord.empty(),
        ),
      );
      return;
    }

    final recordResult = await _getRecord(customSession.currentFlashcardId);
    _prefetchAfter(customSession, customSession.currentIndex);
    switch (recordResult) {
      case Error<StatRecord>(:final error):
        if (error is DocumentDoesntExistException) {
          emit(
            SessionTestLoaded(
              unformattedQuestion: "",
              status: SessionTestStatus.noFlashcard,
              session: customSession,
              statRecord: StatRecord.empty(),
            ),
          );
          return;
        }
        emit(SessionTestError(error));
        return;
      case Ok<StatRecord>():
    }
    final statRecord = recordResult.value;
    final unformattedQuestion = statRecord.flashcard!.question;
    final recordWithCloze = statRecord.copyWith(
      flashcard: statRecord.flashcard!.copyWith(
        question: redactClozeQuestion(unformattedQuestion),
      ),
    );

    // print(customSession.correctCount);
    emit(
      SessionTestLoaded(
        session: customSession,
        statRecord: recordWithCloze,
        unformattedQuestion: unformattedQuestion,
      ),
    );

    // start counting
    _updateStreakInBackground(
      () => _profileRepo.checkAndStartStreak(event.userStreak),
    );
  }

  /// True while moving to the next card, so a quick double tap doesn't
  /// answer the same card twice.
  bool _advancing = false;

  void _onNextPressed(
    SessionTestNextPressed event,
    Emitter<SessionTestState> emit,
  ) async {
    if (_advancing) return;
    _advancing = true;
    try {
      await _next(event, emit);
    } finally {
      _advancing = false;
    }
  }

  Future<void> _next(
    SessionTestNextPressed event,
    Emitter<SessionTestState> emit,
  ) async {
    final state = this.state;
    if (state is! SessionTestLoaded ||
        state.status.isLoading ||
        state.status.isBookmarkLoading) {
      return;
    }
    // Ratings are only offered once the answer is shown, so a stray second
    // tap on a card that just appeared is ignored.
    if (event.rating != null && !state.answerShown) return;

    // The next card is usually downloaded already. Only if it isn't, the
    // student briefly sees the loading indicator.
    final newId = state.session.peekNextFlashcardId;
    StatRecord? nextRecord;
    var nextIsMissing = false;
    if (newId != null) {
      final pending = _getRecord(newId);
      if (!_readyRecords.containsKey(newId)) {
        emit(state.copyWith(status: SessionTestStatus.loading, error: null));
      }
      final recordResult = await pending;
      switch (recordResult) {
        case Error<StatRecord>(:final error):
          if (error is DocumentDoesntExistException) {
            nextIsMissing = true;
            break;
          }
          // Nothing was saved yet, so pressing again simply retries.
          emit(state.copyWith(status: SessionTestStatus.error, error: error));
          return;
        case Ok<StatRecord>(:final value):
          nextRecord = value;
      }
    }

    _saveAnswer(state, event);

    final newSession = event.isCorrect
        ? state.session.incrementCurrentIndexAndCorrectCount()
        : state.session.incrementCurrentIndex();
    _prefetchAfter(newSession, newSession.currentIndex);

    if (newSession.isFinished) {
      emit(
        state.copyWith(status: SessionTestStatus.finished, session: newSession),
      );
      return;
    }

    if (nextIsMissing || nextRecord == null) {
      // The card was deleted after the session was made.
      emit(
        state.copyWith(
          unformattedQuestion: '',
          status: SessionTestStatus.noFlashcard,
          statRecord: StatRecord.empty(),
          session: newSession,
          answerShown: false,
          error: null,
        ),
      );
      return;
    }

    final unformattedQuestion = nextRecord.flashcard!.question;
    emit(
      state.copyWith(
        unformattedQuestion: unformattedQuestion,
        status: SessionTestStatus.initial,
        statRecord: nextRecord.copyWith(
          flashcard: nextRecord.flashcard!.copyWith(
            question: redactClozeQuestion(unformattedQuestion),
          ),
        ),
        session: newSession,
        answerShown: false,
        error: null,
      ),
    );
  }

  /// Saves the rating, the session position and the streak in the background.
  void _saveAnswer(SessionTestLoaded state, SessionTestNextPressed event) {
    _updateStreakInBackground(
      () => _profileRepo.checkAndIncrementCardsCount(event.userStreak),
    );

    // Save the rating to the card's progress, so custom sessions count
    // towards spaced repetition like regular study.
    final rating = event.rating;
    if (rating != null && !state.status.isNoFlashcard) {
      final currRecord = state.statRecord.copyWith(
        // The question in state is formatted for display (cloze revealed),
        // the progress record must keep the original.
        flashcard: state.statRecord.flashcard?.copyWith(
          question: state.unformattedQuestion,
        ),
      );
      final newCard = FSRS()
          .repeat(currRecord.card, DateTime.now())[rating]!
          .card;
      _saver.run(
        'card progress',
        () => _fcpRepo.safeUpdateCard(
          newStatRecord: currRecord.copyWith(card: newCard),
          currStatRecord: currRecord,
          rating: rating,
        ),
      );
      _countTowardsTargets(currRecord.packId);
    }

    final sessionId = state.session.id;
    _saver.run(
      'session position',
      () => event.isCorrect
          ? _sessionRepo.answeredCorrect(sessionId)
          : _sessionRepo.answeredWrong(sessionId),
    );
  }

  /// A card studied here counts towards today's session of its pack (and
  /// the exam goal's), like a card studied in the pack itself.
  void _countTowardsTargets(String packId) {
    final progress = _sessionProgress;
    if (progress == null || packId.isEmpty) return;
    unawaited(() async {
      await progress.add('', packId);
      try {
        if (await _dailyTarget?.isGoalPack([packId]) ?? false) {
          await progress.add('', 'goal');
        }
      } catch (_) {
        // Only the goal's session count is missed.
      }
    }());
  }

  void _onBookmarkToggled(
    SessionTestBookmarkToggled event,
    Emitter<SessionTestState> emit,
  ) async {
    final state = this.state;
    if (state is! SessionTestLoaded ||
        state.status.isLoading ||
        state.status.isBookmarkLoading) {
      return;
    }

    // this is local copy of the currRecord, after emitting
    // new states this will always stay the same
    final currRecord = state.statRecord;
    emit(
      state.copyWith(
        status: SessionTestStatus.bookmarkLoading,
        statRecord: state.statRecord.copyWith(
          hasBookmark: !state.statRecord.hasBookmark,
        ),
        error: null,
      ),
    );

    late final Result<void> bookmarkResult;
    //await Future.delayed(Duration(milliseconds: 1500));
    if (!currRecord.hasBookmark) {
      bookmarkResult = await _fcpRepo.safeAddBookmark(record: currRecord);
    } else {
      bookmarkResult = await _fcpRepo.removeBookmark(
        flashcardId: currRecord.flashcardId,
        record: currRecord,
      );
    }

    switch (bookmarkResult) {
      case Error<void>(:final error):
        // revert previous state and emit error
        print("Error while toggling bookmark");
        print(error);
        // when we write this.state it's referring to the global state, not local one
        // so here we just return back the old local stat record
        emit(
          (this.state as SessionTestLoaded).copyWith(
            status: SessionTestStatus.error,
            statRecord: currRecord,
            error: error,
          ),
        );
        return;
      case Ok<void>():
    }

    emit(
      (this.state as SessionTestLoaded).copyWith(
        status: SessionTestStatus.initial,
      ),
    );
  }
}
