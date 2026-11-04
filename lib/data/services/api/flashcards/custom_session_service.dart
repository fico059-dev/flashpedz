import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/data/services/api/dto/flashcards/custom_session/custom_session_patch/custom_session_patch_dto.dart';
import 'package:flashcards/data/services/api/dto/flashcards/custom_session/flashcard_ids/flashcard_ids_dto.dart';
import 'package:flashcards/data/utils/data_utils.dart';
import 'package:flashcards/data/remote/firestore_db_context.dart';
import 'package:flashcards/data/services/api/dto/flashcards/custom_session/custom_session_dto.dart';
import 'package:flashcards/data/services/api/dto/requests/create_custom_session/create_custom_session_request_dto.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/utils/typedefs.dart';

class CustomSessionService {
  final CollectionReference<JsonMap> _customSessions;
  final CollectionReference<JsonMap> Function(String sessionId)
  _getFlashcardIdsCollection;
  final WriteBatch Function() _createBatch;
  final CloudFunctionService _functions;

  final String _flashcardIdsDocName;

  CustomSessionService({
    required FirestoreDbContext dbContext,
    required CloudFunctionService cloudFunctionService,
  }) : _customSessions = dbContext.customSessions,
       _functions = cloudFunctionService,
       _getFlashcardIdsCollection = dbContext.getSessionFlashcardIdsCollection,
       _createBatch = dbContext.createBatch,
       _flashcardIdsDocName = dbContext.flashcardIdsDocName;

  Future<Result<PaginatedDtoResult<CustomSessionDto>>>
  getCustomSessionForProfilePagination({
    required String profileId,
    required DocumentSnapshot? startAfter,
    required int limit,
  }) async {
    try {
      // Sessions of "My Sets" are shown with their set, not here. Pages are
      // filled up so the list doesn't look finished early.
      final dtoList = <CustomSessionDto>[];
      DocumentSnapshot<JsonMap>? newest;
      DocumentSnapshot? last = startAfter;
      while (true) {
        final wanted = limit - dtoList.length;
        var query = _customSessions
            .orderBy('createdAt', descending: true)
            .where('profileId', isEqualTo: profileId)
            .limit(wanted);
        if (last != null) query = query.startAfterDocument(last);
        final snapshot = await query.get();
        dtoList.addAll(
          snapshot.docs
              .where((doc) => doc.data()['fromSet'] == null)
              .map(
                (doc) => CustomSessionDto.fromJsonWithId(doc.data(), doc.id),
              ),
        );
        if (snapshot.docs.isNotEmpty) last = newest = snapshot.docs.last;
        // Fewer documents than asked for: there are no more.
        if (snapshot.docs.length < wanted || dtoList.length >= limit) break;
      }

      return Result.ok(
        PaginatedDtoResult(items: dtoList, lastDocument: newest),
      );
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Result<FlashcardIdsDto>> getFlashcardIdsForCustomSession(
    String customSessionId,
  ) async {
    try {
      final ref = _getFlashcardIdsCollection(customSessionId);
      final snapshot = await ref.doc(_flashcardIdsDocName).get();
      if (!snapshot.exists) {
        throw Exception("All_ids document doesn't exist");
      }

      final dto = FlashcardIdsDto.fromJson(snapshot.data()!);

      return Result.ok(dto);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Result<void>> createCustomSession(
    CreateCustomSessionRequestDto request, {
    List<String> topics = const [],
    List<String> excludeTags = const [],
  }) async {
    try {
      await _functions.createCustomSession(
        request,
        topics: topics,
        excludeTags: excludeTags,
      );
      //final data = result.data as List<dynamic>;

      // final snapshots =
      //     data.map((item) => FlashcardSnapshotDto.fromJson(item)).toList();
      return Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Result<String>> renameCustomSession({
    required String sessionId,
    required String name,
  }) async {
    try {
      return Result.ok(
        await _functions.renameCustomSession(sessionId: sessionId, name: name),
      );
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Result<void>> incrementCurrentIndex({
    required String sessionId,
    required int increment,
  }) async {
    try {
      final ref = _customSessions.doc(sessionId);
      await ref.update({"currentIndex": FieldValue.increment(increment)});

      return Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Result<void>> incrementCurrentIndexAndCorrectCount({
    required String sessionId,
    required int currentIndexIncrement,
    required int rightIncrement,
  }) async {
    try {
      final ref = _customSessions.doc(sessionId);
      await ref.update({
        "currentIndex": FieldValue.increment(currentIndexIncrement),
        "correctCount": FieldValue.increment(rightIncrement),
      });

      return Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Result<void>> patchCustomSession({
    required String sessionId,
    required CustomSessionPatchDto dto,
  }) async {
    try {
      final ref = _customSessions.doc(sessionId);
      await ref.update(dto.toJson());

      return Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Result<void>> deleteCustomSession(String sessionId) async {
    try {
      final batch = _createBatch();
      final sessionRef = _customSessions.doc(sessionId);
      final flashcardIdsRef = _getFlashcardIdsCollection(
        sessionId,
      ).doc(_flashcardIdsDocName);

      batch.delete(sessionRef);
      batch.delete(flashcardIdsRef);
      await batch.commit();

      return Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }
}
