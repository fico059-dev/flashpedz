import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/bloc/flashcards/bookmark_review/bookmark_review_bloc.dart';
import 'package:flashcards/bloc/flashcards/bookmark_review/bookmark_review_event.dart';
import 'package:flashcards/data/mappers/fsrs_mapper.dart';
import 'package:flashcards/domain/models/flashcards/bookmark/bookmark.dart';
import 'package:flashcards/domain/models/flashcards/card_info_item/card_info_item.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/flashcard/fsrs_card_items/card_meta_row_full_width.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:flashcards/ui/dialogs/card_sets/card_set_dialogs.dart';

class BookmarkCard extends StatefulWidget {
  final int index;
  final bool isAnswerVisible;
  final Bookmark bookmark;
  final void Function({
    required Bookmark bookmark,
    required int index,
    required bool isAnswerVisible,
  })
  onUndo;

  const BookmarkCard({
    super.key,
    required this.index,
    required this.bookmark,
    required this.isAnswerVisible,
    required this.onUndo,
  });

  @override
  State<BookmarkCard> createState() => _BookmarkCardState();
}

class _BookmarkCardState extends State<BookmarkCard> {
  double? minHeight;

  final GlobalKey _textKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderBox? box =
          _textKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null) {
        setState(() {
          minHeight = box.size.height;
        });
      }
    });
  }

  void _toggle() {
    context.read<BookmarkReviewBloc>().add(
      BookmarkReviewAnswerToggled(bookmark: widget.bookmark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.bookmark.fsrsCard;

    void showSuccessSnackBar() {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '"${widget.bookmark.question}"',
                style: const TextStyle(fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Text('removed from bookmarks'),
            ],
          ),
          action: SnackBarAction(
            label: "Undo",
            onPressed: () => widget.onUndo(
              bookmark: widget.bookmark,
              isAnswerVisible: widget.isAnswerVisible,
              index: widget.index,
            ),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }

    void remove() {
      context.read<BookmarkReviewBloc>().add(
        BookmarkReviewBookmarkRemoved(bookmark: widget.bookmark),
      );
      showSuccessSnackBar();
    }

    final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      color: !widget.isAnswerVisible
          ? context.colors.onPrimaryContainer
          : context.colors.onSecondaryContainer,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalScreenPadding,
          vertical: 7,
        ),
        child: Stack(
          children: [
            Material(
              color: !widget.isAnswerVisible
                  ? context.colors.primaryContainer
                  : context.colors.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
              elevation: 0,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _toggle,
                child: Ink(
                  padding: const EdgeInsets.fromLTRB(20, 20, 40, 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: minHeight ?? 0,
                      minWidth: double.infinity,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          plainCardText(
                            widget.isAnswerVisible
                                ? widget.bookmark.answer
                                : widget.bookmark.question,
                          ),
                          key: widget.isAnswerVisible ? null : _textKey,
                          style: textStyle,
                        ),
                        if (widget.isAnswerVisible)
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: Column(
                              children: card
                                  .buildCardInfoItems()
                                  .map(
                                    (item) => CardMetaRowFullWidth(item: item),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<_BookmarkAction>(
                tooltip: 'Bookmark options',
                icon: Icon(
                  Icons.more_vert,
                  color: !widget.isAnswerVisible
                      ? context.colors.onPrimaryContainer
                      : context.colors.onSecondaryContainer,
                ),
                onSelected: (action) {
                  switch (action) {
                    case _BookmarkAction.addToSet:
                      showAddToSetSheet(context, widget.bookmark.flashcardId);
                    case _BookmarkAction.remove:
                      remove();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _BookmarkAction.addToSet,
                    child: ListTile(
                      leading: Icon(Icons.playlist_add),
                      title: Text('Add to set…'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _BookmarkAction.remove,
                    child: ListTile(
                      leading: Icon(Icons.bookmark_remove_outlined),
                      title: Text('Remove bookmark'),
                    ),
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

enum _BookmarkAction { addToSet, remove }
