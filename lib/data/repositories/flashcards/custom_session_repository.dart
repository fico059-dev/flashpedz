import 'package:flashcards/data/repositories/utils/pagination/paginated_cursor_map.dart';
import 'package:flashcards/data/services/api/dto/flashcards/custom_session/custom_session_dto.dart';
import 'package:flashcards/data/services/api/dto/flashcards/custom_session/custom_session_patch/custom_session_patch_dto.dart';
import 'package:flashcards/data/services/api/dto/flashcards/custom_session/flashcard_ids/flashcard_ids_dto.dart';
import 'package:flashcards/data/utils/data_utils.dart';
import 'package:flashcards/data/services/api/dto/requests/create_custom_session/create_custom_session_request_dto.dart';
import 'package:flashcards/data/services/api/flashcards/custom_session_service.dart';
import 'package:flashcards/data/services/api/users/auth_service.dart';
import 'package:flashcards/domain/enums/pack_selected_filter.dart';
import 'package:flashcards/domain/models/flashcards/custom_session/custom_session.dart';
import 'package:flashcards/domain/models/flashcards/custom_session_summary/custom_session_summary.dart';
import 'package:flashcards/utils/result.dart';

class CustomSessionRepository {
  final CustomSessionService _customSessionService;
  final AuthService _authService;
  final PaginatedCursorMap _cursorMap = PaginatedCursorMap();

  CustomSessionRepository({
    required CustomSessionService customSessionService,
    required AuthService authService,
  }) : _customSessionService = customSessionService,
       _authService = authService;

  Future<Result<List<CustomSessionSummary>>> getCustomSessionPage({
    required int pageIndex,
    required int pageSize,
  }) async {
    final lastDoc = _cursorMap.getLastDocFromPrevPage(pageIndex);
    final result = await _customSessionService
        .getCustomSessionForProfilePagination(
          profileId: _getUid(),
          startAfter: lastDoc,
          limit: pageSize,
        );
    switch (result) {
      case Error<PaginatedDtoResult<CustomSessionDto>>(:final error):
        return Result.error(error);
      case Ok<PaginatedDtoResult<CustomSessionDto>>():
    }

    _cursorMap.put(pageIndex, result.value.lastDocument);
    final list = result.value.items
        .map((dto) => dto.toCustomSessionSummary())
        .toList();
    return Result.ok(list);
  }

  Future<Result<CustomSession>> getCustomSessionFlashcardIds({
    required CustomSessionSummary sessionSummary,
  }) async {
    final result = await _customSessionService.getFlashcardIdsForCustomSession(
      sessionSummary.id,
    );
    switch (result) {
      case Error<FlashcardIdsDto>(:final error):
        return Result.error(error);
      case Ok<FlashcardIdsDto>():
    }

    final customSession = CustomSession(
      id: sessionSummary.id,
      flashcardIds: result.value.flashcardIds,
      currentIndex: sessionSummary.currentIndex,
      cardCount: sessionSummary.cardCount,
      correctCount: sessionSummary.correctCount,
    );

    return Result.ok(customSession);
  }

  Future<Result<void>> createCustomSession({
    required int sessionSize,
    required PackSelectedFilter filter,
    required List<String> tags,
    required List<String> packIds,
    String? name,
    List<String> topics = const [],
    List<String> excludeTags = const [],
  }) async {
    final request = CreateCustomSessionRequestDto(
      profileId: _getUid(),
      filter: filter,
      tags: tags,
      packIds: packIds,
      sessionSize: sessionSize,
      name: name,
    );
    return await _customSessionService.createCustomSession(
      request,
      topics: topics,
      excludeTags: excludeTags,
    );
  }

  Future<Result<void>> answeredCorrect(String sessionId) async {
    return await _customSessionService.incrementCurrentIndexAndCorrectCount(
      sessionId: sessionId,
      currentIndexIncrement: 1,
      rightIncrement: 1,
    );
  }

  Future<Result<void>> answeredWrong(String sessionId) async {
    return await _customSessionService.incrementCurrentIndex(
      sessionId: sessionId,
      increment: 1,
    );
  }

  Future<Result<void>> resetSessionProgress(String sessionId) async {
    final dto = CustomSessionPatchDto(currentIndex: 0, correctCount: 0);
    return await _customSessionService.patchCustomSession(
      sessionId: sessionId,
      dto: dto,
    );
  }

  /// Sets where the session is, e.g. back one card when an answer is
  /// undone.
  Future<Result<void>> setSessionProgress(
    String sessionId, {
    required int currentIndex,
    required int correctCount,
  }) {
    return _customSessionService.patchCustomSession(
      sessionId: sessionId,
      dto: CustomSessionPatchDto(
        currentIndex: currentIndex,
        correctCount: correctCount,
      ),
    );
  }

  /// Returns the name that was saved.
  Future<Result<String>> renameSession(String sessionId, String name) {
    return _customSessionService.renameCustomSession(
      sessionId: sessionId,
      name: name,
    );
  }

  Future<Result<void>> deleteSession(String sessionId) async {
    return await _customSessionService.deleteCustomSession(sessionId);
  }

  String _getUid() {
    return getCurrentUserAndThrow(
      authService: _authService,
      repoName: "FcpRepository",
    ).uid;
  }
}
