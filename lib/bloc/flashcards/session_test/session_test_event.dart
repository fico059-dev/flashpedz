import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:equatable/equatable.dart';
import 'package:fsrs/fsrs.dart';
import 'package:flashcards/domain/models/flashcards/custom_session_summary/custom_session_summary.dart';
import 'package:flashcards/domain/models/profile/streak/streak.dart';
import 'package:flashcards/domain/models/profile/streak/streak.dart';

abstract class SessionTestEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SessionTestDataLoaded extends SessionTestEvent {
  final CustomSessionSummary sessionSummary;
  final Streak userStreak;

  SessionTestDataLoaded({
    required this.sessionSummary,
    required this.userStreak,
  });

  @override
  List<Object?> get props => [sessionSummary, userStreak];
}

class SessionTestNextPressed extends SessionTestEvent {
  /// How well the card was remembered. It updates the card's progress
  /// (spaced repetition), like in regular study. Null when the card is
  /// skipped. Every rating except "again" counts as correct.
  final Rating? rating;
  final Streak userStreak;

  SessionTestNextPressed({required this.rating, required this.userStreak});

  bool get isCorrect => rating != Rating.again;

  @override
  List<Object?> get props => [rating, userStreak];
}

class SessionTestBookmarkToggled extends SessionTestEvent {}

/// Takes back the last answer and shows that card again.
class SessionTestUndoPressed extends SessionTestEvent {}

class SessionTestAnswerShown extends SessionTestEvent {}

/// The study streak changed after a background save.
class SessionTestStreakChanged extends SessionTestEvent {
  final Streak streak;

  SessionTestStreakChanged(this.streak);

  @override
  List<Object?> get props => [streak];
}

/// An admin edited the current card while studying.
class SessionTestCardEdited extends SessionTestEvent {
  final Flashcard flashcard;

  SessionTestCardEdited(this.flashcard);

  @override
  List<Object?> get props => [flashcard];
}
