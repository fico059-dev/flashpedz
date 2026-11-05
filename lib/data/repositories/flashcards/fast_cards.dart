import 'package:flashcards/data/repositories/algolia_search/flashcards_searcher_repository.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// The cards with these ids, in the same order. Cards in the search list
/// (already on the device) come from there straight away; only the others
/// (e.g. the student's own cards) are read from the server.
Future<List<Flashcard>> loadCardsFast(
  BuildContext context,
  List<String> ids,
) async {
  final search = context.read<FlashcardsSearcherRepository?>();
  final repo = context.read<FlashcardRepository>();
  final found = <String, Flashcard>{};
  if (search != null) {
    try {
      for (final card in await search.cardsByIds(ids)) {
        found[card.id] = card;
      }
    } catch (_) {
      // Read from the server instead.
    }
  }
  final missing = [
    for (final id in ids)
      if (!found.containsKey(id)) id,
  ];
  if (missing.isNotEmpty) {
    for (final card in await repo.getFlashcardsByIds(missing)) {
      found[card.id] = card;
    }
  }
  return [
    for (final id in ids)
      if (found[id] case final card?) card,
  ];
}
