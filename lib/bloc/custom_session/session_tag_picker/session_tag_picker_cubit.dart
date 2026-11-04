import 'package:flashcards/bloc/custom_session/session_tag_picker/session_tag_picker_state.dart';
import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/domain/models/flashcards/simple_pack/simple_pack.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SessionTagPickerCubit extends Cubit<SessionTagPickerState> {
  SessionTagPickerCubit() : super(SessionTagPickerInitial());

  /// Tags are listed A to Z and none are selected, which means every card.
  void loadAllTags(List<SimplePack> packs) {
    final allTagCounts = sortTagsByName(packs.tagCountsConverted);
    const selectedTags = <String, bool>{};

    emit(
      SessionTagPickerState.loaded(
        allTagCounts: allTagCounts,
        selectedTags: selectedTags,
        firstOptionChecked: _getFirstOptionState(
          allTagCounts: allTagCounts,
          selectedTags: selectedTags,
        ),
      ),
    );
  }

  void toggleTag(Tag tag) {
    final state = this.state;
    if (state is! SessionTagPickerLoaded) {
      return;
    }

    final isSelected = _isSelected(tag);

    //if (!isSelected && state.selectedTags.length >= _selectionLimit) return;

    Map<String, bool> newMap;
    if (isSelected) {
      newMap = deleteMapEntry(state.selectedTags, tag.id);
    } else {
      newMap = updateMapEntry(state.selectedTags, tag.id, !isSelected);
    }

    emit(
      state.copyWith(
        selectedTags: newMap,
        firstOptionChecked: _getFirstOptionState(
          allTagCounts: state.allTagCounts,
          selectedTags: newMap,
        ),
      ),
    );
  }

  /// Leaves out the cards with [tag], or stops leaving them out.
  void toggleExcluded(Tag tag) {
    final state = this.state;
    if (state is! SessionTagPickerLoaded) return;

    final excluded = state.selectedTags[tag.id] == false;
    final newMap = excluded
        ? deleteMapEntry(state.selectedTags, tag.id)
        : updateMapEntry(state.selectedTags, tag.id, false);
    emit(
      state.copyWith(
        selectedTags: newMap,
        firstOptionChecked: _getFirstOptionState(
          allTagCounts: state.allTagCounts,
          selectedTags: newMap,
        ),
      ),
    );
  }

  /// Back to no tag filter, so every card can be in the session.
  void clearSelection() {
    final state = this.state;
    if (state is! SessionTagPickerLoaded) return;

    emit(
      state.copyWith(
        selectedTags: {},
        firstOptionChecked: _getFirstOptionState(
          allTagCounts: state.allTagCounts,
          selectedTags: {},
        ),
      ),
    );
  }

  bool _isSelected(Tag tag) {
    final state = this.state;
    if (state is! SessionTagPickerLoaded) {
      throw Exception("You can't use this function if the tags are not loaded");
    }

    return state.selectedTags[tag.id] == true;
  }

  bool? _getFirstOptionState({
    required Map<Tag, int> allTagCounts,
    required Map<String, bool> selectedTags,
  }) {
    // if (selectedTags.length >= _selectionLimit ||
    //     selectedTags.length == allTagCounts.length) {
    //   return true;
    // }
    if (selectedTags.length == allTagCounts.length) {
      return true;
    }

    if (selectedTags.isNotEmpty) return null;
    return false;
  }
}

/// Returns [tagCounts] ordered alphabetically by tag name.
Map<Tag, int> sortTagsByName(Map<Tag, int> tagCounts) {
  final entries = tagCounts.entries.toList()
    ..sort((a, b) {
      final byName = a.key.name.toLowerCase().compareTo(
        b.key.name.toLowerCase(),
      );
      return byName != 0 ? byName : a.key.id.compareTo(b.key.id);
    });
  return Map.fromEntries(entries);
}
