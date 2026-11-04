import 'package:flashcards/domain/models/flashcards/simple_pack/simple_pack.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

part 'pack_picker_state.freezed.dart';

extension PackPickerStateX on PackPickerState {
  List<String> get selectedPacksIds => selectedPacksMap.entries
      .where((e) => e.value)
      .map((e) => e.key.packId)
      .toList();

  List<String> get selectedPacksNames => selectedPacksMap.entries
      .where((e) => e.value)
      .map((e) => e.key.packName)
      .toList();

  List<SimplePack> get selectedPacks =>
      selectedPacksMap.entries.where((e) => e.value).map((e) => e.key).toList();
}

@freezed
abstract class PackPickerState with _$PackPickerState {
  const factory PackPickerState({
    required PagingState<int, SimplePack> pagingState,
    @Default({}) Map<SimplePack, bool> selectedPacksMap,
    @Default(0) flashcardSum,
    @Default(0) int selectedCount,
    bool? hasCards,
  }) = _PackPickerState;
}
