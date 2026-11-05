import 'package:auto_route/annotations.dart';
import 'package:flashcards/bloc/flashcards/flashcards_searcher/flashcards_searcher_bloc.dart';
import 'package:flashcards/bloc/flashcards/flashcards_searcher/flashcards_searcher_event.dart';
import 'package:flashcards/data/repositories/algolia_search/flashcards_searcher_repository.dart';
import 'package:flashcards/domain/models/algolia/algolia_flashcard/algolia_flashcard.dart';
import 'package:flashcards/ui/dialogs/flashcards/fc_review_bottom_sheet.dart';
import 'package:flashcards/ui/widgets/search/search_page/flashcards_search_page/flashcards_filter_options.dart';
import 'package:flashcards/ui/widgets/search/search_page/flashcards_search_page/flashcards_item_count.dart';
import 'package:flashcards/ui/widgets/search/search_page/flashcards_search_page/flashcards_search_bar.dart';
import 'package:flashcards/ui/widgets/search/search_page/flashcards_search_page/flashcards_search_results.dart';
import 'package:flashcards/ui/widgets/search/search_page/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class FlashcardsSearcherPage extends StatelessWidget {
  const FlashcardsSearcherPage({super.key});

  @override
  Widget build(BuildContext context) {
    void onTap(
      AlgoliaFlashcard flashcard,
      bool hasCards,
      FlashcardsSearcherBloc bloc,
    ) async {
      final result = await showFcReviewBottomSheet(
        context: context,
        flashcardId: flashcard.objectID,
        packId: flashcard.packId,
        question: flashcard.question,
        answer: flashcard.answer,
        isPaid: flashcard.isPaid,
        hasCards: hasCards,
      );
      if (result == null || !result) return;

      await Future.delayed(const Duration(seconds: 4));
      if (!context.mounted) return;

      bloc.add(FlashcardsSearcherRequestSent(query: ''));
    }

    return BlocProvider(
      create: (context) => FlashcardsSearcherBloc(
        flashcardsSearcherRepository: context
            .read<FlashcardsSearcherRepository>(),
      ),
      child: _View(onTap: onTap, searchBarAsTitle: true, title: null),
    );
  }
}

class _View extends StatefulWidget {
  final void Function(
    AlgoliaFlashcard flashcard,
    bool hasCards,
    FlashcardsSearcherBloc bloc,
  )?
  onTap;
  final bool searchBarAsTitle;
  final Widget? title;

  const _View({
    super.key,
    this.onTap,
    required this.searchBarAsTitle,
    required this.title,
  });

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  late final TextEditingController _queryCont = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SearchPage(
      searchBar: FlashcardsSearchBar(cont: _queryCont),
      searchResults: FlashcardsSearchResults(
        onTap: (flashcard, hasCards) => widget.onTap!(
          flashcard,
          hasCards,
          context.read<FlashcardsSearcherBloc>(),
        ),
      ),
      filterOptions: FlashcardsFilterOptions(),
      itemCount: FlashcardsItemCount(),
      searchBarAsTitle: widget.searchBarAsTitle,
      title: widget.title,
      // drawerSubtitle: 'Choose tags to filter flashcard packs more easily',
      // drawerTitle: 'Find the Right Packs',
    );
  }
}
