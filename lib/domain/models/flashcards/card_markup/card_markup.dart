/// Simple formatting inside card text, written by the admin card editor:
///
///   **bold**          __underline__        [size=22]bigger[/size]
///   ![image](https://...)                  (an image, a card can have many)
///   | Header | Header |                    (a table: lines between |...|)
///   |--------|--------|
///   | cell   | cell   |
///
/// Curly braces are left alone: they mark cloze deletions.
library;

/// Raised or lowered text.
enum Script { normal, superscript, subscript }

/// A stretch of text with one style.
class StyledRun {
  final String text;
  final bool bold;
  final bool underline;
  final double? size;
  final bool italic;
  final bool strike;
  final Script script;

  /// Text and background colours as 0xAARRGGBB, if any.
  final int? color;
  final int? background;

  const StyledRun(
    this.text, {
    this.bold = false,
    this.underline = false,
    this.size,
    this.italic = false,
    this.strike = false,
    this.script = Script.normal,
    this.color,
    this.background,
  });

  bool get isPlain =>
      !bold &&
      !underline &&
      size == null &&
      !italic &&
      !strike &&
      script == Script.normal &&
      color == null &&
      background == null;

  /// The same style with other text.
  StyledRun withText(String text) => StyledRun(
    text,
    bold: bold,
    underline: underline,
    size: size,
    italic: italic,
    strike: strike,
    script: script,
    color: color,
    background: background,
  );

  StyledRun copyWith({
    bool? bold,
    bool? underline,
    double? size,
    bool? italic,
    bool? strike,
    Script? script,
    int? color,
    int? background,
  }) => StyledRun(
    text,
    bold: bold ?? this.bold,
    underline: underline ?? this.underline,
    size: size ?? this.size,
    italic: italic ?? this.italic,
    strike: strike ?? this.strike,
    script: script ?? this.script,
    color: color ?? this.color,
    background: background ?? this.background,
  );

  bool sameStyle(StyledRun other) =>
      other.bold == bold &&
      other.underline == underline &&
      other.size == size &&
      other.italic == italic &&
      other.strike == strike &&
      other.script == script &&
      other.color == color &&
      other.background == background;

  @override
  bool operator ==(Object other) =>
      other is StyledRun && other.text == text && sameStyle(other);

  @override
  int get hashCode => Object.hash(
    text,
    bold,
    underline,
    size,
    italic,
    strike,
    script,
    color,
    background,
  );

  @override
  String toString() =>
      'StyledRun("$text"${bold ? ', bold' : ''}'
      '${underline ? ', underline' : ''}${size != null ? ', size: $size' : ''}'
      '${italic ? ', italic' : ''}${strike ? ', strike' : ''}'
      '${script != Script.normal ? ', $script' : ''}'
      '${color != null ? ', color: ${color!.toRadixString(16)}' : ''}'
      '${background != null ? ', bg: ${background!.toRadixString(16)}' : ''})';
}

/// Formatted text: its plain characters and their styles.
class RichLine {
  final List<StyledRun> runs;

  const RichLine(this.runs);

  String get plainText => runs.map((r) => r.text).join();
}

sealed class CardBlock {
  const CardBlock();
}

/// How a paragraph is laid out.
enum LineStyle { normal, h1, h2, h3, quote, center, right, justify }

class TextBlock extends CardBlock {
  final RichLine text;
  final LineStyle style;
  const TextBlock(this.text, {this.style = LineStyle.normal});
}

/// A horizontal line.
class DividerBlock extends CardBlock {
  const DividerBlock();
}

class ImageBlock extends CardBlock {
  final String url;
  const ImageBlock(this.url);
}

class TableBlock extends CardBlock {
  final List<List<RichLine>> rows;

  /// The first row is a header (a |---| line follows it).
  final bool hasHeader;

  const TableBlock(this.rows, {required this.hasHeader});
}

/// A box over part of an image-occlusion image, as fractions of the
/// image's width and height.
class OcclusionMask {
  final double x, y, w, h;

  const OcclusionMask(this.x, this.y, this.w, this.h);

  String encode() => [x, y, w, h].map((v) => v.toStringAsFixed(4)).join(',');

  @override
  bool operator ==(Object other) =>
      other is OcclusionMask &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);
}

/// An image with boxes hiding parts of it, like Anki's image occlusion:
/// the box asked about ([target]) is shown in orange, the others in grey.
/// On the answer ([revealed]) the target box is uncovered.
class OcclusionBlock extends CardBlock {
  final String url;
  final List<OcclusionMask> masks;
  final int target;
  final bool revealed;

  const OcclusionBlock({
    required this.url,
    required this.masks,
    required this.target,
    required this.revealed,
  });
}

/// The card line of an image-occlusion card: `[occlusion](url)[masks]#n`,
/// with `!` at the end on the answer side. Square brackets, as curly ones
/// are cloze deletions.
String occlusionLine({
  required String url,
  required List<OcclusionMask> masks,
  required int target,
  bool revealed = false,
}) =>
    '[occlusion]($url)[${masks.map((m) => m.encode()).join(';')}]'
    '#$target${revealed ? '!' : ''}';

final _occlusion = RegExp(
  r'^\s*\[occlusion\]\((https?://[^\s)]+)\)\[([0-9.,;]*)\]#(\d+)(!?)\s*$',
);

OcclusionBlock? _parseOcclusion(String line) {
  final match = _occlusion.firstMatch(line);
  if (match == null) return null;
  final masks = <OcclusionMask>[];
  for (final part in match.group(2)!.split(';')) {
    final values = part.split(',').map(double.tryParse).toList();
    if (values.length != 4 || values.contains(null)) continue;
    masks.add(OcclusionMask(values[0]!, values[1]!, values[2]!, values[3]!));
  }
  return OcclusionBlock(
    url: match.group(1)!,
    masks: masks,
    target: int.parse(match.group(3)!),
    revealed: match.group(4) == '!',
  );
}

final _image = RegExp(r'!\[[^\]\n]*\]\((https?://[^\s)]+)\)');
final _tableLine = RegExp(r'^\s*\|.*\|\s*$');
final _separator = RegExp(r'^\s*\|?(\s*:?-{2,}:?\s*\|)+\s*:?-{0,}:?\s*\|?\s*$');
final _bold = RegExp(r'\*\*(?=\S)([\s\S]*?\S)\*\*');
final _underline = RegExp(r'__(?=[^\s_])([\s\S]*?[^\s_])__(?!_)');
final _size = RegExp(r'\[size=(\d{1,2})\]([\s\S]*?)\[/size\]');
final _italic = RegExp(r'\[i\]([\s\S]*?)\[/i\]');
final _strike = RegExp(r'\[s\]([\s\S]*?)\[/s\]');
final _sup = RegExp(r'\[sup\]([\s\S]*?)\[/sup\]');
final _sub = RegExp(r'\[sub\]([\s\S]*?)\[/sub\]');
final _color = RegExp(r'\[color=#([0-9a-fA-F]{6})\]([\s\S]*?)\[/color\]');
final _bg = RegExp(r'\[bg=#([0-9a-fA-F]{6})\]([\s\S]*?)\[/bg\]');

/// A paragraph's look, set by a code at the start of its line:
/// `[h1]` – `[h3]` headings, `[quote]`, `[center]` / `[right]` alignment.
final _lineStyle = RegExp(r'^\[(h[1-3]|quote|center|right|justify)\] ?');
final _divider = RegExp(r'^\s*\[hr\]\s*$');

/// Whether [text] uses any formatting. Cards without it are shown exactly as
/// before.
bool hasCardMarkup(String text) =>
    text.split('\n').any(_occlusion.hasMatch) ||
    _image.hasMatch(text) ||
    _bold.hasMatch(text) ||
    _underline.hasMatch(text) ||
    _size.hasMatch(text) ||
    _italic.hasMatch(text) ||
    _strike.hasMatch(text) ||
    _sup.hasMatch(text) ||
    _sub.hasMatch(text) ||
    _color.hasMatch(text) ||
    _bg.hasMatch(text) ||
    text.split('\n').any((l) => _lineStyle.hasMatch(l) || _divider.hasMatch(l)) ||
    _hasTable(text);

bool _hasTable(String text) => text.split('\n').any(_tableLine.hasMatch);

/// Splits card text into paragraphs, tables and images.
List<CardBlock> parseCardMarkup(String text) {
  final blocks = <CardBlock>[];
  final lines = text.split('\n');
  final paragraph = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    final joined = paragraph.join('\n');
    paragraph.clear();
    // Images may sit in the middle of text.
    var position = 0;
    for (final match in _image.allMatches(joined)) {
      final before = _trimNewlines(joined.substring(position, match.start));
      if (before.isNotEmpty) blocks.add(TextBlock(parseInline(before)));
      blocks.add(ImageBlock(match.group(1)!));
      position = match.end;
    }
    final rest = _trimNewlines(joined.substring(position));
    if (rest.isNotEmpty) blocks.add(TextBlock(parseInline(rest)));
  }

  var i = 0;
  while (i < lines.length) {
    final occlusion = _parseOcclusion(lines[i]);
    if (occlusion != null) {
      flushParagraph();
      blocks.add(occlusion);
      i++;
      continue;
    }
    if (_divider.hasMatch(lines[i])) {
      flushParagraph();
      blocks.add(const DividerBlock());
      i++;
      continue;
    }
    final lineStyle = _lineStyle.firstMatch(lines[i]);
    if (lineStyle != null) {
      flushParagraph();
      final style = LineStyle.values.byName(lineStyle.group(1)!);
      final rest = lines[i].substring(lineStyle.end);
      blocks.add(TextBlock(parseInline(rest), style: style));
      i++;
      continue;
    }
    if (_tableLine.hasMatch(lines[i])) {
      flushParagraph();
      final rows = <List<RichLine>>[];
      var hasHeader = false;
      while (i < lines.length && _tableLine.hasMatch(lines[i])) {
        if (_separator.hasMatch(lines[i])) {
          if (rows.length == 1) hasHeader = true;
        } else {
          rows.add(_cells(lines[i]).map(parseInline).toList());
        }
        i++;
      }
      if (rows.isNotEmpty) {
        // Every row gets the same number of cells.
        final width = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
        for (final row in rows) {
          while (row.length < width) {
            row.add(const RichLine([]));
          }
        }
        blocks.add(TableBlock(rows, hasHeader: hasHeader));
      }
      continue;
    }
    paragraph.add(lines[i]);
    i++;
  }
  flushParagraph();
  return blocks;
}

List<String> _cells(String line) {
  var content = line.trim();
  if (content.startsWith('|')) content = content.substring(1);
  if (content.endsWith('|')) content = content.substring(0, content.length - 1);
  return content.split('|').map((c) => c.trim()).toList();
}

String _trimNewlines(String text) => text.replaceAll(RegExp(r'^\n+|\n+$'), '');

/// Bold, underline and size inside one piece of text. They can be nested.
RichLine parseInline(String text) =>
    RichLine(_inline(text, const StyledRun('')));

List<StyledRun> _inline(String text, StyledRun style) {
  final runs = <StyledRun>[];
  var position = 0;
  while (position < text.length) {
    // The formatting that starts first wins.
    RegExpMatch? first;
    var kind = '';
    final rest = text.substring(position);
    for (final (pattern, name) in [
      (_size, 'size'),
      (_bold, 'bold'),
      (_underline, 'underline'),
      (_italic, 'italic'),
      (_strike, 'strike'),
      (_sup, 'sup'),
      (_sub, 'sub'),
      (_color, 'color'),
      (_bg, 'bg'),
    ]) {
      final match = pattern.firstMatch(rest);
      if (match != null && (first == null || match.start < first.start)) {
        first = match;
        kind = name;
      }
    }
    if (first == null) {
      runs.add(style.withText(rest));
      break;
    }
    if (first.start > 0) {
      runs.add(style.withText(rest.substring(0, first.start)));
    }
    int hex(String value) => 0xFF000000 | int.parse(value, radix: 16);
    final (inner, content) = switch (kind) {
      'size' => (
        style.copyWith(
          size: double.parse(first.group(1)!).clamp(8, 48).toDouble(),
        ),
        first.group(2)!,
      ),
      'bold' => (style.copyWith(bold: true), first.group(1)!),
      'underline' => (style.copyWith(underline: true), first.group(1)!),
      'italic' => (style.copyWith(italic: true), first.group(1)!),
      'strike' => (style.copyWith(strike: true), first.group(1)!),
      'sup' => (style.copyWith(script: Script.superscript), first.group(1)!),
      'sub' => (style.copyWith(script: Script.subscript), first.group(1)!),
      'color' => (style.copyWith(color: hex(first.group(1)!)), first.group(2)!),
      _ => (style.copyWith(background: hex(first.group(1)!)), first.group(2)!),
    };
    runs.addAll(_inline(content, inner.withText('')));
    position += first.end;
  }
  return _merge(runs.where((r) => r.text.isNotEmpty).toList());
}

/// Joins neighbouring runs with the same style.
List<StyledRun> _merge(List<StyledRun> runs) {
  final merged = <StyledRun>[];
  for (final run in runs) {
    if (merged.isNotEmpty && merged.last.sameStyle(run)) {
      merged[merged.length - 1] = merged.last.withText(
        merged.last.text + run.text,
      );
      continue;
    }
    merged.add(run);
  }
  return merged;
}

/// The card text without formatting codes, for lists and previews.
String plainCardText(String text) {
  if (!hasCardMarkup(text)) return text;
  return parseCardMarkup(text)
      .map(
        (block) => switch (block) {
          TextBlock(:final text) => text.plainText,
          ImageBlock() => '[image]',
          DividerBlock() => '',
          OcclusionBlock() => '[image occlusion]',
          TableBlock(:final rows) =>
            rows
                .map((row) => row.map((cell) => cell.plainText).join(' | '))
                .join('\n'),
        },
      )
      .join('\n');
}

/// A table with [rows] × [columns] cells, ready to fill in.
String tableTemplate(int rows, int columns) {
  final header =
      '| ${List.generate(columns, (i) => 'Header ${i + 1}').join(' | ')} |';
  final separator = '|${List.filled(columns, '----------').join('|')}|';
  final body = List.generate(
    rows - 1 < 1 ? 1 : rows - 1,
    (_) => '| ${List.filled(columns, ' ').join(' | ')} |',
  );
  return [header, separator, ...body].join('\n');
}
