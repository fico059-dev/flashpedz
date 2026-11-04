import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

/// From this width the app uses its desktop layout (side menu, wider
/// pages, keyboard hints).
const desktopBreakpoint = 900.0;

bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= desktopBreakpoint;

/// Centres [child] at a comfortable reading width on wide screens; on
/// phones it fills the screen as before.
class ReadableWidth extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const ReadableWidth({super.key, this.maxWidth = 820, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Center(
          child: SizedBox(
            width: min(maxWidth, constraints.maxWidth),
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}

/// Keyboard shortcuts while reviewing cards, like in Anki: Space or Enter
/// shows the answer, 1-4 rate Again, Hard, Good, Easy, Z (or Cmd/Ctrl+Z)
/// undoes the last answer. On wide screens a
/// short reminder is shown at the bottom.
///
/// The keys are caught for the whole window while this screen is on top, so
/// they keep working after clicking or selecting card text, using a menu or
/// closing a dialog (which all move the keyboard focus). They are left alone
/// while typing in a text field.
class ReviewShortcuts extends StatefulWidget {
  final VoidCallback onShowAnswer;
  final ValueChanged<fsrs.Rating> onRate;
  final VoidCallback? onUndo;
  final Widget child;

  const ReviewShortcuts({
    super.key,
    required this.onShowAnswer,
    required this.onRate,
    this.onUndo,
    required this.child,
  });

  static final _ratingKeys = {
    LogicalKeyboardKey.digit1: fsrs.Rating.again,
    LogicalKeyboardKey.numpad1: fsrs.Rating.again,
    LogicalKeyboardKey.digit2: fsrs.Rating.hard,
    LogicalKeyboardKey.numpad2: fsrs.Rating.hard,
    LogicalKeyboardKey.digit3: fsrs.Rating.good,
    LogicalKeyboardKey.numpad3: fsrs.Rating.good,
    LogicalKeyboardKey.digit4: fsrs.Rating.easy,
    LogicalKeyboardKey.numpad4: fsrs.Rating.easy,
  };

  static final _showAnswerKeys = {
    LogicalKeyboardKey.space,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  };

  @override
  State<ReviewShortcuts> createState() => _ReviewShortcutsState();
}

class _ReviewShortcutsState extends State<ReviewShortcuts> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// Whether the user is typing in a text field (not read-only card text).
  static bool _typing() {
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return false;
    final editable = focused.widget is EditableText
        ? focused.widget as EditableText
        : focused.findAncestorWidgetOfExactType<EditableText>();
    return editable != null && !editable.readOnly;
  }

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    // Not under a dialog, menu or another screen.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final keyboard = HardwareKeyboard.instance;
    final onUndo = widget.onUndo;
    if (onUndo != null &&
        event.logicalKey == LogicalKeyboardKey.keyZ &&
        !keyboard.isAltPressed &&
        !keyboard.isShiftPressed &&
        !_typing()) {
      onUndo();
      return true;
    }
    if (keyboard.isMetaPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed) {
      return false;
    }
    if (_typing()) return false;

    final key = event.logicalKey;
    final rating = ReviewShortcuts._ratingKeys[key];
    final showAnswer = ReviewShortcuts._showAnswerKeys.contains(key);
    if (rating == null && !showAnswer) return false;

    // Whatever was focused (a button, selected card text) mustn't also act
    // on the key.
    FocusManager.instance.primaryFocus?.unfocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    if (rating != null) {
      widget.onRate(rating);
    } else {
      widget.onShowAnswer();
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: widget.child),
        if (isWideLayout(context))
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Text(
              'Keyboard: Space shows the answer · 1 Again · 2 Hard · '
              '3 Good · 4 Easy${widget.onUndo != null ? ' · Z Undo' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
