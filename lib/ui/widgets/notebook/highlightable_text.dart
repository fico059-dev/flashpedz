import 'package:flashcards/data/repositories/notebook/highlight_repository.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/flashcards/highlight/highlight.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Colour of highlighted text, readable in light and dark mode.
const highlightBackground = Color(0xFFFFE27A);
const highlightForeground = Color(0xFF2B2300);

/// Which card side a [HighlightableText] shows.
class HighlightTarget {
  final String flashcardId;
  final String packId;
  final HighlightSide side;

  /// The card's question, kept with the highlight for the notebook.
  final String question;

  const HighlightTarget({
    required this.flashcardId,
    required this.packId,
    required this.side,
    required this.question,
  });

  /// Null for placeholder cards, which can't be highlighted.
  static HighlightTarget? of(Flashcard flashcard, HighlightSide side) {
    if (flashcard.id.isEmpty || flashcard.id == '-1') return null;
    return HighlightTarget(
      flashcardId: flashcard.id,
      packId: flashcard.packId,
      side: side,
      question: flashcard.question,
    );
  }
}

/// Selectable card text. With a [target], selected text can be highlighted
/// (and highlights removed) from the selection menu, and highlights are
/// shown in yellow.
class HighlightableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final HighlightTarget? target;

  /// Bold, underline and size of parts of [text] (formatted cards). Their
  /// texts joined must equal [text].
  final List<StyledRun>? runs;

  const HighlightableText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.target,
    this.runs,
  });

  @override
  State<HighlightableText> createState() => _HighlightableTextState();
}

class _HighlightableTextState extends State<HighlightableText> {
  HighlightRepository? _repo;

  /// The latest selection, for the menu shown after selecting with a mouse.
  TextSelection? _selection;
  bool _selectedWithMouse = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Missing outside the app (e.g. in admin previews or tests).
    try {
      _repo = context.read<HighlightRepository>();
    } on ProviderNotFoundException {
      _repo = null;
    }
    if (widget.target != null) _repo?.load();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _repo;
    final target = widget.target;
    if (repo == null || target == null) {
      if (widget.runs == null) {
        return SelectableText(
          widget.text,
          style: widget.style,
          textAlign: widget.textAlign,
        );
      }
      return SelectableText.rich(
        _spans(const []),
        style: widget.style,
        textAlign: widget.textAlign,
      );
    }
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final ranges = highlightRanges(
          widget.text,
          repo.forCard(target.flashcardId, target.side),
        );
        // With a mouse or trackpad (Mac, website) the selection menu
        // only opens on a right click, so Highlight is offered as soon as
        // text is selected.
        return Listener(
          // Left button only: a right click opens the usual menu.
          onPointerDown: (event) => _selectedWithMouse =
              event.kind == PointerDeviceKind.mouse &&
              event.buttons == kPrimaryMouseButton,
          onPointerUp: (event) {
            if (!_selectedWithMouse) return;
            final position = event.position;
            // The selection is updated when the button is released.
            Future(() => _showMouseMenu(position, repo, target));
          },
          child: SelectableText.rich(
            _spans(ranges),
            style: widget.style,
            textAlign: widget.textAlign,
            onSelectionChanged: (selection, cause) => _selection = selection,
            contextMenuBuilder: (context, editableTextState) =>
                _menu(context, editableTextState, repo, target),
          ),
        );
      },
    );
  }

  TextSpan _spans(List<(int, int, Highlight)> ranges) {
    final text = widget.text;
    final runs = widget.runs ?? [StyledRun(text)];

    // Cut the text wherever a style or a highlight starts or ends.
    final cuts = <int>{0, text.length};
    var offset = 0;
    final runStarts = <int>[];
    for (final run in runs) {
      runStarts.add(offset);
      cuts.add(offset);
      offset += run.text.length;
      cuts.add(offset);
    }
    for (final (start, end, _) in ranges) {
      cuts
        ..add(start)
        ..add(end);
    }
    final points = cuts.where((c) => c >= 0 && c <= text.length).toList()
      ..sort();

    final children = <TextSpan>[];
    var runIndex = 0;
    for (var i = 0; i + 1 < points.length; i++) {
      final start = points[i];
      final end = points[i + 1];
      if (start == end) continue;
      while (runIndex + 1 < runs.length && runStarts[runIndex + 1] <= start) {
        runIndex++;
      }
      final run = runs[runIndex];
      final highlighted = ranges.any((r) => r.$1 <= start && r.$2 >= end);
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            fontWeight: run.bold ? FontWeight.w700 : null,
            fontStyle: run.italic ? FontStyle.italic : null,
            decoration: TextDecoration.combine([
              if (run.underline) TextDecoration.underline,
              if (run.strike) TextDecoration.lineThrough,
            ]),
            fontSize: run.script == Script.normal
                ? run.size
                : (run.size ?? widget.style?.fontSize ?? 16) * 0.7,
            fontFeatures: switch (run.script) {
              Script.superscript => const [FontFeature.superscripts()],
              Script.subscript => const [FontFeature.subscripts()],
              Script.normal => null,
            },
            backgroundColor: highlighted
                ? highlightBackground
                : run.background == null
                ? null
                : Color(run.background!),
            color: highlighted
                ? highlightForeground
                : run.color == null
                ? null
                : Color(run.color!),
          ),
        ),
      );
    }
    return TextSpan(children: children);
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Couldn't save the highlight: ${extractErrorMessage(error)}",
        ),
      ),
    );
  }

  /// "Highlight" or "Remove highlight" for the selected text, if any.
  (String, VoidCallback)? _highlightAction(
    TextSelection selection,
    HighlightRepository repo,
    HighlightTarget target,
  ) {
    if (!selection.isValid || selection.isCollapsed) return null;
    final text = widget.text;
    if (selection.end > text.length) return null;

    // Highlights touching the selected text.
    final toRemove = [
      for (final highlight in repo.forCard(target.flashcardId, target.side))
        if (highlightRanges(text, [
          highlight,
        ]).any((r) => r.$1 < selection.end && r.$2 > selection.start))
          highlight,
    ];
    if (toRemove.isNotEmpty) {
      return (
        'Remove highlight',
        () => repo.remove(toRemove, onError: _showError),
      );
    }

    final inside = selection.textInside(text);
    final selected = inside.trim();
    if (selected.isEmpty) return null;
    final leading = inside.indexOf(selected);
    return (
      'Highlight',
      () => repo.add(
        flashcardId: target.flashcardId,
        packId: target.packId,
        side: target.side,
        text: selected,
        start: selection.start + leading,
        question: target.question,
        onError: _showError,
      ),
    );
  }

  /// After selecting text with a mouse: a small menu at the pointer.
  Future<void> _showMouseMenu(
    Offset position,
    HighlightRepository repo,
    HighlightTarget target,
  ) async {
    final selection = _selection;
    if (!mounted || !_selectedWithMouse || selection == null) return;
    final action = _highlightAction(selection, repo, target);
    if (action == null) return;
    _selectedWithMouse = false;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final chosen = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position.translate(0, 8) & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'highlight',
          height: 40,
          child: Row(
            children: [
              Icon(
                action.$1 == 'Highlight'
                    ? Icons.border_color_outlined
                    : Icons.format_color_reset_outlined,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(action.$1),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          height: 40,
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 10),
              Text('Copy'),
            ],
          ),
        ),
      ],
    );
    if (chosen == 'highlight') {
      action.$2();
    } else if (chosen == 'copy') {
      await Clipboard.setData(
        ClipboardData(text: selection.textInside(widget.text)),
      );
    }
  }

  Widget _menu(
    BuildContext context,
    EditableTextState editableTextState,
    HighlightRepository repo,
    HighlightTarget target,
  ) {
    final value = editableTextState.textEditingValue;
    final selection = value.selection;
    final buttons = [...editableTextState.contextMenuButtonItems];

    void closeMenu() {
      editableTextState.userUpdateTextEditingValue(
        value.copyWith(
          selection: TextSelection.collapsed(offset: selection.end),
        ),
        SelectionChangedCause.toolbar,
      );
      editableTextState.hideToolbar();
    }

    final action = _highlightAction(selection, repo, target);
    if (action != null) {
      buttons.insert(
        0,
        ContextMenuButtonItem(
          label: action.$1,
          onPressed: () {
            action.$2();
            closeMenu();
          },
        ),
      );
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttons,
    );
  }
}
