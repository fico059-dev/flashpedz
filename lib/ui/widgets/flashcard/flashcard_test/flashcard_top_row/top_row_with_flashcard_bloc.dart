import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/flashcards/flashcard/flashcard_bloc.dart';
import 'package:flashcards/bloc/flashcards/flashcard/flashcard_event.dart';
import 'package:flashcards/bloc/flashcards/flashcard/flashcard_state.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_top_row/widgets/admin_edit_card_button.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_top_row/widgets/batch_counter.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_top_row/widgets/bookmark_button.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_top_row/widgets/popup_menu_button.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_top_row/widgets/question_counter.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_top_row/widgets/undo_button.dart';
import 'package:flashcards/ui/dialogs/flashcard/share_card_dialog.dart';
import 'package:flashcards/ui/dialogs/card_sets/card_set_dialogs.dart';
import 'package:flashcards/ui/dialogs/flashcard/session_target_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TopRowWithFlashcardBloc extends StatelessWidget {
  const TopRowWithFlashcardBloc({super.key});

  @override
  Widget build(BuildContext context) {
    void onIgnore() {
      context.read<FlashcardBloc>().add(FlashcardIgnored());
    }

    void onReport({
      required Flashcard flashcard,
      required String packId,
      required String packName,
    }) {
      context.router.push(
        ReportFlashcardRoute(
          packId: packId,
          flashcard: flashcard,
          packName: packName,
        ),
      );
    }

    void onToggleBookmark() {
      context.read<FlashcardBloc>().add(FlashcardBookmarkToggled());
    }

    return BlocBuilder<FlashcardBloc, FlashcardState>(
      builder: (context, state) {
        // The first batch continues today's session of this pack.
        final done = state.currentBatch == 0 ? state.sessionDone : 0;
        int allFlashcards = done + state.statRecords.length;
        int currFlashcard = done + state.currentCardIndex + 1;
        final isBookmarked = state.flashcard == null
            ? false
            : state.statRecords[state.currentCardIndex].hasBookmark;
        var enabled = false;
        if (state.flashcard != null && state.pack != null) {
          enabled = true;
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (state.currentBatch > 0)
              BatchCounter(
                currentBatch: state.currentBatch,
                currentFlashcard: currFlashcard,
                allFlashcards: allFlashcards,
              )
            else
              _TargetButton(
                enabled:
                    state.testType == TestType.regular &&
                    state.pack != null &&
                    state.status.isLoaded,
                child: QuestionCounter(
                  currentFlashcard: currFlashcard,
                  allFlashcards: allFlashcards,
                ),
              ),

            Row(
              children: [
                UndoButton(
                  onUndo: context.read<FlashcardBloc>().canUndo
                      ? () => context.read<FlashcardBloc>().add(
                          FlashcardUndoPressed(),
                        )
                      : null,
                ),
                AdminEditCardButton(
                  flashcard: state.flashcard == null
                      ? null
                      : state.statRecords[state.currentCardIndex].flashcard,
                  onEdited: (card) =>
                      context.read<FlashcardBloc>().add(FlashcardEdited(card)),
                ),
                IconButton(
                  tooltip: 'Search cards',
                  icon: const Icon(Icons.search),
                  onPressed: () =>
                      context.router.push(StudySearchRoute(pack: state.pack)),
                ),
                IconButton(
                  tooltip: 'Share card',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: state.flashcard == null
                      ? null
                      : () => showShareCardDialog(context, state.flashcard!),
                ),
                BookmarkButton(
                  isBookmarked: isBookmarked,
                  onToggleBookmark: onToggleBookmark,
                ),

                PopupMenuButtonTopRow(
                  onIgnore: onIgnore,
                  onAddToSet: state.flashcard == null
                      ? null
                      : () => showAddToSetSheet(context, state.flashcard!.id),
                  onReport: () {
                    // In a pack with sub-packs, the card may be from one
                    // of the sub-packs.
                    final pack = state.pack!;
                    final cardPackId = state.flashcard!.packId;
                    final cardPack = [
                      pack,
                      ...pack.subPacks,
                    ].firstWhere((p) => p.id == cardPackId, orElse: () => pack);
                    onReport(
                      packName: cardPack.name,
                      flashcard: state.flashcard!,
                      packId: cardPack.id,
                    );
                  },
                  enabled: enabled,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The card counter; tapping it changes how many cards this pack's session
/// has.
class _TargetButton extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _TargetButton({required this.enabled, required this.child});

  Future<void> _change(BuildContext context) async {
    final bloc = context.read<FlashcardBloc>();
    final state = bloc.state;
    final choice = await showSessionTargetDialog(
      context: context,
      packName: state.pack?.name ?? 'this pack',
      current: state.cardsPerSession ?? state.statRecords.length,
    );
    switch (choice) {
      case null:
        return;
      case SessionTargetSet(:final target):
        bloc.add(FlashcardSessionTargetChanged(target));
      case SessionTargetDefault():
        bloc.add(FlashcardSessionTargetChanged(null));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Tooltip(
      message: 'Change cards per session for this pack',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _change(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              const SizedBox(width: 4),
              Icon(
                Icons.tune,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
