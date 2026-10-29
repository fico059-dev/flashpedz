import 'dart:math';
import 'package:flashcards/data/repositories/utils/user_claims.dart';
import 'package:flashcards/data/services/api/dto/flashcards/custom_session/flashcard_ids/flashcard_ids_dto.dart';
import 'package:flashcards/data/services/api/dto/flashcards/flashcard/flashcard_dto.dart';
import 'package:flashcards/data/services/api/exceptions/document_doesnt_exist_exception.dart';
import 'package:flashcards/data/services/api/flashcards/flashcard_service.dart';
import 'package:flashcards/data/services/api/flashcards/pack_service.dart';
import 'package:flashcards/data/utils/data_utils.dart';
import 'package:flashcards/data/mappers/fsrs_mapper.dart';
import 'package:flashcards/data/repositories/utils/cache/page_cache/page_cache.dart';
import 'package:flashcards/data/repositories/utils/pagination/paginated_cursor_map.dart';
import 'package:flashcards/data/services/api/dto/flashcards/fcp_data/fcp_data_dto.dart';
import 'package:flashcards/data/services/api/dto/flashcards/fcp_data/update_fcp_data/update_fcp_data_dto.dart';
import 'package:flashcards/data/services/api/users/auth_service.dart';
import 'package:flashcards/data/services/api/flashcards/fcp_service.dart';
import 'package:flashcards/domain/models/flashcards/bookmark/bookmark.dart';
import 'package:flashcards/domain/models/flashcards/flashcard_filter_counts/pack_filter_counts.dart';
import 'package:flashcards/domain/models/flashcards/ignored_flashcard/ignored_flashcard.dart';
import 'package:flashcards/domain/models/flashcards/pack/pack.dart';
import 'package:flashcards/domain/models/flashcards/stat_record/stat_record.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/data/services/local/seen_cards_store.dart';
import 'package:flashcards/data/services/local/study_log_store.dart';
import 'package:flashcards/data/services/local/study_rewards.dart';
import 'package:fsrs/fsrs.dart';

class FcpRepository {
  final FcpService _fcpService;
  final AuthService _authService;
  final FlashcardService _flashcardService;
  final PackService _packService;

  final PaginatedCursorMap _bookmarkCursorMap = PaginatedCursorMap();
  final PaginatedCursorMap _ignoredCursorMap = PaginatedCursorMap();

  final PageCache<Pack> _packsCache;

  final StudyLogStore? _studyLog;
  final StudyRewards? _rewards;
  final SeenCardsStore _seenCards;

  FcpRepository({
    required FcpService fcpService,
    required AuthService authService,
    required FlashcardService flashcardService,
    required PackService packService,
    required PageCache<Pack> packCache,
    StudyLogStore? studyLog,
    StudyRewards? rewards,
    SeenCardsStore? seenCards,
  }) : _studyLog = studyLog,
       _rewards = rewards,
       _seenCards = seenCards ?? SeenCardsStore(),
       _fcpService = fcpService,
       _authService = authService,
       _packService = packService,
       _flashcardService = flashcardService,
       _packsCache = packCache;

  /// Cards for one study session of a pack. [subPacks] are the packs shown
  /// inside it: their cards are studied together with the pack's own.
  Future<Result<List<StatRecord>>> loadDataForStandardTest({
    required String packId,
    required bool isPaid,
    required int target,
    required double newCardsPercentage,
    required hasCards,
    List<Pack> subPacks = const [],

    /// The student's daily limits still left today. When given, the
    /// session has up to [maxNew] new cards and [maxDue] due cards,
    /// whatever the number of due cards.
    int? maxNew,
    int? maxDue,
  }) async {
    if (target < 0 || newCardsPercentage > 1 || newCardsPercentage < 0) {
      throw Exception("Invalid inputs in loadDataForStandardTest");
    }

    final uid = _getUid();

    // Premium sub-packs are left out without a subscription.
    final studyPacks = <(String, bool)>[
      (packId, isPaid),
      for (final sub in subPacks)
        if (sub.id != packId && (!sub.isPaid || hasCards == true))
          (sub.id, sub.isPaid),
    ];

    final pieces = await Future.wait(
      studyPacks.map(
        (pack) => _loadPackPieces(
          uid: uid,
          packId: pack.$1,
          target: target,
          hasCards: hasCards,
        ),
      ),
    );

    final packFlashcardIds = <String>[];
    final packOfCard = <String, (String, bool)>{};
    final seenIds = <String>{};
    final dueRecords = <StatRecord>[];
    for (var i = 0; i < pieces.length; i++) {
      final piece = pieces[i];
      switch (piece) {
        case Error<_PackPieces>(:final error):
          return Result.error(error);
        case Ok<_PackPieces>(:final value):
          for (final id in value.flashcardIds) {
            if (packOfCard.containsKey(id)) continue;
            packOfCard[id] = studyPacks[i];
            packFlashcardIds.add(id);
          }
          seenIds.addAll(value.seenIds);
          dueRecords.addAll(value.due);
      }
    }
    // Most overdue first, across all the packs.
    dueRecords.sort((a, b) => a.card.due.compareTo(b.card.due));

    final all = packFlashcardIds.length;
    var normalizedTarget = target;
    if (target > all) normalizedTarget = all;

    if (normalizedTarget == 0) {
      return Result.ok([]);
    }

    final unseenCount = packFlashcardIds
        .where((id) => !seenIds.contains(id))
        .length;
    // Progress of cards removed from the pack can still be due, so "seen"
    // is never less than the due cards found.
    final dueList = dueRecords.take(all).toList();
    final seen = (all - unseenCount).clamp(dueList.length, all);

    final [newCount, dueCount] = maxNew != null && maxDue != null
        ? [min(max(0, maxNew), all - seen), min(max(0, maxDue), dueList.length)]
        : _calculateSeenAndNewCount(
            all,
            seen,
            dueList.length,
            normalizedTarget,
            newCardsPercentage,
          );

    final List<StatRecord> resultList = [];

    resultList.addAll(dueList.take(dueCount));

    // New cards are picked at random from the cards not studied yet, so
    // the student doesn't go through the pack in the order it was made.
    if (newCount > 0) {
      final newFcIds = pickNewCardIds(packFlashcardIds, seenIds, newCount);
      resultList.addAll(
        newFcIds.map((fcId) {
          final (cardPackId, cardIsPaid) = packOfCard[fcId]!;
          return StatRecord(
            packId: cardPackId,
            flashcardId: fcId,
            card: Card(),
            isPaid: cardIsPaid,
          );
        }),
      );
    }

    return Result.ok(resultList);
  }

  /// One pack's card ids, its due cards (at most [target]) and the cards
  /// the user has studied.
  Future<Result<_PackPieces>> _loadPackPieces({
    required String uid,
    required String packId,
    required int target,
    required hasCards,
  }) async {
    final flashcardIdsResult = await _packService.getFlashcardIds(packId);
    switch (flashcardIdsResult) {
      case Error<FlashcardIdsDto>(:final error):
        return Result.error(error);
      case Ok<FlashcardIdsDto>():
    }
    final ids = flashcardIdsResult.value.flashcardIds;
    if (ids.isEmpty || target == 0) {
      return Result.ok(_PackPieces(ids, const [], const {}));
    }

    final results = await Future.wait([
      _fcpService.getDueCardsForPack(
        uid,
        packId,
        target > ids.length ? ids.length : target,
        hasCards,
      ),
      _fcpService.countDocumentsForProfileAndPack(uid, packId, hasCards),
    ]);
    final dueResult = results[0] as Result<List<FcpDataDto>>;
    final countResult = results[1] as Result<int>;
    switch (dueResult) {
      case Error<List<FcpDataDto>>(:final error):
        return Result.error(error);
      case Ok<List<FcpDataDto>>():
    }
    switch (countResult) {
      case Error<int>(:final error):
        return Result.error(error);
      case Ok<int>():
    }

    final seenIds = await _seenFlashcardIds(
      uid: uid,
      packId: packId,
      serverCount: countResult.value,
      hasCards: hasCards,
    );
    switch (seenIds) {
      case Error<Set<String>>(:final error):
        return Result.error(error);
      case Ok<Set<String>>():
    }

    return Result.ok(
      _PackPieces(
        ids,
        dueResult.value.map((dto) => dto.toStatRecordDomain()).toList(),
        seenIds.value,
      ),
    );
  }

  Future<Result<List<StatRecord>>> loadDataForBookmarksTest(
    int target,
    bool hasCards,
  ) async {
    final uid = _getUid();

    // we get all the cards that are due and have a bookmark
    final result = await _fcpService.getDueDocsWithBookmark(
      uid,
      target,
      hasCards,
    );
    switch (result) {
      case Error<List<FcpDataDto>>(:final error):
        return Result.error(error);
      case Ok<List<FcpDataDto>>():
    }
    final dueCardsDtoList = result.value;

    final records = [...dueCardsDtoList.map((dto) => dto.toStatRecordDomain())];

    return Result.ok(records);
  }

  /// It tries to read from fcp_data, if it's not there it will read from flashcards
  /// and create empty fsrs_card and return stat record.
  Future<Result<StatRecord>> getStatRecordForFlashcardId(
    String flashcardId,
  ) async {
    final result = await _fcpService.getFcpDataDocument(
      profileId: _getUid(),
      flashcardId: flashcardId,
    );
    switch (result) {
      case Ok<FcpDataDto>():
        return Result.ok(result.value.toStatRecordDomain());
      case Error<FcpDataDto>():
    }

    final error = result.error;
    if (error is! DocumentDoesntExistException) {
      return Result.error(error);
    }
    // if fcp_data doc doesn't exist, pull from flashcards
    final fcResult = await _flashcardService.getDocument(flashcardId);
    switch (fcResult) {
      case Error<FlashcardDto>(:final error):
        return Result.error(error);
      case Ok<FlashcardDto>():
    }

    return Result.ok(fcResult.value.toEmptyStatRecord());
  }

  Future<Result<List<IgnoredFlashcard>>> getIgnoredFlashcardsPage({
    required int pageIndex,
    required int pageSize,
  }) async {
    final uid = _getUid();
    final lastDoc = _ignoredCursorMap.getLastDocFromPrevPage(pageIndex);

    final claims = await UserClaims.current();

    final result = await _fcpService.getIgnoredCardsPagination(
      hasCards: claims.hasCards,
      profileId: uid,
      limit: pageSize,
      startAfter: lastDoc,
    );
    switch (result) {
      case Error<PaginatedDtoResult<FcpDataDto>>(:final error):
        return Result.error(error);
      case Ok<PaginatedDtoResult<FcpDataDto>>():
    }

    final domainList = result.value.items
        .map((dto) => dto.toIgnoredFlashcardDomain())
        .toList();
    _ignoredCursorMap.put(pageIndex, result.value.lastDocument);

    return Result.ok(domainList);
  }

  Future<Result<List<Bookmark>>> getBookmarkPage({
    required int pageIndex,
    required int pageSize,
  }) async {
    final lastDoc = _bookmarkCursorMap.getLastDocFromPrevPage(pageIndex);
    final uid = _getUid();

    final claims = await UserClaims.current();

    final getResult = await _fcpService.getDocsWithBookmarkPagination(
      profileId: uid,
      startAfter: lastDoc,
      limit: pageSize,
      hasCards: claims.hasCards,
    );
    switch (getResult) {
      case Error<PaginatedDtoResult<FcpDataDto>>(:final error):
        return Result.error(error);
      case Ok<PaginatedDtoResult<FcpDataDto>>():
    }

    _bookmarkCursorMap.put(pageIndex, getResult.value.lastDocument);

    final dtoList = getResult.value.items;
    final domainList = dtoList.map((dto) => dto.toBookmarkDomain()).toList();

    return Result.ok(domainList);
  }

  Future<Result<PackFilterCounts>> getFilterCounts(
    List<String> packIds,
    int allCount,
  ) async {
    final uid = _getUid();
    final claims = await UserClaims.current();
    final hasCards = claims.hasCards;

    final results = await Future.wait<Result<int>>([
      _fcpService.countDocumentsForPacks(uid, packIds, hasCards),
      _fcpService.countBookmarkedDocsForPacks(uid, packIds, hasCards),
      _fcpService.countIgnoredDocsForPacks(uid, packIds, hasCards),
    ]);

    final [seenResult, bookmarkedResult, ignoredResult] = results;
    switch (seenResult) {
      case Error<int>(:final error):
        return Result.error(error);
      case Ok<int>():
    }

    switch (bookmarkedResult) {
      case Error<int>(:final error):
        return Result.error(error);
      case Ok<int>():
    }

    switch (ignoredResult) {
      case Error<int>(:final error):
        return Result.error(error);
      case Ok<int>():
    }

    return Result.ok(
      PackFilterCounts(
        allCount: allCount,
        seenCount: seenResult.value,
        bookmarkedCount: bookmarkedResult.value,
        ignoredCount: ignoredResult.value,
      ),
    );
  }

  Future<Result<void>> updateFcpData(
    String flashcardId,
    UpdateFcpDataDto updateDto,
  ) async {
    final uid = _getUid();

    return await _fcpService.updateDocument(
      uid,
      flashcardId,
      updateDto.toJson(),
    );
  }

  Future<Result<void>> safeIgnoreCard({required StatRecord record}) async {
    if (record.flashcard == null) {
      throw Exception(
        "You can't ignore a card if the flashcard inside record is null: $record",
      );
    }

    final uid = _getUid();
    // try to update card
    final updateDto = UpdateFcpDataDto(ignored: true);
    final updateResult = await _fcpService.updateDocument(
      uid,
      record.flashcardId,
      updateDto.toJson(),
    );
    switch (updateResult) {
      case Ok<void>():
        _updateCacheForIgnore(record, record.packId);
        return Result.ok(null);
      case Error<void>():
    }
    final error = updateResult.error;
    if (!isErrorNotFound(error)) {
      return Result.error(error);
    }

    // if the document doesn't exists, create it with default data and set ignored to true
    final setResult = await _fcpService.setDocument(
      FcpDataDto.fromStatRecord(record, uid).copyWith(ignored: true),
      // FcpDataDto(
      //   isPaid: record.isPaid,
      //   profileId: uid,
      //   flashcardId: record.flashcardId,
      //   fsrsCard: record.card,
      //   flashcardSnapshotDto: FlashcardSnapshotDto.fromFlashcard(
      //     record.flashcard!,
      //   ),
      //   ignored: true,
      // ),
    );

    switch (setResult) {
      case Error<void>(:final error):
        return Result.error(error);
      case Ok<void>():
    }
    _updateCacheForIgnore(record, record.packId);
    return Result.ok(null);
  }

  Future<Result<void>> safeAddBookmark({required StatRecord record}) async {
    if (record.flashcard == null) {
      throw Exception("You didn't load the flashcard in the stat record");
    }

    // try to update fcp_data document
    final updateDto = UpdateFcpDataDto(hasBookmark: true);
    final updateResult = await _fcpService.updateDocument(
      _getUid(),
      record.flashcardId,
      updateDto.toJson(),
    );
    switch (updateResult) {
      case Ok<void>():
        _updateCacheForBookmark(record, record.packId);
        return Result.ok(null);
      case Error<void>():
    }

    final error = updateResult.error;
    if (!isErrorNotFound(error)) {
      return Result.error(error);
    }

    // If fcp data document doesn't exist, create it with all of the necessary fields
    final setResult = await _fcpService.setDocument(
      FcpDataDto.fromStatRecord(record, _getUid()).copyWith(hasBookmark: true),
      // FcpDataDto.fromStatRecordWithBookmark(
      //   record,
      //   FlashcardSnapshotDto.fromFlashcard(record.flashcard!),
      //   _getUid(),
      // ),
    );
    switch (setResult) {
      case Error<void>(:final error):
        return Result.error(error);
      case Ok<void>():
    }
    _updateCacheForBookmark(record, record.packId);
    return Result.ok(null);
  }

  Future<Result<void>> removeBookmark({
    required String flashcardId,
    StatRecord? record,
  }) async {
    final uid = _getUid();
    UpdateFcpDataDto updateDto = UpdateFcpDataDto(hasBookmark: false);
    final result = await _fcpService.updateDocument(
      uid,
      flashcardId,
      updateDto.toJson(),
    );
    switch (result) {
      case Error<void>(:final error):
        return Result.error(error);
      case Ok<void>():
    }

    if (record != null) {
      _updateCacheForBookmark(record, record.packId);
    } else {
      _packsCache.invalidate();
    }
    return Result.ok(null);
  }

  Future<Result<void>> unignoreFlashcard({required String flashcardId}) async {
    final uid = _getUid();
    UpdateFcpDataDto updateDto = UpdateFcpDataDto(ignored: false);
    final result = await _fcpService.updateDocument(
      uid,
      flashcardId,
      updateDto.toJson(),
    );
    switch (result) {
      case Error<void>(:final error):
        return Result.error(error);
      case Ok<void>():
    }

    _packsCache.invalidate();
    return Result.ok(null);
  }

  String _getUid() {
    return getCurrentUserAndThrow(
      authService: _authService,
      repoName: "FcpRepository",
    ).uid;
  }

  // tries to update fsrs_card inside document
  // if the document doesn't exist it will create it with all necessary fields
  Future<Result<void>> safeUpdateCard({
    required StatRecord newStatRecord,
    required StatRecord currStatRecord,
    Rating? rating,
  }) async {
    // A card studied for the first time has no progress document yet, so it
    // is written in one go instead of waiting for an update to fail first.
    if (!currStatRecord.isPulledFromDb && newStatRecord.flashcard != null) {
      final result = await _fcpService.setDocument(
        FcpDataDto.fromStatRecord(newStatRecord, _getUid()),
        merge: true,
      );
      switch (result) {
        case Error<void>(:final error):
          return Result.error(error);
        case Ok<void>():
      }
      _rememberSeen(currStatRecord);
      _updateCacheForRatingGiven(
        currStatRecord,
        newStatRecord.card,
        currStatRecord.packId,
      );
      _recordReview(currStatRecord, newStatRecord.card, rating);
      return Result.ok(null);
    }

    // try to update a card, but only update the card object in document
    final updateDto = UpdateFcpDataDto(fsrsCard: newStatRecord.card);
    final updateResult = await _fcpService.updateDocument(
      _getUid(),
      newStatRecord.flashcardId,
      updateDto.toJson(),
    );
    switch (updateResult) {
      case Ok<void>():
        _updateCacheForRatingGiven(
          currStatRecord,
          newStatRecord.card,
          currStatRecord.packId,
        );
        _recordReview(currStatRecord, newStatRecord.card, rating);
        return Result.ok(null);
      case Error<void>():
    }
    final error = updateResult.error;

    if (!isErrorNotFound(error)) {
      return Result.error(error);
    }

    // if the document doesn't exist, create it with card object and all other fields
    final result = await _fcpService.setDocument(
      FcpDataDto.fromStatRecord(newStatRecord, _getUid()),
    );
    switch (result) {
      case Error<void>(:final error):
        return Result.error(error);
      case Ok<void>():
    }
    _rememberSeen(currStatRecord);

    _updateCacheForRatingGiven(
      currStatRecord,
      newStatRecord.card,
      currStatRecord.packId,
    );
    _recordReview(currStatRecord, newStatRecord.card, rating);
    return Result.ok(null);
  }

  /// The cards of the pack the user has studied, from the device when its
  /// list matches the server's count, otherwise read again from the server.
  Future<Result<Set<String>>> _seenFlashcardIds({
    required String uid,
    required String packId,
    required int serverCount,
    required bool hasCards,
  }) async {
    final saved = await _seenCards.load(uid, packId);
    if (saved != null && saved.length == serverCount) return Result.ok(saved);
    final result = await _fcpService.getSeenFlashcardIdsForPack(
      uid,
      packId,
      hasCards,
    );
    if (result case Ok<Set<String>>(:final value)) {
      await _seenCards.save(uid, packId, value);
    }
    return result;
  }

  void _rememberSeen(StatRecord record) {
    _seenCards.add(_getUid(), record.packId, record.flashcardId);
  }

  /// Keeps the daily history shown on the Progress tab.
  /// Also gives XP and goal milestones through [StudyRewards].
  void _recordReview(StatRecord record, Card after, Rating? rating) {
    final before = record.card;
    final isNew = before.state == State.newState || before.reps == 0;
    final forgot = after.lapses > before.lapses;
    final rewards = _rewards;
    if (rewards != null) {
      rewards.recordReview(
        packId: record.packId,
        isNew: isNew,
        forgot: forgot,
        rating: rating,
      );
      return;
    }
    _studyLog?.update(
      (log) =>
          log.recordReview(now: DateTime.now(), isNew: isNew, forgot: forgot),
    );
  }

  List<int> _calculateSeenAndNewCount(
    int all,
    int seen,
    int due,
    int target,
    double newCardsPercentage,
  ) {
    if (all < 0 || seen < 0 || target < 0 || seen > all || due > seen) {
      throw Exception("Invalid values for either all, seen, due or target");
    }
    if (newCardsPercentage > 1 || newCardsPercentage < 0) {
      throw Exception("Percentage must be between 0 and 1");
    }
    if (target > all) target = all;

    double dueCardsPercentage = 1 - newCardsPercentage;
    int dueCount = due, newCount = 0;
    int availableNew = all - seen, availableDue = 0;

    // cut down due cards if we have too many
    if (due > target * dueCardsPercentage) {
      dueCount = (target * dueCardsPercentage).round();
      availableDue = due - dueCount;
    }

    // if I have enough available new cards, then get the rest of the new cards
    if (target - dueCount <= availableNew) {
      newCount = target - dueCount;
    }
    // If I don't have enough, get all available new cards, the rest get from the remaining available due cards
    else {
      newCount = availableNew;
      final missingCount = target - (dueCount + newCount);
      dueCount += missingCount <= availableDue ? missingCount : availableDue;
    }

    print("[CALCULATION]");
    print("Target: $target");
    print("All cards: $all, seen cards: $seen, due cards pulled from db: $due");
    print(
      "Available new cards: $availableNew, available due cards (before): $availableDue",
    );
    print("new count $newCount, dueCount $dueCount");

    return [newCount, dueCount];
  }

  // packs cache operations
  void _updateCacheForIgnore(StatRecord currStatRecord, String packId) {
    final cardState = currStatRecord.card.state;
    if (cardState.isNewState && !currStatRecord.isPulledFromDb) {
      _packsCache.updateItem(
        id: packId,
        copyWith: (pack) => pack.copyWith(
          newCount: pack.newCount != 0 ? pack.newCount - 1 : pack.newCount,
        ),
      );
      return;
    }

    if (!cardState.isNewState) {
      _packsCache.updateItem(
        id: packId,
        copyWith: (pack) => pack.copyWith(
          dueCount: pack.dueCount - 1,
          learningCount:
              (cardState.isLearning || cardState.isRelearning) &&
                  pack.learningCount > 0
              ? pack.learningCount - 1
              : pack.learningCount,
        ),
      );
    }
  }

  // update count in packs cache
  // we check if the state is new, that fcp_data doc is not created
  // and it will be created when we bookmark the card, and the initial fsrs state
  // is newState. When doc is created the dueCount will get incremented as well as
  // newCount will get decremented
  void _updateCacheForBookmark(StatRecord currStatRecord, String packId) {
    if (currStatRecord.hasBookmark ||
        !currStatRecord.card.state.isNewState ||
        currStatRecord.isPulledFromDb) {
      return;
    }

    _packsCache.updateItem(
      id: packId,
      copyWith: (pack) => pack.copyWith(
        newCount: pack.newCount != 0 ? pack.newCount - 1 : pack.newCount,
      ),
    );
  }

  // new stat record is the stat record with updated card object after the
  // rating has been given
  void _updateCacheForRatingGiven(
    StatRecord currStatRecord,
    Card newCard,
    String packId,
  ) {
    final currCard = currStatRecord.card;

    _packsCache.updateItem(
      id: packId,
      copyWith: (pack) {
        final wasLearning =
            currCard.state.isLearning || currCard.state.isRelearning;
        final isLearning =
            newCard.state.isLearning || newCard.state.isRelearning;
        final wasReviewOrNew =
            currCard.state.isReview || currCard.state.isNewState;
        final isNowReview = newCard.state.isReview || newCard.state.isNewState;
        final isFromDb = currStatRecord.isPulledFromDb;

        final bool shouldDecrementDue =
            pack.dueCount > 0 &&
            isFromDb &&
            !currStatRecord.card.state.isNewState;
        print(shouldDecrementDue);
        final bool shouldDecrementNew = pack.newCount > 0 && !isFromDb;

        int newLearningCount = pack.learningCount;
        if (wasReviewOrNew && isLearning) {
          newLearningCount += 1;
        } else if (wasLearning && isNowReview) {
          newLearningCount = (newLearningCount - 1).clamp(0, newLearningCount);
        }

        return pack.copyWith(
          dueCount: shouldDecrementDue ? pack.dueCount - 1 : pack.dueCount,
          newCount: shouldDecrementNew ? pack.newCount - 1 : pack.newCount,
          learningCount: newLearningCount,
        );
      },
    );
  }
}

class _PackPieces {
  final List<String> flashcardIds;
  final List<StatRecord> due;
  final Set<String> seenIds;

  const _PackPieces(this.flashcardIds, this.due, this.seenIds);
}
