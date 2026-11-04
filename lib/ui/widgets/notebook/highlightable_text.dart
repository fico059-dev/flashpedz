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

/// [start]..[end] of [text] widened to whole words.
(int, int) expandToWords(String text, int start, int end) {
  bool isWordChar(int i) =>
      i >= 0 &&
      i < text.length &&
      RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(text[i]);
  var s = start, e = end;
  // Only widen a selection that cuts a word, not one ending at a space.
  if (isWordChar(s) && isWordChar(s - 1)) {
    while (isWordChar(s - 1)) {
      s--;
    }
  }
  if (isWordChar(e - 1) && isWordChar(e)) {
    while (isWordChar(e)) {
      e++;
    }
  }
  return (s, e);
}

/// Colour of the student's underlines.
const underlineColor = Color(0xFFE53935);

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
/// or underlined (and marks removed) from the selection menu. Highlights are
/// shown in yellow, underlines in red.
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
            key: ValueKey(_selectionGeneration),
            _spans(ranges),
            style: widget.style,
            textAlign: widget.textAlign,
            onSelectionChanged: (selection, cause) {
              _selection = selection;
              // A new selection (or a click) replaces the bar.
              if (_mouseBar != null &&
                  (selection.isCollapsed ||
                      cause != SelectionChangedCause.drag)) {
                _hideMouseBar();
              }
            },
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
      bool marked(HighlightKind kind) =>
          ranges.any((r) => r.$3.kind == kind && r.$1 <= start && r.$2 >= end);
      final highlighted = marked(HighlightKind.highlight);
      final underlined = marked(HighlightKind.underline);
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            fontWeight: run.bold ? FontWeight.w700 : null,
            fontStyle: run.italic ? FontStyle.italic : null,
            decoration: TextDecoration.combine([
              if (run.underline || underlined) TextDecoration.underline,
              if (run.strike) TextDecoration.lineThrough,
            ]),
            decorationColor: underlined ? underlineColor : null,
            decorationThickness: underlined ? 2.5 : null,
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

  /// What can be done with the selected text: highlight or underline it,
  /// or remove the marks it touches.
  List<_MarkAction> _markActions(
    TextSelection selection,
    HighlightRepository repo,
    HighlightTarget target,
  ) {
    if (!selection.isValid || selection.isCollapsed) return const [];
    final text = widget.text;
    if (selection.end > text.length) return const [];

    // Marks touching the selected text.
    final touching = [
      for (final highlight in repo.forCard(target.flashcardId, target.side))
        if (highlightRanges(text, [
          highlight,
        ]).any((r) => r.$1 < selection.end && r.$2 > selection.start))
          highlight,
    ];

    // Whole words: a drag that starts or ends inside a word marks all of it.
    final (wordStart, wordEnd) = expandToWords(
      text,
      selection.start,
      selection.end,
    );
    final inside = text.substring(wordStart, wordEnd);
    final selected = inside.trim();
    final leading = inside.indexOf(selected);
    final actions = <_MarkAction>[];
    for (final kind in HighlightKind.values) {
      final isUnderline = kind == HighlightKind.underline;
      final marks = touching.where((h) => h.kind == kind).toList();
      if (marks.isNotEmpty) {
        actions.add(
          _MarkAction(
            isUnderline ? 'Remove underline' : 'Remove highlight',
            isUnderline
                ? Icons.format_underline
                : Icons.format_color_reset_outlined,
            () => repo.remove(marks, onError: _showError),
          ),
        );
      } else if (selected.isNotEmpty) {
        actions.add(
          _MarkAction(
            isUnderline ? 'Underline' : 'Highlight',
            isUnderline ? Icons.format_underline : Icons.border_color_outlined,
            () => repo.add(
              flashcardId: target.flashcardId,
              packId: target.packId,
              side: target.side,
              text: selected,
              start: wordStart + leading,
              question: target.question,
              kind: kind,
              onError: _showError,
            ),
          ),
        );
      }
    }
    return actions;
  }

  /// The bar shown after selecting text with a mouse.
  OverlayEntry? _mouseBar;

  /// Changed to clear the selection once it was highlighted or underlined.
  int _selectionGeneration = 0;

  void _hideMouseBar() {
    _mouseBar?.remove();
    _mouseBar = null;
  }

  @override
  void dispose() {
    _hideMouseBar();
    super.dispose();
  }

  /// After selecting text with a mouse: a small bar just above the pointer
  /// with Highlight, Underline and Copy. The text stays selected (a menu
  /// would take the focus and hide the selection).
  void _showMouseMenu(
    Offset position,
    HighlightRepository repo,
    HighlightTarget target,
  ) {
    final selection = _selection;
    if (!mounted || !_selectedWithMouse || selection == null) return;
    final actions = _markActions(selection, repo, target);
    if (actions.isEmpty) return;
    _selectedWithMouse = false;
    _hideMouseBar();

    final overlay = Overlay.of(context);
    final box = overlay.context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(position);
    final selectedText = selection.textInside(widget.text);
    final entry = OverlayEntry(
      builder: (context) => _MouseSelectionBar(
        anchor: local,
        overlaySize: box.size,
        actions: [
          for (final action in actions)
            _BarButton(action.icon, action.label, () {
              _hideMouseBar();
              action.run();
              if (mounted) setState(() => _selectionGeneration++);
            }),
          _BarButton(Icons.copy, 'Copy', () {
            _hideMouseBar();
            Clipboard.setData(ClipboardData(text: selectedText));
          }),
        ],
        onDismiss: _hideMouseBar,
      ),
    );
    _mouseBar = entry;
    overlay.insert(entry);
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

    final actions = _markActions(selection, repo, target);
    buttons.insertAll(0, [
      for (final action in actions)
        ContextMenuButtonItem(
          label: action.label,
          onPressed: () {
            action.run();
            closeMenu();
          },
        ),
    ]);

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttons,
    );
  }
}

/// "Highlight", "Underline" or removing them, in the selection menu.
class _MarkAction {
  final String label;
  final IconData icon;
  final VoidCallback run;

  const _MarkAction(this.label, this.icon, this.run);
}

class _BarButton {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _BarButton(this.icon, this.label, this.onPressed);
}

/// A row of buttons floating above the selected text.
class _MouseSelectionBar extends StatelessWidget {
  final Offset anchor;
  final Size overlaySize;
  final List<_BarButton> actions;
  final VoidCallback onDismiss;

  const _MouseSelectionBar({
    required this.anchor,
    required this.overlaySize,
    required this.actions,
    required this.onDismiss,
  });

  static const _height = 44.0;

  @override
  Widget build(BuildContext context) {
    final width = 120.0 * actions.length;
    final left = (anchor.dx - width / 2).clamp(
      8.0,
      (overlaySize.width - width - 8).clamp(8.0, double.infinity),
    );
    // Above the pointer, or below it at the top of the screen.
    final top = anchor.dy - _height - 14 < 8
        ? anchor.dy + 16
        : anchor.dy - _height - 14;
    final colors = Theme.of(context).colorScheme;
    return Positioned(
      left: left,
      top: top,
      // Counts as part of the text, so using it keeps the text selected.
      child: TextFieldTapRegion(
        child: TapRegion(
          onTapOutside: (_) => onDismiss(),
          child: Material(
            elevation: 6,
            color: colors.inverseSurface,
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: _height,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in actions)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onInverseSurface,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onPressed: action.onPressed,
                      icon: Icon(action.icon, size: 18),
                      label: Text(action.label),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
