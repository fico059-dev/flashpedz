import 'package:auto_route/annotations.dart';
import 'package:flashcards/bloc/flashcards/flashcards_searcher/flashcards_searcher_bloc.dart';
import 'package:flashcards/bloc/flashcards/flashcards_searcher/flashcards_searcher_event.dart';
import 'package:flashcards/data/repositories/algolia_search/flashcards_searcher_repository.dart';
import 'package:flashcards/domain/models/flashcards/pack/pack.dart';
import 'package:flashcards/ui/dialogs/flashcards/fc_review_bottom_sheet.dart';
import 'package:flashcards/ui/widgets/search/search_page/flashcards_search_page/flashcards_filter_options.dart';
import 'package:flashcards/ui/widgets/search/search_page/flashcards_search_page/flashcards_item_count.dart';
import 'package:flashcards/ui/widgets/search/search_page/flashcards_search_page/flashcards_search_bar.dart';
import 'package:flashcards/ui/widgets/search/search_page/flashcards_search_page/flashcards_search_results.dart';
import 'package:flashcards/ui/widgets/search/search_page/search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Card search opened while studying. With a [pack], it searches that pack
/// (and its sub-packs) first, and can switch to every pack.
@RoutePage()
class StudySearchPage extends StatelessWidget {
  final Pack? pack;

  const StudySearchPage({super.key, this.pack});

  Set<String>? get _packIds =>
      pack == null ? null : {pack!.id, ...pack!.subPacks.map((p) => p.id)};

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FlashcardsSearcherBloc(
        flashcardsSearcherRepository: context
            .read<FlashcardsSearcherRepository>(),
        packIds: _packIds,
      ),
      child: _View(pack: pack, packIds: _packIds),
    );
  }
}

class _View extends StatefulWidget {
  final Pack? pack;
  final Set<String>? packIds;

  const _View({required this.pack, required this.packIds});

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _queryCont = TextEditingController();
  late bool _thisPack = widget.pack != null;

  @override
  void dispose() {
    _queryCont.dispose();
    super.dispose();
  }

  void _setScope(bool thisPack) {
    setState(() => _thisPack = thisPack);
    context.read<FlashcardsSearcherBloc>().add(
      FlashcardsSearcherScopeChanged(packIds: thisPack ? widget.packIds : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    return SearchPage(
      searchBar: FlashcardsSearchBar(cont: _queryCont),
      header: pack == null
          ? null
          : SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.style_outlined),
                  label: Text('This pack', overflow: TextOverflow.ellipsis),
                  tooltip: pack.name,
                ),
                const ButtonSegment(
                  value: false,
                  icon: Icon(Icons.travel_explore),
                  label: Text('All packs'),
                ),
              ],
              selected: {_thisPack},
              onSelectionChanged: (value) => _setScope(value.first),
            ),
      searchResults: FlashcardsSearchResults(
        onTap: (flashcard, hasCards) => showFcReviewBottomSheet(
          context: context,
          flashcardId: flashcard.objectID,
          packId: flashcard.packId,
          question: flashcard.question,
          answer: flashcard.answer,
          isPaid: flashcard.isPaid,
          hasCards: hasCards,
        ),
      ),
      filterOptions: FlashcardsFilterOptions(),
      itemCount: FlashcardsItemCount(),
    );
  }
}
