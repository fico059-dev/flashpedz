import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/bloc/flashcards/ignored_card/ignored_card_bloc.dart';
import 'package:flashcards/bloc/flashcards/ignored_card/ignored_card_event.dart';
import 'package:flashcards/domain/models/flashcards/ignored_flashcard/ignored_flashcard.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class IgnoredFlashcardCard extends StatelessWidget {
  final IgnoredFlashcard card;
  final int index;
  final void Function({required IgnoredFlashcard card, required int index})
  onUndo;

  const IgnoredFlashcardCard({
    super.key,
    required this.card,
    required this.onUndo,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(color: context.colors.onPrimaryContainer);

    void showSuccessSnackBar() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${card.question}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Text('unignored'),
            ],
          ),
          action: SnackBarAction(
            label: "Undo",
            onPressed: () => onUndo(card: card, index: index),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }

    void unignore() {
      context.read<IgnoredCardBloc>().add(
        IgnoredCardUnignored(ignoredCard: card),
      );
      showSuccessSnackBar();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalScreenPadding,
        vertical: 7,
      ),
      child: Material(
        color: context.colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          //onTap: () {},
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 4, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(plainCardText(card.question), style: textStyle),
                ),
                PopupMenuButton<int>(
                  tooltip: 'Card options',
                  icon: Icon(
                    Icons.more_vert,
                    color: context.colors.onPrimaryContainer,
                  ),
                  onSelected: (_) => unignore(),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 0,
                      child: ListTile(
                        leading: Icon(Icons.visibility),
                        title: Text('Unignore'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
