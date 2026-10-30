// Reads the notes made with Anki's built-in Image Occlusion (Anki 23.10 and
// newer). Their first field holds the boxes as clozes, e.g.
// `{{c1::image-occlusion:rect:left=.2:top=.3:width=.1:height=.05:oi=1}}`,
// and another field the picture.

import 'dart:math';
import 'dart:typed_data';

import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:image/image.dart' as img;

/// Stands in for the address of an occlusion card's picture until it is
/// uploaded during the import.
const ankiOcclusionImageUrl = 'https://anki-image.invalid/occlusion';

final _shapeRegex = RegExp(
  r'\{\{c(\d+)::image-occlusion:(\w+)((?:\\.|[^}])*)\}\}',
);

/// Whether an Anki field holds image-occlusion boxes.
bool isImageOcclusionField(String field) => field.contains('image-occlusion:');

/// One shape drawn in Anki, as the box around it.
class AnkiOcclusionShape {
  /// The cloze number: shapes with the same number are asked together.
  final int ordinal;
  final double left, top, width, height;

  /// "Hide all, guess one": the other boxes stay covered on the card.
  final bool hideAll;

  const AnkiOcclusionShape({
    required this.ordinal,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.hideAll,
  });

  /// Older Anki versions stored pixels instead of fractions of the picture.
  bool get isInPixels => [left, top, width, height].any((v) => v > 1.5);

  OcclusionMask toMask({Point<int>? imageSize}) {
    var (x, y, w, h) = (left, top, width, height);
    if (isInPixels && imageSize != null) {
      x /= imageSize.x;
      w /= imageSize.x;
      y /= imageSize.y;
      h /= imageSize.y;
    }
    x = x.clamp(0, 1);
    y = y.clamp(0, 1);
    return OcclusionMask(x, y, w.clamp(0, 1 - x), h.clamp(0, 1 - y));
  }
}

/// The shapes in an Anki image-occlusion field. Text labels (cloze number 0)
/// aren't boxes and are left out; ellipses and polygons become the box
/// around them.
List<AnkiOcclusionShape> parseAnkiOcclusionShapes(String field) {
  final shapes = <AnkiOcclusionShape>[];
  for (final match in _shapeRegex.allMatches(field)) {
    final ordinal = int.parse(match.group(1)!);
    if (ordinal == 0) continue;
    final props = _properties(match.group(3)!);
    double number(String name) => double.tryParse(props[name] ?? '') ?? 0;
    final hideAll = props['oi'] == '1';

    double left = number('left'), top = number('top');
    double width, height;
    switch (match.group(2)) {
      case 'rect':
        width = number('width');
        height = number('height');
      case 'ellipse':
        width = props.containsKey('rx') ? number('rx') * 2 : number('width');
        height = props.containsKey('ry') ? number('ry') * 2 : number('height');
      case 'polygon':
        final points = [
          for (final pair in (props['points'] ?? '').split(' '))
            if (pair.split(',') case [final px, final py])
              if ((double.tryParse(px), double.tryParse(py)) case (
                final double x,
                final double y,
              ))
                Point(x, y),
        ];
        if (points.isEmpty) continue;
        left = points.map((p) => p.x).reduce(min);
        top = points.map((p) => p.y).reduce(min);
        width = points.map((p) => p.x).reduce(max) - left;
        height = points.map((p) => p.y).reduce(max) - top;
      default:
        continue;
    }
    if (width <= 0 || height <= 0) continue;
    shapes.add(
      AnkiOcclusionShape(
        ordinal: ordinal,
        left: left,
        top: top,
        width: width,
        height: height,
        hideAll: hideAll,
      ),
    );
  }
  return shapes;
}

/// `:name=value` pairs, where `\:` and `\\` stand for `:` and `\`.
Map<String, String> _properties(String text) {
  final props = <String, String>{};
  final parts = <String>[];
  final current = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == r'\' && i + 1 < text.length) {
      current.write(text[++i]);
    } else if (char == ':') {
      parts.add(current.toString());
      current.clear();
    } else {
      current.write(char);
    }
  }
  parts.add(current.toString());
  for (final part in parts) {
    final at = part.indexOf('=');
    if (at > 0) props[part.substring(0, at)] = part.substring(at + 1);
  }
  return props;
}

/// The question and answer occlusion lines of every card of a note: one card
/// per cloze number, like in Anki. With "hide one, guess one" a card shows
/// only the boxes it asks about.
List<({int ordinal, String question, String answer})> ankiOcclusionCards(
  List<AnkiOcclusionShape> shapes, {
  Point<int>? imageSize,
  String url = ankiOcclusionImageUrl,
}) {
  final ordinals = shapes.map((s) => s.ordinal).toSet().toList()..sort();
  final hideAll = shapes.any((s) => s.hideAll);
  return [
    for (final ordinal in ordinals)
      () {
        final shown = hideAll
            ? shapes
            : shapes.where((s) => s.ordinal == ordinal).toList();
        final masks = [for (final s in shown) s.toMask(imageSize: imageSize)];
        final asked = [
          for (var i = 0; i < shown.length; i++)
            if (shown[i].ordinal == ordinal) i,
        ];
        String line({required bool revealed}) => occlusionLine(
          url: url,
          masks: masks,
          target: asked.first,
          alsoAsked: asked.skip(1).toList(),
          revealed: revealed,
        );
        return (
          ordinal: ordinal,
          question: line(revealed: false),
          answer: line(revealed: true),
        );
      }(),
  ];
}

/// Width and height of a picture, read from its header.
Point<int>? imageSizeOf(Uint8List bytes) {
  try {
    final info = img.findDecoderForData(bytes)?.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return Point(info.width, info.height);
  } on Object {
    return null;
  }
}
