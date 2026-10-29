import 'package:flashcards/ui/widgets/editor/rich_card_editor.dart'
    deferred as editor;
import 'package:flutter/material.dart';

/// The rich card editor, downloaded the first time it's needed: only
/// admins edit cards, so the website doesn't make students download it.
class RichCardEditorLoader extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? errorText;
  final List<Widget> extraActions;

  const RichCardEditorLoader({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.extraActions = const [],
  });

  @override
  State<RichCardEditorLoader> createState() => _RichCardEditorLoaderState();
}

class _RichCardEditorLoaderState extends State<RichCardEditorLoader> {
  static Future<void>? _loading;

  late final Future<void> _ready = _loading ??= editor.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Couldn't download it: the card can still be edited as text.
          return TextField(
            controller: widget.controller,
            minLines: 4,
            maxLines: 12,
            decoration: InputDecoration(
              labelText: widget.label,
              errorText: widget.errorText,
              border: const OutlineInputBorder(),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 330,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return editor.RichCardEditor(
          controller: widget.controller,
          label: widget.label,
          errorText: widget.errorText,
          extraActions: widget.extraActions,
        );
      },
    );
  }
}
