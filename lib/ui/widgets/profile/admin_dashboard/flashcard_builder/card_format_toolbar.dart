import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/data/utils/image_compression.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/ui/widgets/flashcard/card_content.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flutter/material.dart';

/// Wraps the selected text of [controller] in [before] and [after]. With
/// nothing selected, the cursor ends up between them.
void wrapSelection(
  TextEditingController controller,
  String before,
  String after,
) {
  final text = controller.text;
  var selection = controller.selection;
  if (!selection.isValid) {
    selection = TextSelection.collapsed(offset: text.length);
  }
  final selected = selection.textInside(text);
  controller.value = TextEditingValue(
    text:
        selection.textBefore(text) +
        before +
        selected +
        after +
        selection.textAfter(text),
    selection: selected.isEmpty
        ? TextSelection.collapsed(offset: selection.start + before.length)
        : TextSelection(
            baseOffset: selection.start + before.length,
            extentOffset: selection.start + before.length + selected.length,
          ),
  );
}

/// Inserts [block] on its own lines at the cursor (tables, images).
void insertBlock(TextEditingController controller, String block) {
  final text = controller.text;
  var selection = controller.selection;
  if (!selection.isValid) {
    selection = TextSelection.collapsed(offset: text.length);
  }
  // Spaces next to the cursor would start the lines around the block.
  final before = selection
      .textBefore(text)
      .replaceFirst(RegExp(r'[ \t]+$'), '');
  final after = selection.textAfter(text).replaceFirst(RegExp(r'^[ \t]+'), '');
  final lead = before.isEmpty || before.endsWith('\n') ? '' : '\n';
  final trail = after.startsWith('\n') ? '' : '\n';
  final inserted = '$lead$block$trail';
  controller.value = TextEditingValue(
    text: before + inserted + after,
    selection: TextSelection.collapsed(offset: before.length + inserted.length),
  );
}

final _bulletPrefix = RegExp(r'^\s*[•\-\*]\s+');
final _numberPrefix = RegExp(r'^\s*\d+[.)]\s+');

/// Turns the selected lines (or the cursor's line) into a bulleted or
/// numbered list, or back into plain lines when they already are one.
void toggleList(TextEditingController controller, {required bool numbered}) {
  final text = controller.text;
  var selection = controller.selection;
  if (!selection.isValid) {
    selection = TextSelection.collapsed(offset: text.length);
  }
  // Whole lines touched by the selection.
  final start = text.lastIndexOf('\n', max(0, selection.start - 1)) + 1;
  final startAt = selection.start == 0 ? 0 : start;
  var end = text.indexOf('\n', selection.end);
  if (end == -1) end = text.length;
  final lines = text.substring(startAt, end).split('\n');

  final pattern = numbered ? _numberPrefix : _bulletPrefix;
  final already = lines
      .where((l) => l.trim().isNotEmpty)
      .every((l) => pattern.hasMatch(l));
  var number = 0;
  final changed = [
    for (final line in lines)
      if (line.trim().isEmpty)
        line
      else if (already)
        line.replaceFirst(pattern, '')
      else
        '${numbered ? '${++number}.' : '•'} '
            '${line.replaceFirst(_bulletPrefix, '').replaceFirst(_numberPrefix, '')}',
  ].join('\n');

  controller.value = TextEditingValue(
    text: text.substring(0, startAt) + changed + text.substring(end),
    selection: TextSelection.collapsed(offset: startAt + changed.length),
  );
}

/// The card text as it will look, under the box it's typed in, so tables,
/// lists and formatting can be checked while writing.
class CardMarkupPreview extends StatelessWidget {
  final TextEditingController controller;

  const CardMarkupPreview({super.key, required this.controller});

  static bool _worthShowing(String text) =>
      hasCardMarkup(text) ||
      text
          .split('\n')
          .any((l) => _bulletPrefix.hasMatch(l) || _numberPrefix.hasMatch(l));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final text = controller.text;
        if (text.trim().isEmpty || !_worthShowing(text)) {
          return const SizedBox.shrink();
        }
        final colors = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preview',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.primary),
              ),
              const SizedBox(height: 6),
              CardContent(text),
            ],
          ),
        );
      },
    );
  }
}

/// Formatting buttons shown above a card's question or answer box: bold,
/// underline, text size, lists, table and image.
class CardFormatToolbar extends StatefulWidget {
  final TextEditingController controller;

  const CardFormatToolbar({super.key, required this.controller});

  @override
  State<CardFormatToolbar> createState() => _CardFormatToolbarState();
}

class _CardFormatToolbarState extends State<CardFormatToolbar> {
  bool _uploading = false;

  TextEditingController get _controller => widget.controller;

  Future<void> _insertTable() async {
    final size = await showDialog<(int, int)>(
      context: context,
      builder: (context) => const _TableSizeDialog(),
    );
    if (size == null) return;
    insertBlock(_controller, tableTemplate(size.$1, size.$2));
  }

  Future<void> _insertImage() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = picked?.files.single.bytes;
    if (bytes == null || !mounted) return;
    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final jpeg = await prepareJpeg(bytes);
      if (jpeg == null) throw Exception("This image couldn't be read.");
      final url = await CloudFunctionService().uploadCardImage(
        base64Encode(jpeg),
      );
      insertBlock(_controller, '![image]($url)');
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text("Image not added: ${extractErrorMessage(error)}"),
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Formatting"),
        content: const SingleChildScrollView(
          child: Text(
            "Select text, then tap a button. The codes are shown here and "
            "turn into formatting on the card (tap Preview to see it).\n\n"
            "**bold**\n"
            "__underline__\n"
            "[size=22]bigger text[/size]  (sizes 8–48)\n"
            "![image](link)  an image; add as many as you like\n"
            "• a bulleted line,  1. a numbered line (list buttons)\n\n"
            "Tables: each row on its own line between | bars. The line of "
            "dashes under the first row makes it a header.\n"
            "| Drug | Dose |\n"
            "|------|------|\n"
            "| Amox | 50 mg/kg |\n\n"
            "Cloze {curly braces} still work inside formatting. A preview "
            "under the box shows how the card will look.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          tooltip: "Bold",
          icon: const Icon(Icons.format_bold),
          onPressed: () => wrapSelection(_controller, '**', '**'),
        ),
        IconButton(
          tooltip: "Underline",
          icon: const Icon(Icons.format_underlined),
          onPressed: () => wrapSelection(_controller, '__', '__'),
        ),
        PopupMenuButton<int>(
          tooltip: "Text size",
          icon: const Icon(Icons.format_size),
          onSelected: (size) =>
              wrapSelection(_controller, '[size=$size]', '[/size]'),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 13, child: Text("Small (13)")),
            PopupMenuItem(value: 22, child: Text("Large (22)")),
            PopupMenuItem(value: 28, child: Text("Very large (28)")),
            PopupMenuItem(value: 36, child: Text("Huge (36)")),
          ],
        ),
        IconButton(
          tooltip: "Bulleted list",
          icon: const Icon(Icons.format_list_bulleted),
          onPressed: () => toggleList(_controller, numbered: false),
        ),
        IconButton(
          tooltip: "Numbered list",
          icon: const Icon(Icons.format_list_numbered),
          onPressed: () => toggleList(_controller, numbered: true),
        ),
        IconButton(
          tooltip: "Insert table",
          icon: const Icon(Icons.table_chart_outlined),
          onPressed: _insertTable,
        ),
        _uploading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: "Insert image (as many as you like)",
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: _insertImage,
              ),
        IconButton(
          tooltip: "How formatting works",
          icon: const Icon(Icons.help_outline),
          onPressed: _showHelp,
        ),
      ],
    );
  }
}

class _TableSizeDialog extends StatefulWidget {
  const _TableSizeDialog();

  @override
  State<_TableSizeDialog> createState() => _TableSizeDialogState();
}

class _TableSizeDialogState extends State<_TableSizeDialog> {
  int _rows = 3;
  int _columns = 2;

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          onPressed: value < 12 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Insert table"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepper(
            "Rows (with header)",
            _rows,
            (v) => setState(() => _rows = v),
          ),
          _stepper("Columns", _columns, (v) => setState(() => _columns = v)),
          const SizedBox(height: 8),
          const Text(
            "Then type into the cells between the | bars.",
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_rows, _columns)),
          child: const Text("Insert"),
        ),
      ],
    );
  }
}
