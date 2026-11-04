import 'package:flashcards/bloc/custom_session/pack_picker/pack_picker_event.dart';
import 'package:flashcards/bloc/custom_session/pack_picker/pack_picker_state.dart';
import 'package:flashcards/bloc/utils/utils.dart';
import 'package:flashcards/data/repositories/flashcards/pack_repository.dart';
import 'package:flashcards/data/repositories/utils/user_claims.dart';
import 'package:flashcards/domain/models/flashcards/simple_pack/simple_pack.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class PackPickerBloc extends Bloc<PackPickerEvent, PackPickerState> {
  final PackRepository _packRepo;
  final int _pageSize = 20;
  bool _isFirstLoad = true;
  static const int selectionLimit = 30;

  PackPickerBloc({required PackRepository packRepo})
    : _packRepo = packRepo,
      super(PackPickerState(pagingState: PagingState(hasNextPage: false))) {
    on<PackPickerPageFetched>(
      _onPageFetched,
      transformer: throttleDroppable(throttleDuration),
    );
    //on<PackPickerCacheRead>(_onCacheRead);
    on<PackPickerRefresh>(_onRefresh);
    on<PackPickerPackToggled>(_onPackToggled);
  }

  void _onRefresh(
    PackPickerRefresh event,
    Emitter<PackPickerState> emit,
  ) async {
    final pagingState = state.pagingState;
    if (pagingState.isLoading) {
      event.completer?.completeError(
        Exception(
          "Still loading more content. Please try refreshing again shortly.",
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        pagingState: pagingState.copyWith(
          isLoading: true,
          hasNextPage: false,
          error: null,
        ),
      ),
    );

    final newKey = getNewKey(null);
    final result = await _packRepo.refreshAdminPacksAndFetchFirstPage(
      pageSize: _pageSize,
      firstPageIndex: newKey,
    );
    switch (result) {
      case Error<List<SimplePack>>(:final error):
        event.completer?.completeError(error);
        emit(state.copyWith(pagingState: pagingState.copyWith(error: error)));
        return;
      case Ok<List<SimplePack>>():
    }
    final newItems = result.value;

    emit(
      state.copyWith(
        selectedPacksMap: {},
        selectedCount: 0,
        flashcardSum: 0,
        pagingState: pagingState.copyWith(
          isLoading: false,
          hasNextPage: !calcIsLastPage(newItems),
          pages: [newItems],
          keys: [newKey],
        ),
      ),
    );
    event.completer?.complete();
  }

  void fetchNextPage() {
    // if (_isFirstLoad) {
    //   add(PackPickerCacheRead());
    //   _isFirstLoad = false;
    // } else {
    //   add(PackPickerPageFetched());
    // }
    add(PackPickerPageFetched());
  }

  // void _onCacheRead(PackPickerCacheRead event, Emitter<PackPickerState> emit) {
  //   final pagingState = state.pagingState;
  //   if (pagingState.isLoading) return;
  //   emit(state.copyWith(pagingState: pagingState.copyWith(isLoading: true)));
  //
  //   List<List<SimplePack>>? pages;
  //   List<int>? keys;
  //   List<SimplePack>? newItems;
  //   while (true) {
  //     final newKey = getNewKey(keys);
  //     newItems = _packRepo.getAdminPackPageFromCache(newKey);
  //     if (newItems == null) break;
  //
  //     pages = [...?pages, newItems];
  //     keys = [...?keys, newKey];
  //   }
  //
  //   emit(
  //     state.copyWith(
  //       pagingState: pagingState.copyWith(
  //         hasNextPage: true,
  //         keys: keys,
  //         pages: pages,
  //         isLoading: false,
  //         error: null,
  //       ),
  //     ),
  //   );
  // }

  void _onPageFetched(
    PackPickerPageFetched event,
    Emitter<PackPickerState> emit,
  ) async {
    final pagingState = state.pagingState;
    if (pagingState.isLoading) return;

    emit(
      state.copyWith(
        pagingState: pagingState.copyWith(isLoading: true, error: null),
      ),
    );

    if (state.hasCards == null) {
      final claims = await UserClaims.current();
      emit(state.copyWith(hasCards: claims.hasCards));
    }

    final newKey = getNewKey(pagingState.keys);
    final result = await _packRepo.getAvailablePacksPage(
      hasCards: state.hasCards,
      pageIndex: newKey,
      pageSize: _pageSize,
    );
    switch (result) {
      case Error<List<SimplePack>>(:final error):
        emit(state.copyWith(pagingState: pagingState.copyWith(error: error)));
        return;
      case Ok<List<SimplePack>>():
    }
    final items = result.value;

    emit(
      state.copyWith(
        pagingState: pagingState.copyWith(
          keys: [...?pagingState.keys, newKey],
          isLoading: false,
          pages: [...?pagingState.pages, items],
          hasNextPage: !calcIsLastPage(items),
        ),
      ),
    );
  }

  void _onPackToggled(
    PackPickerPackToggled event,
    Emitter<PackPickerState> emit,
  ) {
    if (state.pagingState.isLoading) return;
    final pack = event.pack;
    final fcCount = event.pack.flashcardsCount;
    final isSelected = _isSelected(pack);

    if (!isSelected && state.selectedCount >= selectionLimit) return;

    final updatedMap = updateMapEntry(
      state.selectedPacksMap,
      pack,
      !isSelected,
    );

    emit(
      state.copyWith(
        selectedPacksMap: updatedMap,
        selectedCount: isSelected
            ? state.selectedCount - 1
            : state.selectedCount + 1,
        flashcardSum: isSelected
            ? state.flashcardSum - fcCount
            : state.flashcardSum + fcCount,
      ),
    );
  }

  bool _isSelected(SimplePack pack) => state.selectedPacksMap[pack] == true;
}
