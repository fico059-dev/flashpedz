import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/custom_session/pack_filter/pack_filter_bloc.dart';
import 'package:flashcards/bloc/custom_session/pack_filter/pack_filter_state.dart';
import 'package:flashcards/bloc/custom_session/pack_picker/pack_picker_bloc.dart';
import 'package:flashcards/bloc/custom_session/pack_picker/pack_picker_state.dart';
import 'package:flashcards/bloc/custom_session/session_tag_picker/session_tag_picker_cubit.dart';
import 'package:flashcards/bloc/custom_session/session_tag_picker/session_tag_picker_state.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/domain/enums/pack_selected_filter.dart';
import 'package:flashcards/domain/models/flashcards/flashcard_filter_counts/pack_filter_counts.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flashcards/bloc/custom_session/studied_filter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:percent_indicator/flutter_percent_indicator.dart';

class CustomSessionBottomNavigationBar extends StatelessWidget {
  final int stepIndex;

  const CustomSessionBottomNavigationBar({super.key, required this.stepIndex});

  static const _stepCount = 4;

  @override
  Widget build(BuildContext context) {
    // pack picker state
    final pickerState = context.watch<PackPickerBloc>().state;
    final selectedCount = pickerState.selectedCount;
    final selectedPackIds = pickerState.selectedPacksIds;
    final selectedPacks = pickerState.selectedPacks;
    final allCount = pickerState.flashcardSum;

    // filter state
    final filterState = context.watch<PackFilterBloc>().state;
    final isFilterLoaded = filterState is PackFilterLoaded;
    final packFilterCounts = isFilterLoaded
        ? filterState.packFilterCounts
        : PackFilterCounts(
            allCount: -1,
            seenCount: -1,
            bookmarkedCount: -1,
            ignoredCount: -1,
          );
    final selectedFilter = isFilterLoaded
        ? filterState.selectedFilter
        : PackSelectedFilter.all;

    // tag picker state
    final tagPickerState = context.watch<SessionTagPickerCubit>().state;
    final areTagsLoaded = tagPickerState is SessionTagPickerLoaded;
    final List<String> selectedTags = areTagsLoaded
        ? tagPickerState.selectedTagsList
        : [];

    final nextEnabled = switch (stepIndex) {
      0 => selectedCount > 0 && selectedCount <= PackPickerBloc.selectionLimit,
      1 => isFilterLoaded,
      2 => areTagsLoaded,
      3 => false,
      _ => false,
    };

    void pushNextPage() {
      final PageRouteInfo nextRoute = switch (stepIndex) {
        0 => FlashcardsFilterRoute(
          selectedPacks: selectedPackIds,
          allCount: allCount,
        ),
        1 => FlashcardTagSelectionRoute(packs: selectedPacks),
        2 => FlashcardLimitRoute(
          filter: selectedFilter,
          packFilterCount: _estimateCount(
            packFilterCounts.getCountForFilter(selectedFilter),
            tagPickerState.maxCardsWithAllTags,
          ),
          isCountExact:
              tagPickerState.isCountExact &&
              (selectedFilter != PackSelectedFilter.seen ||
                  context.read<StudiedFilterNotifier>().value ==
                      StudiedCardsFilter.all),
          selectedPacks: selectedPacks,
          selectedTags: tagPickerState.selectedTagsObject,
        ),
        int() => throw UnimplementedError(),
      };

      context.router
          .innerRouterOf<StackRouter>(CustomSessionWrapperRoute.name)
          ?.push(nextRoute);
    }

    void popChildRoute() {
      context.router
          .innerRouterOf<StackRouter>(CustomSessionWrapperRoute.name)
          ?.pop();
    }

    return Align(
      heightFactor: 1,
      child: Container(
        padding: EdgeInsets.only(bottom: 35, top: 20),
        color: context.colors.surfaceContainer,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearPercentIndicator(
              percent: (stepIndex + 1) / _stepCount,
              backgroundColor: context.colors.surfaceContainerHighest,
              progressColor: context.colors.primary,
              padding: EdgeInsets.zero,
              animateFromLastPercent: true,
              animateToInitialPercent: true,
              animation: true,
              curve: Curves.easeInOut,
              animationDuration: 250,
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: stepIndex > 0 ? popChildRoute : null,
                    child: Text("Previous"),
                  ),
                  FilledButton(
                    onPressed: nextEnabled ? pushNextPage : null,
                    child: Text("Next"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

int _estimateCount(int filterCount, int? maxCardsWithAllTags) =>
    maxCardsWithAllTags == null || maxCardsWithAllTags > filterCount
    ? filterCount
    : maxCardsWithAllTags;
