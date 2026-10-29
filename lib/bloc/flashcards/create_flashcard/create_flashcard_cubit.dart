import 'package:flashcards/bloc/flashcards/create_flashcard/create_flashcard_state.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/tag_repository.dart';
import 'package:flashcards/domain/models/core/image_data_wrapper.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/utils/form_validations.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateFlashcardCubit extends Cubit<CreateFlashcardState> {
  final FlashcardRepository _flashcardRepo;
  final TagRepository _tagRepo;

  CreateFlashcardCubit({
    required FlashcardRepository flashcardRepo,
    required TagRepository tagRepo,
  }) : _flashcardRepo = flashcardRepo,
       _tagRepo = tagRepo,
       super(CreateFlashcardState());

  /// It's used when previewing the flashcard, since the flashcard actually doesn't
  /// exists, we need to generate it
  Flashcard? generateFlashcardObject(
    String question,
    String answer,
    String packId,
  ) {
    if (state.allAvailableTags == null) {
      throw Exception("Tags not loaded when submitting flashcard");
    }

    final errors = _validateForm(question, answer);
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          formErrors: errors,
          status: CreateFlashcardStatus.formInvalid,
        ),
      );
      return null;
    }

    final fc = Flashcard(
      id: "",
      packId: packId,
      question: question,
      answer: answer,
      tags: state.selectedTags,
      isPaid: false,
    );

    return fc;
  }

  void questionImageChanged(ImageDataWrapper questionImageData) {
    emit(state.copyWith(questionImageData: questionImageData));
  }

  void answerImageChanged(ImageDataWrapper answerImageData) {
    emit(state.copyWith(answerImageData: answerImageData));
  }

  void addTag(Tag tag) {
    if (state.selectedTags.length >= 10) {
      emit(
        state.copyWith(
          status: CreateFlashcardStatus.error,
          error: Exception("Max 10 tags"),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: CreateFlashcardStatus.initial,
        selectedTags: [...state.selectedTags, tag],
        error: null,
      ),
    );
  }

  void removeTag(Tag tag) {
    emit(
      state.copyWith(
        status: CreateFlashcardStatus.initial,
        selectedTags: state.selectedTags.where((t) => t != tag).toList(),
        error: null,
      ),
    );
  }

  void getAllAvailableTags() async {
    emit(
      state.copyWith(
        status: CreateFlashcardStatus.tagsLoading,
        error: null,
        formErrors: {},
      ),
    );

    final result = await _tagRepo.getAllTags();
    switch (result) {
      case Error<List<Tag>>(:final error):
        emit(state.copyWith(status: CreateFlashcardStatus.error, error: error));
        return;
      case Ok<List<Tag>>():
    }

    emit(
      state.copyWith(
        status: CreateFlashcardStatus.initial,
        allAvailableTags: result.value,
      ),
    );
  }

  void createFlashcardAndAssignToPack({
    required String question,
    required String answer,
    required String packId,
    required String buttonType,
  }) async {
    if (state.allAvailableTags == null) {
      throw Exception("Tags not loaded when submitting flashcard");
    }

    final errors = _validateForm(question, answer);
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          formErrors: errors,
          status: CreateFlashcardStatus.formInvalid,
        ),
      );
      return;
    }

    late final bool shouldExit;
    if (buttonType == 'main') {
      emit(
        state.copyWith(
          status: CreateFlashcardStatus.loading,
          error: null,
          formErrors: {},
        ),
      );
      shouldExit = false;
    } else if (buttonType == 'secondary') {
      emit(
        state.copyWith(
          status: CreateFlashcardStatus.loading,
          error: null,
          formErrors: {},
        ),
      );
      shouldExit = true;
    } else {
      throw Exception("Button type must either be 'main' or 'secondary'");
    }

    final createResult = await _flashcardRepo.createFlashcardAndAssignToPack(
      answer: answer,
      question: question,
      packId: packId,
      allAvailableTags: state.allAvailableTags!,
      selectedTags: state.selectedTags,
      answerImage: state.answerImageData.pickedImage,
      questionImage: state.questionImageData.pickedImage,
    );
    switch (createResult) {
      case Error<void>(:final error):
        emit(state.copyWith(status: CreateFlashcardStatus.error, error: error));
        return;
      case Ok<void>():
    }

    emit(
      state.copyWith(
        status: CreateFlashcardStatus.success,
        shouldExit: shouldExit,
        answerImageData: ImageDataWrapper(),
        questionImageData: ImageDataWrapper(),
      ),
    );

    getAllAvailableTags();
  }

  /// Makes an image-occlusion card for every box, like Anki: each card asks
  /// about one box (orange) with the others hidden too (grey), and its
  /// answer uncovers that box. Returns how many cards were made.
  Future<Result<int>> createOcclusionCards({
    required String packId,
    required String imageUrl,
    required List<OcclusionMask> masks,
    String prompt = '',
    String extra = '',
  }) async {
    var made = 0;
    for (var i = 0; i < masks.length; i++) {
      final question = [
        if (prompt.trim().isNotEmpty) prompt.trim(),
        occlusionLine(url: imageUrl, masks: masks, target: i),
      ].join('\n');
      final answer = [
        occlusionLine(url: imageUrl, masks: masks, target: i, revealed: true),
        if (extra.trim().isNotEmpty) extra.trim(),
      ].join('\n');
      final result = await _flashcardRepo.createFlashcardAndAssignToPack(
        question: question,
        answer: answer,
        packId: packId,
        allAvailableTags: state.allAvailableTags ?? const [],
        selectedTags: state.selectedTags,
      );
      switch (result) {
        case Error<void>(:final error):
          return Result.error(
            made == 0
                ? error
                : Exception(
                    'Made $made of ${masks.length} cards, then: $error',
                  ),
          );
        case Ok<void>():
          made++;
      }
    }
    getAllAvailableTags();
    return Result.ok(made);
  }

  Map<String, String> _validateForm(String question, String answer) {
    final Map<String, String> errors = {};

    putErrorIfExists(errors, 'question', validateString(question));
    putErrorIfExists(errors, 'answer', validateString(answer));
    return errors;
  }
}
