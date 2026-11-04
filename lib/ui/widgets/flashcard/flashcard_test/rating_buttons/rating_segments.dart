import 'package:flashcards/l10n/app_localizations.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/rating_buttons/score_segmented_button.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flutter/widgets.dart';

import 'package:fsrs/fsrs.dart' as fsrs;

/// Again is red, the ratings of a remembered card green.
const againColor = Color(0xFFD32F2F);
const rememberedColor = Color(0xFF2E7D32);

/// The Easy / Good / Hard / Again buttons for [card], each showing when the
/// card will be due again if that rating is chosen (e.g. "10m", "3d").
List<ScoreSegment<fsrs.Rating>> buildRatingSegments(
  BuildContext context,
  fsrs.Card card,
) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();
  // Same scheduling as when the rating is saved.
  final scheduled = fsrs.FSRS().repeat(card, now);
  String interval(fsrs.Rating rating) =>
      formatInterval(scheduled[rating]!.card.due, now);

  return [
    ScoreSegment(
      value: fsrs.Rating.easy,
      label: l10n.flashcardRatingButtons_easyLabel,
      tooltip: l10n.flashcardRatingButtons_easyTooltip,
      time: interval(fsrs.Rating.easy),
      color: rememberedColor,
    ),
    ScoreSegment(
      value: fsrs.Rating.good,
      label: l10n.flashcardRatingButtons_goodLabel,
      tooltip: l10n.flashcardRatingButtons_goodTooltip,
      time: interval(fsrs.Rating.good),
      color: rememberedColor,
    ),
    ScoreSegment(
      value: fsrs.Rating.hard,
      label: l10n.flashcardRatingButtons_hardLabel,
      tooltip: l10n.flashcardRatingButtons_hardTooltip,
      time: interval(fsrs.Rating.hard),
      color: rememberedColor,
    ),
    ScoreSegment(
      value: fsrs.Rating.again,
      label: l10n.flashcardRatingButtons_againLabel,
      tooltip: l10n.flashcardRatingButtons_againTooltip,
      time: interval(fsrs.Rating.again),
      color: againColor,
    ),
  ];
}
