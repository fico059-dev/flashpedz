import 'package:flashcards/bloc/flashcards/fc_review_getter/fc_review_getter_state.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/domain/models/flashcards/flashcard_review/flashcard_review.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FcReviewGetterCubit extends Cubit<FcReviewGetterState> {
  final FlashcardRepository _fcRepo;
  final FcpRepository _fcpRepo;

  FcReviewGetterCubit({
    required FlashcardRepository fcRepo,
    required FcpRepository fcpRepo,
  }) : _fcRepo = fcRepo,
       _fcpRepo = fcpRepo,
       super(FcReviewGetterInitial());

  /// The reason this function needs question and answer is when showing forbidden content,
  /// Question and answer will be displayed but they will be blur-ed
  void getFlashcardReview({
    required String flashcardId,
    required String question,
    required String answer,
    required bool isPaid,
    required bool hasCards,
    String? packId,
  }) async {
    if (state is! FcReviewGetterInitial) return;

    if (isPaid && !hasCards) {
      emit(FcReviewGetterForbidden(question: question, answer: answer));
      return;
    }

    emit(FcReviewGetterLoading());

    final result = await _fcRepo.getFlashcardReview(
      flashcardId,
      packId: packId,
    );
    switch (result) {
      case Error<FlashcardReview>(:final error):
        emit(FcReviewGetterError(error: error));
        return;
      case Ok<FlashcardReview>():
    }

    emit(FcReviewGetterLoaded(fcReview: result.value));
  }

  void toggleBookmark() async {
    final state = this.state;
    if (state is! FcReviewGetterLoaded) return;

    final record = state.fcReview.record;
    final flashcard = record.flashcard;

    emit(
      state.copyWith(
        fcReview: state.fcReview.copyWith(
          record: record.copyWith(hasBookmark: !record.hasBookmark),
        ),
      ),
    );

    late final Result<void> result;
    if (record.hasBookmark) {
      result = await _fcpRepo.removeBookmark(flashcardId: flashcard!.id);
    } else {
      result = await _fcpRepo.safeAddBookmark(record: record);
    }
    switch (result) {
      case Error<void>(:final error):
        print(error);
        // revert hasBookmark flag
        final review = (this.state as FcReviewGetterLoaded).fcReview;
        emit(
          (this.state as FcReviewGetterLoaded).copyWith(
            fcReview: review.copyWith(record: record),
          ),
        );
        return;
      case Ok<void>():
    }
  }
}
