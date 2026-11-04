import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_tag_picker_state.freezed.dart';

/// In [SessionTagPickerLoaded.selectedTags] a tag set to true is required
/// (topics: one of the chosen topics is required) and a tag set to false is
/// excluded.
extension SessionTagPickerStateX on SessionTagPickerState {
  Iterable<String> _ids(bool value, {required bool topics}) {
    final state = this;
    if (state is! SessionTagPickerLoaded) return const [];
    return state.selectedTags.entries
        .where((e) => e.value == value && Tag.fromId(e.key).isTopic == topics)
        .map((e) => e.key);
  }

  /// Tags every card must have.
  List<String> get selectedTagsList => _ids(true, topics: false).toList();

  List<Tag> get selectedTagsObject =>
      selectedTagsList.map((k) => Tag.fromId(k)).toList();

  /// Topics, a card must have one of them.
  List<String> get selectedTopics => _ids(true, topics: true).toList();

  /// Tags (or topics) whose cards are left out.
  List<String> get excludedTags => [
    ..._ids(false, topics: false),
    ..._ids(false, topics: true),
  ];

  /// With nothing chosen every card counts, so the card count is exact.
  /// Otherwise it can only be estimated here.
  bool get isCountExact {
    final state = this;
    return state is! SessionTagPickerLoaded || state.selectedTags.isEmpty;
  }

  /// At most this many cards can match: the count of the rarest required
  /// tag, and of the chosen topics together. Null when nothing limits it.
  int? get maxCardsWithAllTags {
    final state = this;
    if (state is! SessionTagPickerLoaded) return null;
    final required = selectedTagsList.toSet();
    final topics = selectedTopics.toSet();
    if (required.isEmpty && topics.isEmpty) return null;
    int? result;
    var topicSum = 0;
    state.allTagCounts.forEach((tag, count) {
      if (topics.contains(tag.id)) topicSum += count;
      if (!required.contains(tag.id)) return;
      if (result == null || count < result!) result = count;
    });
    if (topics.isNotEmpty && (result == null || topicSum < result!)) {
      result = topicSum;
    }
    return result ?? 0;
  }
}

@freezed
sealed class SessionTagPickerState with _$SessionTagPickerState {
  const factory SessionTagPickerState.initial() = SessionTagPickerInitial;

  const factory SessionTagPickerState.loaded({
    required bool? firstOptionChecked,
    required Map<Tag, int> allTagCounts,
    required Map<String, bool> selectedTags,
  }) = SessionTagPickerLoaded;
}
