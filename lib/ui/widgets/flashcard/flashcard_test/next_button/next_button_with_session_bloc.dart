import 'package:flashcards/bloc/flashcards/session_test/session_test_bloc.dart';
import 'package:flashcards/bloc/flashcards/session_test/session_test_event.dart';
import 'package:flashcards/bloc/flashcards/session_test/session_test_state.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_cubit.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/rating_buttons/rating_segments.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/rating_buttons/score_segmented_button.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

class NextButtonWithSessionBloc extends StatelessWidget {
  const NextButtonWithSessionBloc({super.key});

  @override
  Widget build(BuildContext context) {
    void onPressed(fsrs.Rating? rating) {
      final profileState = context.read<ProfileReaderCubit>().state;
      if (profileState is! ProfileReaderIsLoaded) {
        throw Exception("Profile is not loaded when pressing bloc button");
      }

      context.read<SessionTestBloc>().add(
        SessionTestNextPressed(
          rating: rating,
          userStreak: profileState.profile.streak,
        ),
      );
    }

    return BlocSelector<SessionTestBloc, SessionTestState, (bool, fsrs.Card)?>(
      selector: (state) {
        if (state is! SessionTestLoaded) {
          throw Exception("State is not loaded state");
        }

        if (state.status.isNoFlashcard) return null;

        return (state.answerShown, state.statRecord.card);
      },
      builder: (context, selected) {
        if (selected == null) {
          return Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: () => onPressed(null),
                    child: Text(
                      "Skip this question",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final (answerShown, card) = selected;
        if (!answerShown) {
          return SizedBox.shrink();
        }

        return _SessionRatingButtons(card: card, onRated: onPressed);
      },
    );
  }
}

class _SessionRatingButtons extends StatefulWidget {
  final fsrs.Card card;
  final ValueChanged<fsrs.Rating> onRated;

  const _SessionRatingButtons({required this.card, required this.onRated});

  @override
  State<_SessionRatingButtons> createState() => _SessionRatingButtonsState();
}

class _SessionRatingButtonsState extends State<_SessionRatingButtons> {
  fsrs.Rating? _selected;

  @override
  void didUpdateWidget(covariant _SessionRatingButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new card is shown: allow rating again.
    if (!identical(oldWidget.card, widget.card)) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SessionTestBloc, SessionTestState>(
      // If the rating didn't go through (saving failed, or it was ignored),
      // let the user rate again once the app isn't busy.
      listenWhen: (previous, current) =>
          current is SessionTestLoaded &&
          (current.status.isError ||
              (previous is SessionTestLoaded &&
                  previous.status != current.status &&
                  !current.status.isLoading)),
      listener: (context, state) => setState(() => _selected = null),
      child: ScoreSegmentedButton<fsrs.Rating>(
        segments: buildRatingSegments(context, widget.card),
        selectedValue: _selected,
        onChanged: (rating) {
          setState(() => _selected = rating);
          widget.onRated(rating);
        },
      ),
    );
  }
}
