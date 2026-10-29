import 'dart:async';
import 'dart:math';

import 'package:flashcards/bloc/flashcards/flashcard/flashcard_event.dart';
import 'package:flashcards/bloc/flashcards/flashcard/flashcard_state.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pp_repository.dart';
import 'package:flashcards/data/repositories/users/auth_repository.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/users/profile_repository.dart';
import 'package:flashcards/data/repositories/utils/user_claims.dart';
import 'package:flashcards/data/services/api/dto/users/profile/update_profile/update_profile_dto.dart';
import 'package:flashcards/data/services/api/dto/users/profile/update_profile/update_profile_settings/update_profile_settings_dto.dart';
import 'package:flashcards/data/services/local/local_storage_service.dart';
import 'package:flashcards/data/services/local/daily_target.dart';
import 'package:flashcards/data/services/local/session_progress_store.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/stat_record/stat_record.dart';
import 'package:flashcards/domain/models/profile/streak/streak.dart';
import 'package:flashcards/utils/background_save.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs/fsrs.dart';

class FlashcardBloc extends Bloc<FlashcardEvent, FlashcardState> {
  final FlashcardRepository _flashcardRepo;
  final FcpRepository _fcpRepo;
  final ProfileRepository _profileRepo;
  final PpRepository _ppRepo;
  final LocalStorageService _localStorageService;
  final SessionProgressStore _sessionProgress;
  final DailyTargetService? _dailyTarget;

  /// Where today's count of this session is kept: the pack, or 'goal' when
  /// the pack is part of the exam goal (one daily target for all its packs).
  String? _progressKey;

  /// How the session was started, to start it again with a new target.
  FlashcardTestStarted? _startEvent;
  late final String _uid;

  /// Saves progress without making the student wait for the server.
  final _saver = BackgroundSaver();

  /// Saves that failed, shown to the student without stopping the review.
  Stream<Exception> get saveErrors => _saver.errors;

  /// Image URLs of the next cards, so the page can load the pictures early.
  final _upcomingImages = StreamController<String>.broadcast();
  Stream<String> get upcomingImages => _upcomingImages.stream;
  final _announcedImageCards = <String>{};

  /// Downloads of cards that aren't in the session data yet.
  final _flashcardFetches = <String, Future<Result<Flashcard>>>{};
  final _readyFlashcards = <String, Flashcard>{};
  static const _prefetchCount = 3;

  @override
  Future<void> close() {
    // Once the last ratings are saved, share the session's count right away
    // so another device opened next continues from here.
    unawaited(_saver.settle().then((_) => _sessionProgress.flush()));
    _saver.dispose();
    _upcomingImages.close();
    return super.close();
  }

  Future<Result<Flashcard>> _fetchFlashcard(String flashcardId) {
    return _flashcardFetches.putIfAbsent(
      flashcardId,
      () => _flashcardRepo.getFlashcard(flashcardId).withReadTimeout().then((
        result,
      ) {
        if (result case Ok(:final value)) {
          _readyFlashcards[flashcardId] = value;
          _announceImages(flashcardId, value);
        } else {
          // A failed download is tried again next time.
          _flashcardFetches.remove(flashcardId);
        }
        return result;
      }),
    );
  }

  void _announceImages(String flashcardId, Flashcard flashcard) {
    if (!_announcedImageCards.add(flashcardId)) return;
    for (final url in [flashcard.questionImageUrl, flashcard.answerImageUrl]) {
      if (url != null && url.isNotEmpty && !_upcomingImages.isClosed) {
        _upcomingImages.add(url);
      }
    }
  }

  /// Starts loading the cards after [index] while the current one is studied.
  void _prefetchAfter(List<StatRecord> records, int index) {
    for (
      var i = index + 1;
      i < records.length && i <= index + _prefetchCount;
      i++
    ) {
      final record = records[i];
      if (record.flashcard != null) {
        _announceImages(record.flashcardId, record.flashcard!);
      } else {
        _fetchFlashcard(record.flashcardId);
      }
    }
  }

  final double _newCardsPercentage = 0.2;
  final double _goalNewCardsPercentage = 0.7;
  final int _sessionExtendedTargetCards = 20;

  FlashcardBloc({
    required FlashcardRepository flashcardRepo,
    required FcpRepository fcpRepo,
    required AuthRepository authRepo,
    required ProfileRepository profileRepo,
    required PpRepository ppRepo,
    required LocalStorageService localStorageService,
    SessionProgressStore? sessionProgress,
    DailyTargetService? dailyTarget,
  }) : _flashcardRepo = flashcardRepo,
       _dailyTarget = dailyTarget,
       _sessionProgress = sessionProgress ?? SessionProgressStore(),
       _localStorageService = localStorageService,
       _fcpRepo = fcpRepo,
       _profileRepo = profileRepo,
       _ppRepo = ppRepo,
       super(FlashcardState()) {
    final user = authRepo.getCurrentUser();
    if (user == null) {
      throw Exception("User is null");
    }
    _uid = user.uid;

    on<FlashcardTestStarted>(_onFlashcardTestStarted);
    on<FlashcardAnswerShown>(_onFlashcardAnswerShown);
    on<FlashcardHintToggled>(_onFlashcardHintToggled);
    on<FlashcardSessionExtended>(_onFlashcardSessionExtended);
    on<FlashcardCardsPerSessionUpdated>(_onFlashcardCardsPerSessionUpdated);
    on<FlashcardRatingGiven>(_onFlashcardRatingGiven);
    on<FlashcardBookmarkToggled>(_onFlashcardBookmarkToggled);
    on<FlashcardIgnored>(_onFlashcardIgnored);
    on<FlashcardTutorialSeenChecked>(_onTutorialChecked);
    on<FlashcardTutorialFinished>(_onTutorialFinished);
    on<FlashcardEdited>(_onFlashcardEdited);
    on<FlashcardSessionTargetChanged>(_onSessionTargetChanged);
  }

  void _onTutorialChecked(
    FlashcardTutorialSeenChecked event,
    Emitter<FlashcardState> emit,
  ) async {
    if (state.tutorialSeen == true) return;

    final isSeen = await _localStorageService.getFlashcardsTutorialSeen();
    if (!isSeen) {
      emit(state.copyWith(tutorialSeen: false));
    }
  }

  void _onTutorialFinished(
    FlashcardTutorialFinished event,
    Emitter<FlashcardState> emit,
  ) async {
    if (state.tutorialSeen == true) return;

    _localStorageService.setFlashcardsTutorialSeen();
    emit(state.copyWith(tutorialSeen: true));
  }

  void _onFlashcardIgnored(
    FlashcardIgnored event,
    Emitter<FlashcardState> emit,
  ) async {
    if (state.status.isSessionEnded ||
        state.status.isPackFinished ||
        state.status.isLoading ||
        state.status.isBookmarkLoading) {
      return;
    }
    final flashcard = state.flashcard;
    if (flashcard == null) {
      throw Exception("Flashcard is null inside onFlashcardIgnored");
    }

    emit(state.copyWith(status: FlashcardStatus.loading, errorMessage: null));

    final currStatRecord = state.statRecords[state.currentCardIndex];
    final ignoreResult = await _fcpRepo.safeIgnoreCard(record: currStatRecord);
    switch (ignoreResult) {
      case Error<void>(:final error):
        emit(
          state.copyWith(
            status: FlashcardStatus.error,
            errorMessage: error.toString(),
          ),
        );
        return;
      case Ok<void>():
    }

    final shouldReturn = await _checkLengthAndEmit(emit: emit);
    if (shouldReturn) return;

    final newCurrIndex = state.currentCardIndex + 1;
    final fcResult = await _getNewFlashcardAndEmitError(
      emit: emit,
      currCardIndex: newCurrIndex,
      records: state.statRecords,
    );
    if (fcResult.status == 'error') return;

    emit(
      state.copyWith(
        status: FlashcardStatus.loaded,
        flashcard: fcResult.flashcard!,
        statRecords: fcResult.records!,
        answerVisible: false,
        currentCardIndex: newCurrIndex,
      ),
    );
  }

  void _onFlashcardCardsPerSessionUpdated(
    FlashcardCardsPerSessionUpdated event,
    Emitter<FlashcardState> emit,
  ) async {
    emit(state.copyWith(status: FlashcardStatus.loading, errorMessage: null));

    final updateDto = UpdateProfileDto(
      profileSettings: UpdateProfileSettingsDto(
        cardsPerSession: event.cardPerSession,
      ),
    );
    final profileResult = await _profileRepo.updateCurrentProfile(updateDto);
    switch (profileResult) {
      case Error<void>(:final error):
        emit(
          state.copyWith(
            status: FlashcardStatus.error,
            errorMessage: error.toString(),
          ),
        );
        return;
      case Ok<void>():
    }

    emit(state.copyWith(status: FlashcardStatus.profileUpdated));
  }

  void _onFlashcardBookmarkToggled(
    FlashcardBookmarkToggled event,
    Emitter<FlashcardState> emit,
  ) async {
    if (state.flashcard == null ||
        state.status.isBookmarkLoading ||
        state.status.isLoading) {
      return;
    }

    final currStatRecord = state.statRecords[state.currentCardIndex];
    final updatedRecords = _updateCurrentStatRecord(
      (record) => record.copyWith(hasBookmark: !currStatRecord.hasBookmark),
    );
    emit(
      state.copyWith(
        status: FlashcardStatus.bookmarkLoading,
        statRecords: updatedRecords,
        errorMessage: null,
      ),
    );

    late final Result<void> bookmarkResult;
    if (!currStatRecord.hasBookmark) {
      bookmarkResult = await _fcpRepo.safeAddBookmark(record: currStatRecord);
    } else {
      bookmarkResult = await _fcpRepo.removeBookmark(
        flashcardId: currStatRecord.flashcardId,
        record: currStatRecord,
      );
    }

    switch (bookmarkResult) {
      case Error<void>(:final error):
        // revert previous state and emit error
        final revert = _updateCurrentStatRecord(
          (record) => record.copyWith(hasBookmark: currStatRecord.hasBookmark),
        );
        emit(
          state.copyWith(
            status: FlashcardStatus.error,
            statRecords: revert,
            errorMessage: error.toString(),
          ),
        );
        return;
      case Ok<void>():
    }

    //_updateCacheForBookmark(currStatRecord);

    emit(state.copyWith(status: FlashcardStatus.loaded));
  }

  /// True while moving to the next card, so a quick double tap doesn't
  /// rate the same card twice.
  bool _advancing = false;

  void _onFlashcardRatingGiven(
    FlashcardRatingGiven event,
    Emitter<FlashcardState> emit,
  ) async {
    if (_advancing) return;
    _advancing = true;
    try {
      await _rate(event, emit);
    } finally {
      _advancing = false;
    }
  }

  Future<void> _rate(
    FlashcardRatingGiven event,
    Emitter<FlashcardState> emit,
  ) async {
    if (state.status.isSessionEnded ||
        state.status.isPackFinished ||
        state.status.isLoading ||
        state.status.isBookmarkLoading) {
      return;
    }

    // Ratings are only offered once the answer is shown, so a stray second
    // tap on a card that just appeared is ignored.
    if (!state.answerVisible) return;

    if (state.flashcard == null) {
      throw Exception("Flashcard is null inside flashcard state");
    }
    // count streak, if it needs to
    _saver.run('streak', () async {
      final result = await _profileRepo.checkAndIncrementCardsCount(
        event.userStreak,
      );
      return switch (result) {
        Error<Streak?>(:final error) => Result.error(error),
        Ok<Streak?>() => Result.ok(null),
      };
    });

    // Counts towards today's target of this pack (not extra batches).
    if (state.testType == TestType.regular &&
        state.currentBatch == 0 &&
        state.pack != null) {
      _sessionProgress.add(_uid, _progressKey ?? state.pack!.id);
    }

    final oldCard = state.statRecords[state.currentCardIndex].card;
    final newCard = FSRS().repeat(oldCard, DateTime.now())[event.rating]!.card;

    final updatedRecords = _updateCurrentStatRecord(
      (record) => record.copyWith(card: newCard),
    );

    final newStatRecord = updatedRecords[state.currentCardIndex];
    final currStatRecord = state.statRecords[state.currentCardIndex];
    _saver.run(
      'card progress',
      () => _fcpRepo.safeUpdateCard(
        newStatRecord: newStatRecord,
        currStatRecord: currStatRecord,
        rating: event.rating,
      ),
    );

    final shouldReturn = await _checkLengthAndEmit(
      emit: emit,
      updatedRecords: updatedRecords,
    );
    if (shouldReturn) return;

    final newIndex = state.currentCardIndex + 1;
    final flashcardResult = await _getNewFlashcardAndEmitError(
      emit: emit,
      records: updatedRecords,
      currCardIndex: newIndex,
    );
    if (flashcardResult.status == 'error') return;

    emit(
      state.copyWith(
        status: FlashcardStatus.loaded,
        flashcard: flashcardResult.flashcard!,
        currentCardIndex: newIndex,
        statRecords: flashcardResult.records!,
        errorMessage: null,
        hintVisible: false,
        answerVisible: false,
      ),
    );
  }

  Future<void> _onSessionTargetChanged(
    FlashcardSessionTargetChanged event,
    Emitter<FlashcardState> emit,
  ) async {
    final pack = state.pack;
    final start = _startEvent;
    if (pack == null || start == null) return;
    await _sessionProgress.setPackTarget(_uid, pack.id, event.target);
    // Ratings already given are saved; start again with the new target.
    await _saver.settle();
    emit(FlashcardState());
    add(start);
  }

  void _onFlashcardTestStarted(
    FlashcardTestStarted event,
    Emitter<FlashcardState> emit,
  ) async {
    _startEvent = event;
    if (!state.status.isInitial &&
        !(state.status.isError && state.flashcard == null)) {
      return;
    }

    emit(
      state.copyWith(
        status: FlashcardStatus.loading,
        answerVisible: false,
        hintVisible: false,
        errorMessage: null,
        testType: event.testType,
        pack: event.pack,
        cardsPerSession: event.cardsPerSession,
      ),
    );

    final claims = await UserClaims.current();
    final hasCards = claims.hasCards;
    emit(state.copyWith(hasCards: hasCards));

    // start counting, if it needs to
    _saver.run('streak', () async {
      final result = await _profileRepo.checkAndStartStreak(event.userStreak);
      return switch (result) {
        Error<Streak?>(:final error) => Result.error(error),
        Ok<Streak?>() => Result.ok(null),
      };
    });

    late final Result<List<StatRecord>> fcpResult;
    switch (event.testType) {
      case TestType.regular:
        final pack = event.pack!;
        // A pack of the exam goal studies what the goal needs today;
        // other packs use the cards per session.
        var target = event.cardsPerSession;
        var key = pack.id;
        var newShare = _newCardsPercentage;
        final daily = _dailyTarget;
        // What the user's other devices studied today, so every device
        // continues the same session.
        await _sessionProgress.refresh();
        // A target chosen for this pack comes first, then the student's
        // daily new card and review limits.
        final own = await _sessionProgress.packTarget(_uid, pack.id);
        final limits = own == null
            ? await _sessionProgress.dailyLimits()
            : null;
        int? maxNew, maxDue;
        if (own != null) {
          target = own;
        } else if (limits != null) {
          // What's left of today's limits, after every session today.
          final studied = await _sessionProgress.studiedToday();
          maxNew = max(0, limits.newCards - studied.newCards);
          maxDue = max(0, limits.reviews - studied.reviews);
        } else if (daily != null &&
            await daily.isGoalPack([
              pack.id,
              ...pack.subPacks.map((p) => p.id),
            ])) {
          target = (await daily.todayTarget(event.cardsPerSession)).target;
          key = 'goal';
          // The goal counts new cards, so they make up most of the session.
          newShare = _goalNewCardsPercentage;
        }
        _progressKey = key;

        // Opening the pack again today continues the same session. Cards
        // of its sub-packs studied on their own or in custom sessions count
        // too.
        var done = await _sessionProgress.doneToday(_uid, key);
        if (key == pack.id) {
          for (final sub in pack.subPacks) {
            if (sub.id != pack.id) {
              done += await _sessionProgress.doneToday(_uid, sub.id);
            }
          }
        }
        final remaining = maxNew != null && maxDue != null
            ? maxNew + maxDue
            : target - done;
        if (maxNew != null) target = done + remaining;
        emit(state.copyWith(sessionDone: done, cardsPerSession: target));
        if (remaining <= 0) {
          // Today's target is done: offer to continue with more cards.
          emit(state.copyWith(status: FlashcardStatus.sessionEnded));
          return;
        }
        fcpResult = await _fcpRepo.loadDataForStandardTest(
          packId: pack.id,
          target: remaining,
          newCardsPercentage: newShare,
          isPaid: event.pack!.isPaid,
          hasCards: state.hasCards,
          subPacks: event.pack!.subPacks,
          maxNew: maxNew,
          maxDue: maxDue,
        );
        // With daily limits the session is what was found, which can be
        // less than the limits allow.
        if (maxNew != null) {
          if (fcpResult case Ok<List<StatRecord>>(:final value)) {
            emit(state.copyWith(cardsPerSession: done + value.length));
          }
        }

        // Remembers the pack as started (Started packs list).
        _saver.run(
          'pack opened',
          () => _ppRepo.openPack(packId: pack.id, packName: pack.name),
        );
        break;
      case TestType.bookmark:
        fcpResult = await _fcpRepo.loadDataForBookmarksTest(
          event.cardsPerSession,
          state.hasCards!,
        );
        break;
    }

    switch (fcpResult) {
      case Error<List<StatRecord>>(:final error):
        emit(
          state.copyWith(
            status: FlashcardStatus.error,
            errorMessage: error.toString(),
          ),
        );
        return;
      case Ok<List<StatRecord>>():
    }

    int currentCardIndex = 0;
    var records = fcpResult.value;

    // no stat records, flashcard_builder finished for now
    if (records.isEmpty) {
      emit(state.copyWith(status: FlashcardStatus.packFinished));
      return;
    }

    final result = await _getNewFlashcardAndEmitError(
      emit: emit,
      records: records,
      currCardIndex: currentCardIndex,
    );
    if (result.status == 'error') return;

    emit(
      state.copyWith(
        status: FlashcardStatus.loaded,
        statRecords: result.records!,
        flashcard: result.flashcard!,
        currentCardIndex: currentCardIndex,
      ),
    );

    // when everything is loaded and user is ready to start the test,
    // we check to see if he saw the tutorial
    add(FlashcardTutorialSeenChecked());
  }

  void _onFlashcardSessionExtended(
    FlashcardSessionExtended event,
    Emitter<FlashcardState> emit,
  ) async {
    if (!state.status.isSessionEnded) return;

    // The next batch is chosen from saved progress.
    await _saver.settle();
    await _loadNextBatchAndEmit(
      emit: emit,
      newCardsPerSession: _sessionExtendedTargetCards,
    );
  }

  void _onFlashcardAnswerShown(
    FlashcardAnswerShown event,
    Emitter<FlashcardState> emit,
  ) {
    // if flashcard has cloze, we need to format it
    final currRecord = state.statRecords[state.currentCardIndex];
    final clozeFlashcard = state.flashcard!.copyWith(
      question: revealClozeQuestion(currRecord.flashcard!.question),
    );

    emit(
      state.copyWith(
        status: FlashcardStatus.loaded,
        answerVisible: true,
        flashcard: clozeFlashcard,
      ),
    );
  }

  void _onFlashcardEdited(FlashcardEdited event, Emitter<FlashcardState> emit) {
    final index = state.currentCardIndex;
    if (state.flashcard == null ||
        index >= state.statRecords.length ||
        state.statRecords[index].flashcardId != event.flashcard.id) {
      return;
    }
    final edited = event.flashcard;
    emit(
      state.copyWith(
        statRecords: _updateStatRecordAt(
          state.statRecords,
          index,
          (record) => record.copyWith(flashcard: edited),
        ),
        flashcard: edited.copyWith(
          question: state.answerVisible
              ? revealClozeQuestion(edited.question)
              : redactClozeQuestion(edited.question),
        ),
      ),
    );
  }

  void _onFlashcardHintToggled(
    FlashcardHintToggled event,
    Emitter<FlashcardState> emit,
  ) {
    final toggleValue = !state.hintVisible;
    emit(
      state.copyWith(status: FlashcardStatus.loaded, hintVisible: toggleValue),
    );
  }

  Future<bool> _checkLengthAndEmit({
    required Emitter<FlashcardState> emit,
    List<StatRecord>? updatedRecords,
  }) async {
    final records = updatedRecords ?? state.statRecords;

    // it means we ran out of flashcards from this session
    if (state.currentCardIndex >= records.length - 1) {
      // if user choose an option to extend the session, we continue extending it
      if (state.currentBatch > 0) {
        // The next batch is chosen from saved progress.
        await _saver.settle();
        await _loadNextBatchAndEmit(emit: emit);
        return true;
      }
      FlashcardState newState;
      if (updatedRecords == null) {
        newState = state.copyWith(
          status: FlashcardStatus.sessionEnded,
          errorMessage: null,
        );
      } else {
        newState = state.copyWith(
          status: FlashcardStatus.sessionEnded,
          statRecords: updatedRecords,
          errorMessage: null,
        );
      }
      emit(newState);
      return true;
    }
    return false;
  }

  Future<GetNewFlashcard> _getNewFlashcardAndEmitError({
    required Emitter<FlashcardState> emit,
    required List<StatRecord> records,
    required int currCardIndex,
  }) async {
    late final Flashcard flashcard;
    final currStatRecord = records[currCardIndex];
    // if we already have flashcard data, we use that instead of calling the db
    if (currStatRecord.flashcard != null) {
      flashcard = currStatRecord.flashcard!;
    } else {
      final fcId = currStatRecord.flashcardId;
      final pending = _fetchFlashcard(fcId);
      if (!_readyFlashcards.containsKey(fcId)) {
        // Only now the student has to wait.
        emit(state.copyWith(status: FlashcardStatus.loading));
      }
      final cardResult = await pending;
      switch (cardResult) {
        case Error<Flashcard>(:final error):
          emit(
            state.copyWith(
              status: FlashcardStatus.error,
              errorMessage: error.toString(),
            ),
          );
          return GetNewFlashcard(status: "error");
        case Ok<Flashcard>():
      }
      flashcard = cardResult.value;
      // also write this new flashcard inside stat record
      records = _updateStatRecordAt(
        records,
        currCardIndex,
        (record) => record.copyWith(flashcard: flashcard),
      );
    }

    _prefetchAfter(records, currCardIndex);

    // if flashcard.question has cloze, we need to format it
    final clozeFlashcard = flashcard.copyWith(
      question: redactClozeQuestion(flashcard.question),
    );

    return GetNewFlashcard(
      status: 'success',
      flashcard: clozeFlashcard,
      records: records,
    );
  }

  Future<void> _loadNextBatchAndEmit({
    required Emitter<FlashcardState> emit,
    int? newCardsPerSession,
  }) async {
    if (state.testType == null || state.cardsPerSession == null) {
      throw Exception(
        "Test type or cardsPerSession can't be null in _loadNextBatchAndEmit handler",
      );
    }

    emit(state.copyWith(status: FlashcardStatus.loading, errorMessage: null));

    final int cardsPerSession = newCardsPerSession ?? state.cardsPerSession!;
    Result<List<StatRecord>> testResult;
    switch (state.testType!) {
      case TestType.regular:
        if (state.pack == null) {
          throw Exception("Pack can't be null if the test type is regular");
        }
        testResult = await _fcpRepo.loadDataForStandardTest(
          packId: state.pack!.id,
          isPaid: state.pack!.isPaid,
          target: cardsPerSession,
          newCardsPercentage: _newCardsPercentage,
          hasCards: state.hasCards,
          subPacks: state.pack!.subPacks,
        );
        break;
      case TestType.bookmark:
        testResult = await _fcpRepo.loadDataForBookmarksTest(
          cardsPerSession,
          state.hasCards!,
        );
        break;
    }

    switch (testResult) {
      case Error<List<StatRecord>>(:final error):
        emit(
          state.copyWith(
            status: FlashcardStatus.error,
            errorMessage: error.toString(),
          ),
        );
        return;
      case Ok<List<StatRecord>>():
    }
    var records = testResult.value;
    final currentCardIndex = 0;

    // no records pulled, means that this flashcard_builder is finished for now
    if (records.isEmpty) {
      emit(state.copyWith(status: FlashcardStatus.packFinished));
      return;
    }

    final result = await _getNewFlashcardAndEmitError(
      emit: emit,
      records: records,
      currCardIndex: currentCardIndex,
    );
    if (result.status == 'error') return;

    emit(
      state.copyWith(
        status: FlashcardStatus.loaded,
        cardsPerSession: cardsPerSession,
        flashcard: result.flashcard!,
        statRecords: result.records!,
        currentCardIndex: currentCardIndex,
        currentBatch: state.currentBatch + 1,
        hintVisible: false,
        answerVisible: false,
        errorMessage: null,
      ),
    );
  }

  List<StatRecord> _updateCurrentStatRecord(
    StatRecord Function(StatRecord record) copyWith,
  ) {
    return _updateStatRecordAt(
      state.statRecords,
      state.currentCardIndex,
      copyWith,
    );
  }

  List<StatRecord> _updateStatRecordAt(
    List<StatRecord> records,
    int index,
    StatRecord Function(StatRecord record) copyWith,
  ) {
    final updatedRecords = List<StatRecord>.from(records);
    updatedRecords[index] = copyWith(updatedRecords[index]);

    return updatedRecords;
  }

  bool _isDueToday(DateTime due) {
    final now = DateTime.now();
    return due.year == now.year && due.month == now.month && due.day == now.day;
  }
}

class GetNewFlashcard {
  final Flashcard? flashcard;
  final List<StatRecord>? records;
  final String status;

  const GetNewFlashcard({this.flashcard, required this.status, this.records});
}
