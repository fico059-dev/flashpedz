import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fsrs/fsrs.dart';

part 'stat_record.freezed.dart';

@freezed
abstract class StatRecord with _$StatRecord {
  /// Used for flashcard anc custom session test screen,
  /// flashcard is nullable because sometimes we won't
  /// have that info, that will force the bloc to pull the flashcard from db and
  /// fill in this field.
  /// On session test page it's safe to use ! on flashcard screen since I don't
  /// ask for flashcard in bloc but rather in repo layer, stuped.
  const factory StatRecord({
    required String packId,
    required String flashcardId,
    required bool isPaid,
    Flashcard? flashcard,
    @Default(false) bool hasBookmark,
    required Card card,
    @Default(false) bool isPulledFromDb,
  }) = _StatRecord;

  factory StatRecord.empty() => StatRecord(
    packId: '-1',
    flashcardId: '-1',
    flashcard: Flashcard(
      id: '-1',
      packId: '-1',
      question:
          "Ooops, looks like someone deleted this flashcard but it's still"
          " in this exam, you can skip it or create a new exam.",
      answer: '',
      tags: [],
    ),
    isPaid: false,
    card: Card(),
  );
}
