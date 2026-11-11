import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/data/remote/cloud_storage_service.dart';
import 'package:flashcards/data/services/api/exceptions/document_doesnt_exist_exception.dart';
import 'package:flashcards/data/utils/data_utils.dart';
import 'package:flashcards/data/remote/firestore_db_context.dart';
import 'package:flashcards/data/services/api/dto/flashcards/flashcard/flashcard_dto.dart';
import 'package:flashcards/domain/models/core/picked_image.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/utils/typedefs.dart';

class FlashcardService {
  final CollectionReference<JsonMap> _flashcards;

  final CloudFunctionService _functions;
  final Reference Function(String flashcardId) _getQuestionImageRef;
  final Reference Function(String flashcardId) _getAnswerImageRef;

  FlashcardService({
    required FirestoreDbContext dbContext,
    required CloudFunctionService functions,
    required CloudStorageService storage,
  }) : _flashcards = dbContext.flashcards,
       _functions = functions,
       _getQuestionImageRef = storage.getFlashcardQuestionImageRef,
       _getAnswerImageRef = storage.getFlashcardAnswerImageRef;

  Future<Result<String>> uploadQuestionImageAndGetUrl({
    required String flashcardId,
    required PickedImage image,
  }) async {
    try {
      final questionRef = _getQuestionImageRef(flashcardId);
      if (image.file != null) {
        await questionRef.putFile(image.file!);
      } else {
        await questionRef.putData(image.bytes!);
      }
      final url = await questionRef.getDownloadURL();

      return Result.ok(url);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Result<String>> uploadAnswerImageAndGetUrl({
    required String flashcardId,
    required PickedImage image,
  }) async {
    try {
      final questionRef = _getAnswerImageRef(flashcardId);
      if (image.file != null) {
        await questionRef.putFile(image.file!);
      } else {
        await questionRef.putData(image.bytes!);
      }
      final url = await questionRef.getDownloadURL();

      return Result.ok(url);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  DocumentReference<JsonMap> createDocumentReference() {
    FirebaseFirestore.instance.collectionGroup('flashcards');
    return _flashcards.doc();
  }

  DocumentReference<JsonMap> getDocumentReference(String flashcardId) {
    return _flashcards.doc(flashcardId);
  }

  Future<Result<PaginatedDtoResult<FlashcardDto>>>
  getDocumentsByPackIdPagination({
    required String packId,
    required int limit,
    required DocumentSnapshot? startAfter,
  }) async {
    try {
      var query = _flashcards
          .where('packId', isEqualTo: packId)
          .orderBy('question')
          .limit(limit);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();
      final dtoList = snapshot.docs
          .map((doc) => FlashcardDto.fromJsonWithId(doc.data(), doc.id))
          .toList();

      return Result.ok(
        PaginatedDtoResult(
          items: dtoList,
          lastDocument: getLastDocFromSnapshot(snapshot),
        ),
      );
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Stream<Result<List<FlashcardDto>>> getDocumentsByPackIdStream(
    String packId,
  ) async* {
    try {
      final query = _flashcards.where('packId', isEqualTo: packId);
      await for (final snapshot in query.snapshots()) {
        final flashcards = snapshot.docs
            .map((doc) => FlashcardDto.fromJsonWithId(doc.data(), doc.id))
            .toList();
        yield Result.ok(flashcards);
      }
    } on Exception catch (error) {
      yield Result.error(error);
    }
  }

  Future<Result<FlashcardDto>> getDocument(String flashcardId) async {
    try {
      final snapshot = await _flashcards.doc(flashcardId).get();
      if (!snapshot.exists) {
        return Result.error(DocumentDoesntExistException());
      }
      return Result.ok(
        FlashcardDto.fromJsonWithId(snapshot.data()!, snapshot.id),
      );
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Result<void>> deleteFlashcardEverywhere(
    FlashcardDto flashcardDto,
  ) async {
    try {
      await _functions.deleteFlashcardEverywhere(flashcardDto);

      return Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  Future<Result<void>> updateFlashcardEverywhere({
    required String flashcardId,
    required JsonMap partialJson,
    required shouldDeleteAnswer,
    required shouldDeleteQuestion,
    Uint8List? answerImageBytes,
    Uint8List? questionImageBytes,
  }) async {
    try {
      await _functions.updateFlashcardEverywhere(
        shouldDeleteQuestion: shouldDeleteQuestion,
        shouldDeleteAnswer: shouldDeleteAnswer,
        flashcardId: flashcardId,
        partialJson: partialJson,
        answerImageBytes: answerImageBytes,
        questionImageBytes: questionImageBytes,
      );

      return Result.ok(null);
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  /// Adds and removes tags on many cards in one request (at most 400).
  /// Returns the ids of the cards that changed.
  Future<List<String>> bulkUpdateCardTags({
    required List<String> flashcardIds,
    List<String> addTags = const [],
    List<String> removeTags = const [],
  }) => _functions.bulkUpdateCardTags(
    flashcardIds: flashcardIds,
    addTags: addTags,
    removeTags: removeTags,
  );

  /// Returns the question of every flashcard in the pack.
  Future<Result<Set<String>>> getQuestionsInPack(String packId) async {
    try {
      final snapshot = await _flashcards
          .where('packId', isEqualTo: packId)
          .get();
      return Result.ok(
        snapshot.docs.map((doc) => doc.data()['question'] as String).toSet(),
      );
    } on Exception catch (error) {
      return Result.error(error);
    }
  }

  void setDocumentInTransaction({
    required DocumentReference<JsonMap> documentReference,
    required FlashcardDto dto,
    required Transaction transaction,
  }) {
    transaction.set(documentReference, dto.toJson());
  }
}
