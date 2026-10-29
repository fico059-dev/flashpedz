import 'package:appflowy_editor/appflowy_editor.dart';
// ignore: implementation_imports
import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_config.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';

/// Converts between card text (the card markup the app stores and shows)
/// and the rich editor's document.

/// Text attributes the editor has no key for.
const superscriptKey = 'superscript';
const subscriptKey = 'subscript';

/// A node holding an image-occlusion line, shown as the image and boxes.
const occlusionNodeType = 'card_occlusion';
const occlusionLineKey = 'line';

/// Whether a table's first row is a header.
const tableHeaderKey = 'card_has_header';

final _bullet = RegExp(r'^\s*[•\-\*]\s+');
final _number = RegExp(r'^\s*(\d+)[.)]\s+');
final _imageLine = RegExp(r'^\s*!\[[^\]\n]*\]\((https?://[^\s)]+)\)\s*$');
final _tableRow = RegExp(r'^\s*\|.*\|\s*$');
final _tableSeparator = RegExp(
  r'^\s*\|?(\s*:?-{2,}:?\s*\|)+\s*:?-{0,}:?\s*\|?\s*$',
);
final _occlusionLine = RegExp(r'^\s*\[occlusion\]\(');
final _lineCode = RegExp(r'^\[(h[1-3]|quote|center|right|justify)\] ?');

/// Card text → editor document.
Document markupToDocument(String text) {
  final nodes = <Node>[];
  final lines = text.split('\n');
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (_tableRow.hasMatch(line)) {
      final rows = <List<String>>[];
      var hasHeader = false;
      while (i < lines.length && _tableRow.hasMatch(lines[i])) {
        if (_tableSeparator.hasMatch(lines[i])) {
          if (rows.length == 1) hasHeader = true;
        } else {
          rows.add(_cells(lines[i]));
        }
        i++;
      }
      if (rows.isNotEmpty) nodes.add(_tableNode(rows, hasHeader));
      continue;
    }
    i++;
    if (_occlusionLine.hasMatch(line) &&
        parseCardMarkup(line).firstOrNull is OcclusionBlock) {
      nodes.add(
        Node(
          type: occlusionNodeType,
          attributes: {occlusionLineKey: line.trim()},
        ),
      );
      continue;
    }
    final image = _imageLine.firstMatch(line);
    if (image != null) {
      nodes.add(imageNode(url: image.group(1)!));
      continue;
    }
    if (line.trim() == '[hr]') {
      nodes.add(dividerNode());
      continue;
    }
    final code = _lineCode.firstMatch(line);
    if (code != null) {
      final delta = inlineToDelta(line.substring(code.end));
      nodes.add(switch (code.group(1)!) {
        'h1' => headingNode(level: 1, delta: delta),
        'h2' => headingNode(level: 2, delta: delta),
        'h3' => headingNode(level: 3, delta: delta),
        'quote' => quoteNode(delta: delta),
        final align => paragraphNode(
          delta: delta,
          attributes: {
            'delta': delta.toJson(),
            blockComponentAlign: align == 'justify' ? 'left' : align,
          },
        ),
      });
      continue;
    }
    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      nodes.add(
        bulletedListNode(delta: inlineToDelta(line.substring(bullet.end))),
      );
      continue;
    }
    final number = _number.firstMatch(line);
    if (number != null) {
      nodes.add(
        numberedListNode(
          delta: inlineToDelta(line.substring(number.end)),
          number: int.parse(number.group(1)!),
        ),
      );
      continue;
    }
    nodes.add(paragraphNode(delta: inlineToDelta(line)));
  }
  if (nodes.isEmpty) nodes.add(paragraphNode());
  return Document(root: pageNode(children: nodes));
}

List<String> _cells(String line) {
  var content = line.trim();
  if (content.startsWith('|')) content = content.substring(1);
  if (content.endsWith('|')) content = content.substring(0, content.length - 1);
  return content.split('|').map((c) => c.trim()).toList();
}

/// A table from rows of cell texts (card markup inside the cells).
Node _tableNode(List<List<String>> rows, bool hasHeader) {
  final width = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
  return tableFromRows([
    for (final row in rows)
      [
        for (var c = 0; c < width; c++)
          paragraphNode(delta: inlineToDelta(c < row.length ? row[c] : '')),
      ],
  ], hasHeader: hasHeader);
}

/// A table from rows of cell contents. Its cells are kept row by row: the
/// editor finds the clicked cell by going through them in reading order.
Node tableFromRows(List<List<Node>> rows, {required bool hasHeader}) {
  final columns = rows.isEmpty ? 0 : rows.first.length;
  final table = Node(
    type: TableBlockKeys.type,
    attributes: {
      TableBlockKeys.colsLen: columns,
      TableBlockKeys.rowsLen: rows.length,
      ...TableConfig().toJson(),
      tableHeaderKey: hasHeader,
    },
  );
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < columns; c++) {
      table.insert(
        Node(
          type: TableCellBlockKeys.type,
          attributes: {
            TableCellBlockKeys.colPosition: c,
            TableCellBlockKeys.rowPosition: r,
          },
        )..insert(rows[r][c]),
      );
    }
  }
  return table;
}

/// The cell contents of [table], row by row (copies).
List<List<Node>> tableRows(Node table) {
  final columns = table.attributes[TableBlockKeys.colsLen] as int? ?? 0;
  final rowCount = table.attributes[TableBlockKeys.rowsLen] as int? ?? 0;
  Node content(int c, int r) {
    for (final cell in table.children) {
      if (cell.attributes[TableCellBlockKeys.colPosition] == c &&
          cell.attributes[TableCellBlockKeys.rowPosition] == r &&
          cell.children.isNotEmpty) {
        return Node.fromJson(cell.children.first.toJson());
      }
    }
    return paragraphNode();
  }

  return [
    for (var r = 0; r < rowCount; r++)
      [for (var c = 0; c < columns; c++) content(c, r)],
  ];
}

/// Whether [table]'s cells are stored row by row.
bool isRowOrdered(Node table) {
  var previous = (-1, -1);
  for (final cell in table.children) {
    final position = (
      cell.attributes[TableCellBlockKeys.rowPosition] as int? ?? 0,
      cell.attributes[TableCellBlockKeys.colPosition] as int? ?? 0,
    );
    if (position.$1 < previous.$1 ||
        (position.$1 == previous.$1 && position.$2 <= previous.$2)) {
      return false;
    }
    previous = position;
  }
  return true;
}

/// An empty table of [rows] × [columns], the first row a header.
Node emptyTableNode(int rows, int columns) => _tableNode([
  for (var r = 0; r < rows; r++) [for (var c = 0; c < columns; c++) ''],
], true);

String _hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

int? _parseColor(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^(?:#|0x)(?:[0-9a-fA-F]{2})?([0-9a-fA-F]{6})$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  return 0xFF000000 | int.parse(match.group(1)!, radix: 16);
}

/// One line of card markup → editor text with attributes.
Delta inlineToDelta(String text) {
  final delta = Delta();
  for (final run in parseInline(text).runs) {
    final attributes = <String, dynamic>{
      if (run.bold) AppFlowyRichTextKeys.bold: true,
      if (run.italic) AppFlowyRichTextKeys.italic: true,
      if (run.underline) AppFlowyRichTextKeys.underline: true,
      if (run.strike) AppFlowyRichTextKeys.strikethrough: true,
      if (run.size != null) AppFlowyRichTextKeys.fontSize: run.size,
      if (run.color != null) AppFlowyRichTextKeys.textColor: _hex(run.color!),
      if (run.background != null)
        AppFlowyRichTextKeys.backgroundColor: _hex(run.background!),
      if (run.script == Script.superscript) superscriptKey: true,
      if (run.script == Script.subscript) subscriptKey: true,
    };
    delta.insert(run.text, attributes: attributes.isEmpty ? null : attributes);
  }
  return delta;
}

/// Editor text → one line of card markup. Line breaks become spaces (a
/// card line can't hold them).
String deltaToInline(Delta? delta) {
  if (delta == null) return '';
  final out = StringBuffer();
  for (final op in delta.whereType<TextInsert>()) {
    final text = op.text.replaceAll('\n', ' ');
    final a = op.attributes ?? const {};
    // Spaces stay outside the codes: **bold** needs letters at its edges.
    final lead = RegExp(r'^\s*').stringMatch(text)!;
    final trail = text.trim().isEmpty ? '' : RegExp(r'\s*$').stringMatch(text)!;
    var core = text.substring(lead.length, text.length - trail.length);
    if (core.isEmpty) {
      out.write(text);
      continue;
    }
    if (a[superscriptKey] == true) core = '[sup]$core[/sup]';
    if (a[subscriptKey] == true) core = '[sub]$core[/sub]';
    if (a[AppFlowyRichTextKeys.strikethrough] == true) core = '[s]$core[/s]';
    if (a[AppFlowyRichTextKeys.italic] == true) core = '[i]$core[/i]';
    if (a[AppFlowyRichTextKeys.underline] == true) core = '__${core}__';
    if (a[AppFlowyRichTextKeys.bold] == true) core = '**$core**';
    final size = a[AppFlowyRichTextKeys.fontSize];
    if (size is num) {
      core = '[size=${size.round().clamp(8, 48)}]$core[/size]';
    }
    final background = _parseColor(a[AppFlowyRichTextKeys.backgroundColor]);
    if (background != null) core = '[bg=${_hex(background)}]$core[/bg]';
    final color = _parseColor(a[AppFlowyRichTextKeys.textColor]);
    if (color != null) core = '[color=${_hex(color)}]$core[/color]';
    out
      ..write(lead)
      ..write(core)
      ..write(trail);
  }
  return out.toString();
}

/// Editor document → card text.
String documentToMarkup(Document document) {
  final lines = <String>[];
  var number = 0;

  void addNode(Node node, String indent) {
    final delta = node.delta;
    if (node.type != NumberedListBlockKeys.type) number = 0;
    switch (node.type) {
      case BulletedListBlockKeys.type:
        lines.add('$indent• ${deltaToInline(delta)}');
      case NumberedListBlockKeys.type:
        // A list may start at another number (e.g. after a paragraph).
        final start = node.attributes[NumberedListBlockKeys.number];
        number = number == 0 && start is int && start > 0 ? start : number + 1;
        lines.add('$indent$number. ${deltaToInline(delta)}');
      case HeadingBlockKeys.type:
        final level = (node.attributes[HeadingBlockKeys.level] as int? ?? 1)
            .clamp(1, 3);
        lines.add('[h$level] ${deltaToInline(delta)}');
      case QuoteBlockKeys.type:
        lines.add('[quote] ${deltaToInline(delta)}');
      case DividerBlockKeys.type:
        lines.add('[hr]');
      case ImageBlockKeys.type:
        final url = node.attributes[ImageBlockKeys.url];
        if (url is String && url.startsWith('http')) {
          lines.add('![image]($url)');
        }
      case occlusionNodeType:
        final line = node.attributes[occlusionLineKey];
        if (line is String) lines.add(line);
      case TableBlockKeys.type:
        lines.addAll(_tableLines(node));
      default:
        final align = node.attributes[blockComponentAlign];
        final code = align == 'center' || align == 'right' ? '[$align] ' : '';
        lines.add('$code${deltaToInline(delta)}');
    }
    // Items inside list items are indented.
    if (node.type != TableBlockKeys.type) {
      final saved = number;
      number = 0;
      for (final child in node.children) {
        addNode(child, '$indent  ');
      }
      number = saved;
    }
  }

  for (final node in document.root.children) {
    addNode(node, '');
  }
  // No empty lines at the end.
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

List<String> _tableLines(Node table) {
  final columns = table.attributes[TableBlockKeys.colsLen] as int? ?? 0;
  final rows = table.attributes[TableBlockKeys.rowsLen] as int? ?? 0;
  if (columns == 0 || rows == 0) return const [];
  String cell(int c, int r) {
    final node = table.children.firstWhere(
      (n) =>
          n.attributes[TableCellBlockKeys.colPosition] == c &&
          n.attributes[TableCellBlockKeys.rowPosition] == r,
      orElse: () => Node(type: TableCellBlockKeys.type),
    );
    final text = node.children
        .map((child) => deltaToInline(child.delta))
        .where((t) => t.isNotEmpty)
        .join(' ')
        // A | would split the cell.
        .replaceAll('|', '/');
    return text.isEmpty ? ' ' : text;
  }

  final hasHeader = table.attributes[tableHeaderKey] != false;
  return [
    for (var r = 0; r < rows; r++) ...[
      '| ${[for (var c = 0; c < columns; c++) cell(c, r)].join(' | ')} |',
      if (r == 0 && hasHeader) '|${List.filled(columns, '------').join('|')}|',
    ],
  ];
}
