import 'package:flutter/foundation.dart';

/// Which of the studied cards an exam takes.
enum StudiedCardsFilter { all, forgotten, hard, due }

extension StudiedCardsFilterX on StudiedCardsFilter {
  String get label => switch (this) {
    StudiedCardsFilter.all => 'All studied',
    StudiedCardsFilter.forgotten => 'Answered Again before',
    StudiedCardsFilter.hard => 'Hard for me',
    StudiedCardsFilter.due => 'Due now',
  };

  String get description => switch (this) {
    StudiedCardsFilter.all => 'Every card you have studied.',
    StudiedCardsFilter.forgotten =>
      'Cards you got wrong (answered Again) at least once.',
    StudiedCardsFilter.hard =>
      'Cards the scheduler rates as difficult for you, from your answers.',
    StudiedCardsFilter.due => 'Cards whose review is due today or overdue.',
  };

  /// Sent to the server; null for all studied cards.
  String? get requestValue => this == StudiedCardsFilter.all ? null : name;
}

/// The choice made on the filter step, read when the exam is created.
class StudiedFilterNotifier extends ValueNotifier<StudiedCardsFilter> {
  StudiedFilterNotifier() : super(StudiedCardsFilter.all);
}
