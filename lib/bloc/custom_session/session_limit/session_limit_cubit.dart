import 'package:flashcards/bloc/custom_session/session_limit/session_limit_state.dart';
import 'package:flashcards/data/repositories/flashcards/custom_session_repository.dart';
import 'package:flashcards/domain/enums/pack_selected_filter.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/utils/form_validations.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SessionLimitCubit extends Cubit<SessionLimitState> {
  final CustomSessionRepository _customSessionRepo;

  SessionLimitCubit({required CustomSessionRepository customSessionRepo})
    : _customSessionRepo = customSessionRepo,
      super(SessionLimitInitial());

  void loadData({
    required bool isCountExact,
    required int packFilterCount,
    required List<Tag> selectedTags,
    required List<String> selectedPackNames,
    required PackSelectedFilter filter,
  }) {
    emit(
      SessionLimitLoaded(
        flashcardsCount: packFilterCount,
        isEstimatePrecise: isCountExact,
        selectedTags: selectedTags,
        selectedPacks: selectedPackNames,
        selectedFilter: filter,
      ),
    );
  }

  void submitCustomSession({
    required String flashcardsCount,
    required int packFilterCount,
    required PackSelectedFilter filter,
    required List<String> selectedTags,
    required List<String> packIds,
    String? name,
    List<String> topics = const [],
    List<String> excludeTags = const [],
  }) async {
    final state = this.state;
    if (state is! SessionLimitLoaded) return;

    final errors = _validateInput(flashcardsCount, packFilterCount);
    if (errors.isNotEmpty) {
      emit(
        state.copyWith(
          status: SessionLimitStatus.formInvalid,
          formErrors: errors,
        ),
      );
      return;
    }

    emit(state.copyWith(status: SessionLimitStatus.loading));
    final result = await _customSessionRepo.createCustomSession(
      sessionSize: int.parse(flashcardsCount),
      filter: filter,
      tags: selectedTags,
      packIds: packIds,
      name: name,
      topics: topics,
      excludeTags: excludeTags,
    );
    switch (result) {
      case Error<void>(:final error):
        emit(state.copyWith(status: SessionLimitStatus.error, error: error));
        return;
      case Ok<void>():
    }

    emit(state.copyWith(status: SessionLimitStatus.success));
  }

  Map<String, String> _validateInput(
    String flashcardsCount,
    int packFilterCount,
  ) {
    final Map<String, String> errors = {};

    putErrorIfExists(
      errors,
      'flashcardsCount',
      validateClampedNumber(flashcardsCount, 1, packFilterCount, 1000),
    );

    return errors;
  }
}

/// Name used when the student doesn't type one: the topics, the selected
/// tags, or else the packs, e.g. "Cardiology", "Neoreview + 2025" or
/// "Cardiology, Renal".
String defaultSessionName({
  required List<String> tagNames,
  required List<String> packNames,
  List<String> topicNames = const [],
}) {
  final name = topicNames.isNotEmpty
      ? [topicNames.join(' / '), ...tagNames].join(' + ')
      : tagNames.isNotEmpty
      ? tagNames.join(' + ')
      : packNames.isNotEmpty
      ? packNames.join(', ')
      : 'Custom Session';
  return name.length <= 60 ? name : '${name.substring(0, 57)}...';
}
