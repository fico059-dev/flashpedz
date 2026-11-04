import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:equatable/equatable.dart';
import 'package:flashcards/domain/models/flashcards/pack/pack.dart';
import 'package:flashcards/domain/models/profile/streak/streak.dart';
import 'package:fsrs/fsrs.dart';

enum TestType { regular, bookmark }

extension TestTypeX on TestType {
  bool get isRegular => this == TestType.regular;
  bool get isBookmark => this == TestType.bookmark;
}

sealed class FlashcardEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class FlashcardTestStarted extends FlashcardEvent {
  final TestType testType;
  final Pack? pack;
  final int cardsPerSession;
  final Streak userStreak;

  FlashcardTestStarted({
    required this.testType,
    required this.cardsPerSession,
    required this.userStreak,
    this.pack,
  }) : assert(
         testType == TestType.bookmark || pack != null,
         'Pack must not be null for regular test type',
       );

  @override
  List<Object?> get props => [testType, pack, cardsPerSession, userStreak];
}

class FlashcardSessionExtended extends FlashcardEvent {}

class FlashcardAnswerShown extends FlashcardEvent {}

class FlashcardHintToggled extends FlashcardEvent {}

class FlashcardRatingGiven extends FlashcardEvent {
  final Rating rating;
  final Streak userStreak;

  FlashcardRatingGiven({required this.rating, required this.userStreak});

  @override
  List<Object?> get props => [rating, userStreak];
}

class FlashcardBookmarkToggled extends FlashcardEvent {}

/// Takes back the last rating and shows that card again.
class FlashcardUndoPressed extends FlashcardEvent {}

class FlashcardIgnored extends FlashcardEvent {}

class FlashcardCardsPerSessionUpdated extends FlashcardEvent {
  final int cardPerSession;

  FlashcardCardsPerSessionUpdated({required this.cardPerSession});

  @override
  List<Object?> get props => [cardPerSession];
}

class FlashcardTutorialSeenChecked extends FlashcardEvent {}

class FlashcardTutorialFinished extends FlashcardEvent {}

/// The student set this pack's session target (null: back to the
/// default). The session starts again with the new target.
class FlashcardSessionTargetChanged extends FlashcardEvent {
  final int? target;

  FlashcardSessionTargetChanged(this.target);

  @override
  List<Object?> get props => [target];
}

/// An admin edited the current card while studying.
class FlashcardEdited extends FlashcardEvent {
  final Flashcard flashcard;

  FlashcardEdited(this.flashcard);

  @override
  List<Object?> get props => [flashcard];
}
