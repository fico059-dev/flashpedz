enum HighlightSide { question, answer }

/// A yellow highlight (also listed in the notebook) or an underline, which
/// only marks the card.
enum HighlightKind { highlight, underline }

/// A passage of a flashcard the student highlighted.
class Highlight {
  final String id;
  final String flashcardId;
  final String packId;
  final HighlightSide side;
  final String text;

  /// Where [text] started in the displayed text when it was highlighted.
  final int start;

  /// The card's question, to show where the highlight comes from.
  final String question;
  final DateTime createdAt;
  final HighlightKind kind;

  const Highlight({
    required this.id,
    required this.flashcardId,
    required this.packId,
    required this.side,
    required this.text,
    required this.start,
    required this.question,
    required this.createdAt,
    this.kind = HighlightKind.highlight,
  });

  bool get isUnderline => kind == HighlightKind.underline;

  Highlight copyWith({String? id}) => Highlight(
    id: id ?? this.id,
    flashcardId: flashcardId,
    packId: packId,
    side: side,
    text: text,
    start: start,
    question: question,
    createdAt: createdAt,
    kind: kind,
  );

  Map<String, dynamic> toJson() => {
    'flashcardId': flashcardId,
    'packId': packId,
    'side': side.name,
    'text': text,
    'start': start,
    'question': question,
    'kind': kind.name,
  };

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
    id: json['id'] as String,
    flashcardId: json['flashcardId'] as String? ?? '',
    packId: json['packId'] as String? ?? '',
    side: json['side'] == 'answer'
        ? HighlightSide.answer
        : HighlightSide.question,
    text: json['text'] as String? ?? '',
    start: (json['start'] as num?)?.toInt() ?? 0,
    question: json['question'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num?)?.toInt() ?? 0,
    ),
    kind: json['kind'] == 'underline'
        ? HighlightKind.underline
        : HighlightKind.highlight,
  );
}

/// Ranges of [text] covered by [highlights]. A highlight is found at its
/// saved position, or else where its text appears closest to it (the card
/// text can change slightly, e.g. when a cloze is revealed).
List<(int start, int end, Highlight highlight)> highlightRanges(
  String text,
  Iterable<Highlight> highlights,
) {
  final ranges = <(int, int, Highlight)>[];
  for (final highlight in highlights) {
    final needle = highlight.text;
    if (needle.isEmpty) continue;
    int? best;
    if (highlight.start + needle.length <= text.length &&
        text.startsWith(needle, highlight.start)) {
      best = highlight.start;
    } else {
      var index = text.indexOf(needle);
      while (index != -1) {
        if (best == null ||
            (index - highlight.start).abs() < (best - highlight.start).abs()) {
          best = index;
        }
        index = text.indexOf(needle, index + 1);
      }
    }
    if (best != null) ranges.add((best, best + needle.length, highlight));
  }
  ranges.sort((a, b) => a.$1.compareTo(b.$1));

  // Overlapping highlights (or underlines) are merged into one stretch.
  final merged = <(int, int, Highlight)>[];
  for (final kind in HighlightKind.values) {
    final ofKind = <(int, int, Highlight)>[];
    for (final range in ranges.where((r) => r.$3.kind == kind)) {
      if (ofKind.isNotEmpty && range.$1 <= ofKind.last.$2) {
        final last = ofKind.removeLast();
        ofKind.add((last.$1, range.$2 > last.$2 ? range.$2 : last.$2, last.$3));
      } else {
        ofKind.add(range);
      }
    }
    merged.addAll(ofKind);
  }
  merged.sort((a, b) => a.$1.compareTo(b.$1));
  return merged;
}
