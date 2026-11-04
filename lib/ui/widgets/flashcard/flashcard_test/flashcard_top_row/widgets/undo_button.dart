import 'package:flutter/material.dart';

/// Takes back the last answer and shows that card again.
class UndoButton extends StatelessWidget {
  final VoidCallback? onUndo;

  const UndoButton({super.key, required this.onUndo});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Undo last answer (Z)',
      icon: const Icon(Icons.undo),
      onPressed: onUndo,
    );
  }
}
