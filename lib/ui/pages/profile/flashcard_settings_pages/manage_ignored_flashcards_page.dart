import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/flashcards/ignored_card/ignored_card_bloc.dart';
import 'package:flashcards/bloc/flashcards/ignored_card/ignored_card_event.dart';
import 'package:flashcards/bloc/flashcards/ignored_card/ignored_card_state.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pack_repository.dart';
import 'package:flashcards/domain/models/flashcards/ignored_flashcard/ignored_flashcard.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/widgets/core/card_factory.dart';
import 'package:flashcards/ui/widgets/core/error_screen.dart';
import 'package:flashcards/ui/widgets/flashcard/bookmarks/bookmarks_shimmer.dart';
import 'package:flashcards/ui/widgets/profile/flashcard_settings/manage_ignored_cards/ignored_flashcard_card.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

@RoutePage()
class ManageIgnoredFlashcardsPage extends StatelessWidget {
  const ManageIgnoredFlashcardsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => IgnoredCardBloc(
        fcpRepo: context.read<FcpRepository>(),
        packRepo: context.read<PackRepository>(),
      ),
      child: _IgnoredCardsView(),
    );
  }
}

class _IgnoredCardsView extends StatelessWidget {
  const _IgnoredCardsView({super.key});

  @override
  Widget build(BuildContext context) {
    void onUndo({required IgnoredFlashcard card, required int index}) {
      context.read<IgnoredCardBloc>().add(
        IgnoredCardUnignoreUndo(ignoredCard: card, index: index),
      );
    }

    void fetchNextPage() {
      context.read<IgnoredCardBloc>().add(IgnoredCardPageFetched());
    }

    Future<void> handleRefresh(BuildContext context) {
      final completer = Completer<void>();
      context.read<IgnoredCardBloc>().add(
        IgnoredCardRefresh(completer: completer),
      );

      return completer.future.catchError((error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(extractErrorMessage(error))));
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.router.pop(),
          icon: Icon(Icons.arrow_back),
        ),
        title: Text("Manage Ignored Flashcards"),
      ),
      body: ReadableWidth(
        maxWidth: 820,
        child: BlocBuilder<IgnoredCardBloc, IgnoredCardState>(
          builder: (context, state) => RefreshIndicator(
            onRefresh: () => handleRefresh(context),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalScreenPadding,
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 7),
                        CardFactory.info(
                          title: Text("Unignore flashcard"),
                          subtitle: Text("Tap ⋮ on a card to unignore it"),
                          closable: true,
                        ),
                        SizedBox(height: 15),
                      ],
                    ),
                  ),
                ),

                PagedSliverList(
                  state: state.pagingState,
                  fetchNextPage: fetchNextPage,
                  builderDelegate: PagedChildBuilderDelegate(
                    firstPageProgressIndicatorBuilder: (context) =>
                        BookmarksShimmer(),
                    noItemsFoundIndicatorBuilder: (context) =>
                        _EmptyListContainer(),
                    firstPageErrorIndicatorBuilder: (context) => ErrorScreen(
                      errorMessage: extractErrorMessage(
                        state.pagingState.error!,
                      ),
                      onReload: fetchNextPage,
                    ),
                    itemBuilder: (context, item, index) {
                      final card = item as IgnoredFlashcard;
                      return IgnoredFlashcardCard(
                        key: ValueKey(card.flashcardId),
                        card: card,
                        index: index,
                        onUndo: onUndo,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// builder: (context, state) {
//   switch (state) {
//     case IgnoredCardError(:final error):
//       return ErrorScreen(
//         errorMessage: error.toString(),
//         onReload: _loadData,
//         message: '',
//       );
//     case IgnoredCardInitial():
//       return _EmptyListContainer();
//     case IgnoredCardSuccess(:final ignoredCards):
//       if (ignoredCards.isEmpty) {
//         return _EmptyListContainer();
//       }
//       return _Content(ignoredCards: ignoredCards, onUndo: onUndo);
//     default:
//       return SizedBox.expand();
//   }
// },

class _Content extends StatefulWidget {
  final List<IgnoredFlashcard> ignoredCards;
  final void Function({required IgnoredFlashcard card, required int index})
  onUndo;

  const _Content({super.key, required this.ignoredCards, required this.onUndo});

  @override
  State<_Content> createState() => _ContentState();
}

class _ContentState extends State<_Content> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalScreenPadding),
            child: Column(
              children: [
                Text(
                  "Number of ignored flashcards: ${widget.ignoredCards.length}",
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 7),
                CardFactory.info(
                  title: Text("Unignore flashcard"),
                  subtitle: Text("Tap ⋮ on a card to unignore it"),
                  closable: true,
                ),
                SizedBox(height: 15),
              ],
            ),
          ),
          ListView.builder(
            itemCount: widget.ignoredCards.length,
            shrinkWrap: true,
            primary: false,
            itemBuilder: (context, index) {
              final card = widget.ignoredCards[index];

              return IgnoredFlashcardCard(
                key: ValueKey(card.flashcardId),
                card: card,
                index: index,
                onUndo: widget.onUndo,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyListContainer extends StatelessWidget {
  const _EmptyListContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalScreenPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset("assets/images/happy_parrot.png", height: 200),
          const SizedBox(height: 10),
          Text(
            "No ignored cards so far — nice!",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
