import 'dart:async';
import 'dart:convert';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/data/utils/image_compression.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/ui/widgets/editor/card_document.dart';
import 'package:flashcards/ui/widgets/flashcard/card_content.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Colours offered for text and highlights.
const _textColors = [
  Color(0xFF000000),
  Color(0xFF616161),
  Color(0xFFD32F2F),
  Color(0xFFE64A19),
  Color(0xFFF9A825),
  Color(0xFF388E3C),
  Color(0xFF1976D2),
  Color(0xFF7B1FA2),
];
const _highlightColors = [
  Color(0xFFFFF59D),
  Color(0xFFC8E6C9),
  Color(0xFFBBDEFB),
  Color(0xFFF8BBD0),
  Color(0xFFFFE0B2),
  Color(0xFFE1BEE7),
];

String _colorCode(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// A card side edited like a word processor (like Anki's editor): bold,
/// italic, colours, lists, tables, images... The card text stays in
/// [controller], as the card markup the app stores.
class RichCardEditor extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? errorText;

  /// Extra toolbar buttons (e.g. image occlusion).
  final List<Widget> extraActions;

  const RichCardEditor({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.extraActions = const [],
  });

  @override
  State<RichCardEditor> createState() => RichCardEditorState();
}

class RichCardEditorState extends State<RichCardEditor> {
  late EditorState _editor;
  StreamSubscription<EditorTransactionValue>? _changes;
  String _synced = '';
  bool _source = false;
  bool _uploading = false;
  bool _tall = false;

  /// The selection when a toolbar button was pressed: opening a menu can
  /// take it away from the editor.
  Selection? _savedSelection;

  @visibleForTesting
  EditorState get editorState => _editor;

  @override
  void initState() {
    super.initState();
    _load(widget.controller.text);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(RichCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _load(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _changes?.cancel();
    _editor.dispose();
    super.dispose();
  }

  void _load(String text) {
    _changes?.cancel();
    _synced = text;
    _editor = EditorState(document: markupToDocument(text));
    _changes = _editor.transactionStream.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _keepTablesInOrder();
      });
      final text = documentToMarkup(_editor.document);
      if (text == _synced) return;
      _synced = text;
      widget.controller.text = text;
    });
  }

  /// The card text was changed elsewhere (cleared after saving, or edited
  /// as code): show it.
  void _onControllerChanged() {
    if (_source || widget.controller.text == _synced) return;
    final old = _editor;
    setState(() => _load(widget.controller.text));
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Selection? get _selection => _editor.selection ?? _savedSelection;

  Future<void> _toggle(String key) async {
    final selection = _selection;
    if (selection == null) return;
    // Raised and lowered text exclude each other.
    if (!selection.isCollapsed &&
        (key == superscriptKey || key == subscriptKey)) {
      final other = key == superscriptKey ? subscriptKey : superscriptKey;
      await _editor.formatDelta(selection, {other: null});
    }
    await _editor.toggleAttribute(key, selection: selection);
  }

  Future<void> _format(Map<String, dynamic> attributes) async {
    final selection = _selection;
    if (selection == null || selection.isCollapsed) return;
    await _editor.formatDelta(selection, attributes);
  }

  Future<void> _clearFormatting() => _format({
    AppFlowyRichTextKeys.bold: null,
    AppFlowyRichTextKeys.italic: null,
    AppFlowyRichTextKeys.underline: null,
    AppFlowyRichTextKeys.strikethrough: null,
    AppFlowyRichTextKeys.textColor: null,
    AppFlowyRichTextKeys.backgroundColor: null,
    AppFlowyRichTextKeys.fontSize: null,
    superscriptKey: null,
    subscriptKey: null,
  });

  /// Turns the selected blocks into [type] (or back into paragraphs when
  /// they already are).
  Future<void> _setBlockType(String type, {int? level}) async {
    final selection = _selection;
    if (selection == null) return;
    final nodes = _editor.getNodesInSelection(selection);
    final already =
        nodes.isNotEmpty &&
        nodes.every(
          (n) =>
              n.type == type &&
              (level == null || n.attributes[HeadingBlockKeys.level] == level),
        );
    await _editor.formatNode(selection, (node) {
      if (node.delta == null) return node;
      final attributes = <String, dynamic>{
        'delta': node.delta!.toJson(),
        if (!already && level != null) HeadingBlockKeys.level: level,
        if (node.attributes[blockComponentAlign] != null)
          blockComponentAlign: node.attributes[blockComponentAlign],
      };
      return node.copyWith(
        type: already ? ParagraphBlockKeys.type : type,
        attributes: attributes,
      );
    });
  }

  Future<void> _align(String align) async {
    final selection = _selection;
    if (selection == null) return;
    await _editor.formatNode(
      selection,
      (node) => node.copyWith(
        attributes: {
          ...node.attributes,
          blockComponentAlign: align == 'left' ? null : align,
        },
      ),
    );
  }

  /// The top-level block the cursor is in.
  Node? _currentBlock() {
    final selection = _selection;
    if (selection == null) return null;
    var node = _editor.getNodeAtPath(selection.end.path);
    while (node != null && node.parent != null && node.parent!.parent != null) {
      node = node.parent;
    }
    return node;
  }

  Future<void> _insertBlock(Node block) async {
    final current = _currentBlock();
    final path = current == null
        ? [_editor.document.root.children.length]
        : current.path.next;
    final transaction = _editor.transaction
      ..insertNode(path, block)
      // Room to keep typing after it.
      ..insertNode(path.next, paragraphNode());
    await _editor.apply(transaction);
  }

  /// The table cell holding the cursor, and its table.
  (Node table, int row, int column)? _currentCell() {
    final selection = _selection;
    if (selection == null) return null;
    Node? node = _editor.getNodeAtPath(selection.start.path);
    while (node != null && node.type != TableCellBlockKeys.type) {
      node = node.parent;
    }
    final table = node?.parent;
    if (node == null || table == null) return null;
    return (
      table,
      node.attributes[TableCellBlockKeys.rowPosition] as int,
      node.attributes[TableCellBlockKeys.colPosition] as int,
    );
  }

  void _tableAction(String action) {
    if (action == 'insert') {
      _pickTableSize();
      return;
    }
    final cell = _currentCell();
    if (cell == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Click inside a table cell first.')),
      );
      return;
    }
    final (table, row, column) = cell;
    if (action == 'deleteTable') {
      _editor.apply(_editor.transaction..deleteNode(table));
      return;
    }
    final rows = tableRows(table);
    var hasHeader = table.attributes[tableHeaderKey] != false;
    final columns = rows.first.length;
    var (cursorRow, cursorColumn) = (row, column);
    List<Node> emptyRow() => [
      for (var c = 0; c < columns; c++) paragraphNode(),
    ];
    switch (action) {
      case 'rowAbove':
        rows.insert(row, emptyRow());
      case 'rowBelow':
        rows.insert(row + 1, emptyRow());
        cursorRow = row + 1;
      case 'colLeft':
        for (final r in rows) {
          r.insert(column, paragraphNode());
        }
      case 'colRight':
        for (final r in rows) {
          r.insert(column + 1, paragraphNode());
        }
        cursorColumn = column + 1;
      case 'deleteRow':
        if (rows.length == 1) return _tableAction('deleteTable');
        rows.removeAt(row);
        cursorRow = row.clamp(0, rows.length - 1);
      case 'deleteCol':
        if (columns == 1) return _tableAction('deleteTable');
        for (final r in rows) {
          r.removeAt(column);
        }
        cursorColumn = column.clamp(0, columns - 2);
      case 'header':
        hasHeader = !hasHeader;
    }
    _replaceTable(table, rows, hasHeader, cursorRow, cursorColumn);
  }

  /// Puts a rebuilt table (cells row by row) in place of [table].
  Future<void> _replaceTable(
    Node table,
    List<List<Node>> rows,
    bool hasHeader,
    int cursorRow,
    int cursorColumn,
  ) async {
    final path = table.path;
    final rebuilt = tableFromRows(rows, hasHeader: hasHeader);
    final columns = rows.isEmpty ? 0 : rows.first.length;
    final cellIndex = cursorRow * columns + cursorColumn;
    final transaction = _editor.transaction
      ..deleteNode(table)
      ..insertNode(path, rebuilt)
      ..afterSelection = Selection.collapsed(
        Position(path: [...path, cellIndex, 0]),
      );
    await _editor.apply(transaction);
  }

  /// The editor's own table menus add rows and columns column by column;
  /// put the cells back in reading order so clicks find the right cell.
  void _keepTablesInOrder() {
    for (final node in _editor.document.root.children) {
      if (node.type == TableBlockKeys.type && !isRowOrdered(node)) {
        final selection = _editor.selection;
        var (row, column) = (0, 0);
        if (selection != null) {
          Node? at = _editor.getNodeAtPath(selection.start.path);
          while (at != null && at.type != TableCellBlockKeys.type) {
            at = at.parent;
          }
          if (at != null && at.parent == node) {
            row = at.attributes[TableCellBlockKeys.rowPosition] as int? ?? 0;
            column = at.attributes[TableCellBlockKeys.colPosition] as int? ?? 0;
          }
        }
        _replaceTable(
          node,
          tableRows(node),
          node.attributes[tableHeaderKey] != false,
          row,
          column,
        );
        return;
      }
    }
  }

  Future<void> _pickTableSize() async {
    final size = await showDialog<(int, int)>(
      context: context,
      builder: (context) => const _TableGridDialog(),
    );
    if (size == null) return;
    await _insertBlock(emptyTableNode(size.$1, size.$2));
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
      await _insertBlock(imageNode(url: url));
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

  /// Puts the selected words in {curly braces}: a cloze deletion.
  Future<void> _cloze() async {
    final selection = _selection?.normalized;
    if (selection == null ||
        selection.isCollapsed ||
        selection.start.path != selection.end.path) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the words to hide (within one paragraph).'),
        ),
      );
      return;
    }
    final node = _editor.getNodeAtPath(selection.start.path);
    if (node == null || node.delta == null) return;
    final transaction = _editor.transaction
      ..insertText(node, selection.end.offset, '}')
      ..insertText(node, selection.start.offset, '{');
    await _editor.apply(transaction);
  }

  /// Clicking the empty space under the text puts the cursor at its end.
  Future<void> _focusEnd() async {
    final children = _editor.document.root.children;
    var last = children.isEmpty ? null : children.last;
    if (last == null || last.delta == null) {
      final path = [children.length];
      await _editor.apply(
        _editor.transaction..insertNode(path, paragraphNode()),
      );
      last = _editor.getNodeAtPath(path);
    }
    if (last == null) return;
    // As a click: the keyboard opens and typing goes there.
    await _editor.updateSelectionWithReason(
      Selection.collapsed(
        Position(path: last.path, offset: last.delta?.length ?? 0),
      ),
      reason: SelectionUpdateReason.uiEvent,
    );
  }

  void _toggleSource() {
    setState(() {
      _source = !_source;
      if (!_source) {
        final old = _editor;
        _load(widget.controller.text);
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    });
  }

  Widget _button(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    bool active = false,
    bool alwaysOn = false,
  }) => IconButton(
    tooltip: tooltip,
    isSelected: active,
    visualDensity: VisualDensity.compact,
    iconSize: 20,
    // While editing as code only the code and size buttons work.
    onPressed: _source && !alwaysOn ? null : onPressed,
    icon: Icon(icon),
  );

  Widget _colorMenu({
    required IconData icon,
    required String tooltip,
    required List<Color> colors,
    required String attribute,
  }) => PopupMenuButton<Color?>(
    tooltip: tooltip,
    enabled: !_source,
    icon: Icon(icon, size: 20),
    onSelected: (color) =>
        _format({attribute: color == null ? null : _colorCode(color)}),
    itemBuilder: (context) => [
      PopupMenuItem(
        enabled: false,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final color in colors)
              InkWell(
                onTap: () => Navigator.of(context).pop(color),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.black26),
                  ),
                ),
              ),
          ],
        ),
      ),
      const PopupMenuItem(value: null, child: Text('No colour')),
    ],
  );

  Widget _toolbar() {
    final selection = _editor.selection;
    bool isOn(String key) {
      if (selection == null) return _editor.toggledStyle[key] == true;
      final nodes = _editor.getNodesInSelection(selection);
      if (selection.isCollapsed) {
        return _editor.toggledStyle[key] ??
            nodes.allSatisfyInSelection(
              selection.copyWith(
                start: selection.start.copyWith(
                  offset: (selection.startIndex - 1).clamp(0, 1 << 30),
                ),
              ),
              (delta) => delta.everyAttributes((a) => a[key] == true),
            );
      }
      return nodes.allSatisfyInSelection(
        selection,
        (delta) => delta.everyAttributes((a) => a[key] == true),
      );
    }

    return Listener(
      // Remember the selection before a button or menu takes the focus.
      onPointerDown: (_) => _savedSelection = _editor.selection,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _button(Icons.undo, 'Undo', () => _editor.undoManager.undo()),
          _button(Icons.redo, 'Redo', () => _editor.undoManager.redo()),
          PopupMenuButton<String>(
            tooltip: 'Paragraph style',
            enabled: !_source,
            icon: const Icon(Icons.title, size: 20),
            onSelected: (value) => switch (value) {
              'p' => _setBlockType(ParagraphBlockKeys.type),
              'h1' => _setBlockType(HeadingBlockKeys.type, level: 1),
              'h2' => _setBlockType(HeadingBlockKeys.type, level: 2),
              'h3' => _setBlockType(HeadingBlockKeys.type, level: 3),
              _ => _setBlockType(QuoteBlockKeys.type),
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'p', child: Text('Paragraph')),
              PopupMenuItem(
                value: 'h1',
                child: Text(
                  'Heading 1',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              PopupMenuItem(
                value: 'h2',
                child: Text(
                  'Heading 2',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              PopupMenuItem(
                value: 'h3',
                child: Text(
                  'Heading 3',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              PopupMenuItem(
                value: 'quote',
                child: Text(
                  'Quote',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
          _button(
            Icons.format_bold,
            'Bold',
            () => _toggle(AppFlowyRichTextKeys.bold),
            active: isOn(AppFlowyRichTextKeys.bold),
          ),
          _button(
            Icons.format_italic,
            'Italic',
            () => _toggle(AppFlowyRichTextKeys.italic),
            active: isOn(AppFlowyRichTextKeys.italic),
          ),
          _button(
            Icons.format_underlined,
            'Underline',
            () => _toggle(AppFlowyRichTextKeys.underline),
            active: isOn(AppFlowyRichTextKeys.underline),
          ),
          _button(
            Icons.format_strikethrough,
            'Strikethrough',
            () => _toggle(AppFlowyRichTextKeys.strikethrough),
            active: isOn(AppFlowyRichTextKeys.strikethrough),
          ),
          _button(
            Icons.superscript,
            'Superscript',
            () => _toggle(superscriptKey),
            active: isOn(superscriptKey),
          ),
          _button(
            Icons.subscript,
            'Subscript',
            () => _toggle(subscriptKey),
            active: isOn(subscriptKey),
          ),
          _colorMenu(
            icon: Icons.format_color_text,
            tooltip: 'Text colour',
            colors: _textColors,
            attribute: AppFlowyRichTextKeys.textColor,
          ),
          _colorMenu(
            icon: Icons.format_color_fill,
            tooltip: 'Highlight colour',
            colors: _highlightColors,
            attribute: AppFlowyRichTextKeys.backgroundColor,
          ),
          _button(Icons.format_clear, 'Clear formatting', _clearFormatting),
          _button(
            Icons.format_list_bulleted,
            'Bulleted list',
            () => _setBlockType(BulletedListBlockKeys.type),
          ),
          _button(
            Icons.format_list_numbered,
            'Numbered list',
            () => _setBlockType(NumberedListBlockKeys.type),
          ),
          _button(Icons.format_align_left, 'Align left', () => _align('left')),
          _button(
            Icons.format_align_center,
            'Align centre',
            () => _align('center'),
          ),
          _button(
            Icons.format_align_right,
            'Align right',
            () => _align('right'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Table',
            enabled: !_source,
            icon: const Icon(Icons.table_chart_outlined, size: 20),
            onSelected: _tableAction,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'insert', child: Text('Insert table…')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'rowAbove', child: Text('Row above')),
              PopupMenuItem(value: 'rowBelow', child: Text('Row below')),
              PopupMenuItem(value: 'colLeft', child: Text('Column left')),
              PopupMenuItem(value: 'colRight', child: Text('Column right')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'deleteRow', child: Text('Delete row')),
              PopupMenuItem(value: 'deleteCol', child: Text('Delete column')),
              PopupMenuItem(value: 'header', child: Text('Header row on/off')),
              PopupMenuItem(value: 'deleteTable', child: Text('Delete table')),
            ],
          ),
          _uploading
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _button(
                  Icons.add_photo_alternate_outlined,
                  'Insert image',
                  _insertImage,
                ),
          _button(
            Icons.horizontal_rule,
            'Horizontal line',
            () => _insertBlock(dividerNode()),
          ),
          _button(Icons.data_object, 'Cloze: hide the selected words', _cloze),
          ...widget.extraActions,
          _button(
            _tall ? Icons.unfold_less : Icons.unfold_more,
            _tall ? 'Smaller' : 'Expand',
            () => setState(() => _tall = !_tall),
            alwaysOn: true,
          ),
          _button(
            Icons.code,
            _source ? 'Back to the editor' : 'Edit as code',
            _toggleSource,
            active: _source,
            alwaysOn: true,
          ),
        ],
      ),
    );
  }

  EditorStyle _style(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme.bodyLarge!.copyWith(
      color: theme.colorScheme.onSurface,
      fontSize: 16,
    );
    InlineSpan decorate(
      BuildContext context,
      Node node,
      int index,
      TextInsert insert,
      TextSpan before,
      TextSpan after,
    ) {
      final attributes = insert.attributes ?? const {};
      final raised = attributes[superscriptKey] == true;
      final lowered = attributes[subscriptKey] == true;
      final span = defaultTextSpanDecoratorForAttribute(
        context,
        node,
        index,
        insert,
        before,
        after,
      );
      if (!raised && !lowered) return span;
      final style = span.style ?? text;
      return TextSpan(
        text: span.text,
        children: span.children,
        recognizer: span.recognizer,
        style: style.copyWith(
          fontSize: (style.fontSize ?? 16) * 0.7,
          fontFeatures: [
            raised
                ? const FontFeature.superscripts()
                : const FontFeature.subscripts(),
          ],
        ),
      );
    }

    final configuration = TextStyleConfiguration(text: text);
    final isDesktop =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
    return isDesktop
        ? EditorStyle.desktop(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            cursorColor: theme.colorScheme.primary,
            selectionColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            textStyleConfiguration: configuration,
            textSpanDecorator: decorate,
          )
        : EditorStyle.mobile(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            cursorColor: theme.colorScheme.primary,
            selectionColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            textStyleConfiguration: configuration,
            textSpanDecorator: decorate,
          );
  }

  Map<String, BlockComponentBuilder> get _builders => {
    ...standardBlockComponentBuilderMap,
    // No "type / for commands" hint in empty lines.
    ParagraphBlockKeys.type: ParagraphBlockComponentBuilder(
      configuration: const BlockComponentConfiguration().copyWith(
        placeholderText: (_) => '',
      ),
    ),
    TableBlockKeys.type: _TableBuilder(),
    TableCellBlockKeys.type: _CellBuilder(),
    occlusionNodeType: DividerBlockComponentBuilder(
      lineColor: Colors.transparent,
      height: 2,
      wrapper: (context, node, child) {
        final line = node.attributes[occlusionLineKey] as String? ?? '';
        final block = parseCardMarkup(line).firstOrNull;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (block is OcclusionBlock)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: OcclusionImage(block: block, maxWidth: 420),
              ),
            child,
          ],
        );
      },
    ),
  };

  @override
  Widget build(BuildContext context) {
    // The editor's own texts (menus, placeholders).
    return Localizations.override(
      context: context,
      delegates: const [AppFlowyEditorLocalizations.delegate],
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final error = widget.errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 2),
          child: Text(
            widget.label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: colors.primary),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: error != null ? colors.error : colors.outline,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: colors.surfaceContainerHigh,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _toolbar(),
              ),
              SizedBox(
                // The editing area scrolls inside, like Anki's editor.
                height: _tall ? 560 : 280,
                child: _source
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextField(
                          controller: widget.controller,
                          expands: true,
                          minLines: null,
                          maxLines: null,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            helperText:
                                'The card codes. Tap </> again to go back.',
                          ),
                        ),
                      )
                    : Listener(
                        // A click that didn't land on text (the empty space
                        // under it) puts the cursor at the end.
                        onPointerUp: (_) => Future.delayed(
                          const Duration(milliseconds: 80),
                          () {
                            if (mounted &&
                                !_source &&
                                _editor.selection == null) {
                              _focusEnd();
                            }
                          },
                        ),
                        child: AppFlowyEditor(
                          key: ObjectKey(_editor),
                          editorState: _editor,
                          editorStyle: _style(context),
                          blockComponentBuilders: _builders,
                          // Typing "/" is just a slash here.
                          characterShortcutEvents: [
                            for (final event in standardCharacterShortcutEvents)
                              if (event.character != '/') event,
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              error,
              style: TextStyle(color: colors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

/// Pick a table size on a grid, like in Anki's editor.
class _TableGridDialog extends StatefulWidget {
  const _TableGridDialog();

  @override
  State<_TableGridDialog> createState() => _TableGridDialogState();
}

class _TableGridDialogState extends State<_TableGridDialog> {
  static const _max = 8;
  int _rows = 3;
  int _columns = 2;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Insert table'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 1; r <= _max; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 1; c <= _max; c++)
                  MouseRegion(
                    onEnter: (_) => setState(() {
                      _rows = r;
                      _columns = c;
                    }),
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop((r, c)),
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: r <= _rows && c <= _columns
                              ? colors.primary.withValues(alpha: 0.6)
                              : colors.surfaceContainerHighest,
                          border: Border.all(color: colors.outlineVariant),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Text('$_rows rows × $_columns columns (first row is the header)'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((_rows, _columns)),
          child: const Text('Insert'),
        ),
      ],
    );
  }
}

/// A table cell: just its text (the header row shaded). The editor's own
/// cell also has hover handles laid over the next cell, which catch clicks
/// meant for it; rows and columns are added and removed from the toolbar's
/// Table menu instead.
class _CellBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _CellWidget(key: node.key, node: node, configuration: configuration);
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.children.isNotEmpty;
}

class _CellWidget extends BlockComponentStatefulWidget {
  const _CellWidget({
    super.key,
    required super.node,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<_CellWidget> createState() => _CellWidgetState();
}

class _CellWidgetState extends State<_CellWidget> {
  @override
  Widget build(BuildContext context) {
    final editorState = context.read<EditorState>();
    final node = widget.node;
    final isHeader =
        node.attributes[TableCellBlockKeys.rowPosition] == 0 &&
        node.parent?.attributes[tableHeaderKey] != false;
    return Container(
      // The same height the table draws its lines at.
      constraints: const BoxConstraints(minHeight: 36),
      alignment: Alignment.centerLeft,
      color: isHeader
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: editorState.renderer.build(context, node.children.first),
    );
  }
}

/// A table: a plain grid of its cells, left-aligned.
class _TableBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return _TableWidget(
      key: node.key,
      node: node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.children.isNotEmpty;
}

class _TableWidget extends BlockComponentStatefulWidget {
  const _TableWidget({
    super.key,
    required super.node,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<_TableWidget> createState() => _TableWidgetState();
}

class _TableWidgetState extends State<_TableWidget> {
  @override
  Widget build(BuildContext context) {
    final editorState = context.read<EditorState>();
    final node = widget.node;
    final columns = node.attributes[TableBlockKeys.colsLen] as int? ?? 0;
    final rows = node.attributes[TableBlockKeys.rowsLen] as int? ?? 0;
    Node? cell(int r, int c) {
      for (final child in node.children) {
        if (child.attributes[TableCellBlockKeys.rowPosition] == r &&
            child.attributes[TableCellBlockKeys.colPosition] == c) {
          return child;
        }
      }
      return null;
    }

    final border = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Table(
        border: TableBorder.all(color: border),
        defaultColumnWidth: const FlexColumnWidth(),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          for (var r = 0; r < rows; r++)
            TableRow(
              children: [
                for (var c = 0; c < columns; c++)
                  if (cell(r, c) case final Node found)
                    editorState.renderer.build(context, found)
                  else
                    const SizedBox(height: 36),
              ],
            ),
        ],
      ),
    );
  }
}
