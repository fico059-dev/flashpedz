import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flashcards/data/services/local/daily_target.dart';
import 'package:flashcards/data/services/local/session_progress_store.dart';
import 'package:flashcards/bloc/flashcards/session_test/session_test_bloc.dart';
import 'package:flashcards/bloc/flashcards/session_test/session_test_event.dart';
import 'package:flashcards/bloc/flashcards/session_test/session_test_state.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_cubit.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_state.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/data/repositories/flashcards/custom_session_repository.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/data/repositories/users/profile_repository.dart';
import 'package:flashcards/domain/enums/score_status.dart';
import 'package:flashcards/domain/models/flashcards/custom_session_summary/custom_session_summary.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/core/error_screen.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flashcards/ui/widgets/core/loading_overlay_listener.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/answer_container/answer_with_session_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_main_button/main_button_with_session_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_top_row/top_row_with_session_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/image_containers/question/question_container_with_session_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/main_card/main_card_with_session_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/next_button/next_button_with_session_bloc.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/ui/widgets/rewards/study_rewards_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs/fsrs.dart' as fsrs;

@RoutePage()
class CustomSessionTestPage extends StatelessWidget {
  final CustomSessionSummary sessionSummary;

  const CustomSessionTestPage({super.key, required this.sessionSummary});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SessionTestBloc(
        profileRepo: context.read<ProfileRepository>(),
        sessionRepo: context.read<CustomSessionRepository>(),
        fcpRepo: context.read<FcpRepository>(),
        sessionProgress: context.read<SessionProgressStore>(),
        dailyTarget: context.read<DailyTargetService>(),
      ),
      child: _View(sessionSummary: sessionSummary),
    );
  }
}

class _View extends StatefulWidget {
  final CustomSessionSummary sessionSummary;

  const _View({super.key, required this.sessionSummary});

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  void _onStart() {
    final profileState = context.read<ProfileReaderCubit>().state;
    if (profileState case ProfileReaderIsLoaded(:final profile)) {
      context.read<SessionTestBloc>().add(
        SessionTestDataLoaded(
          sessionSummary: widget.sessionSummary,
          userStreak: profile.streak,
        ),
      );
    } else {
      throw Exception("You didn't include ProfileLoadedGuard on this route");
    }
  }

  final _subscriptions = <StreamSubscription<Object>>[];

  @override
  void initState() {
    super.initState();
    final bloc = context.read<SessionTestBloc>();
    _subscriptions
      ..add(
        bloc.saveErrors.listen((error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Couldn't save your progress for a card: "
                "${extractErrorMessage(error)}",
              ),
            ),
          );
        }),
      )
      ..add(
        // Load the pictures of the next cards while this one is studied.
        bloc.upcomingImages.listen((url) {
          if (!mounted) return;
          precacheImage(NetworkImage(url), context, onError: (_, _) {});
        }),
      );
    _onStart();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _showAnswerFromKeyboard() {
    final state = context.read<SessionTestBloc>().state;
    if (state is! SessionTestLoaded ||
        state.status.isNoFlashcard ||
        state.answerShown) {
      return;
    }
    context.read<SessionTestBloc>().add(SessionTestAnswerShown());
  }

  void _rateFromKeyboard(fsrs.Rating rating) {
    final state = context.read<SessionTestBloc>().state;
    final profileState = context.read<ProfileReaderCubit>().state;
    if (state is! SessionTestLoaded ||
        !state.answerShown ||
        profileState is! ProfileReaderIsLoaded) {
      return;
    }
    context.read<SessionTestBloc>().add(
      SessionTestNextPressed(
        rating: rating,
        userStreak: profileState.profile.streak,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Custom session test"),
        leading: IconButton(
          onPressed: () => context.router.pop(),
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: ReadableWidth(
          child: StudyRewardsListener(
            child: ReviewShortcuts(
              onShowAnswer: _showAnswerFromKeyboard,
              onRate: _rateFromKeyboard,
              child: Padding(
                padding: flashcardPagePadding,
                child:
                    LoadingOverlayListener<SessionTestBloc, SessionTestState>(
                      isLoading: (state) =>
                          state is SessionTestLoaded && state.status.isLoading,
                      child: BlocListener<SessionTestBloc, SessionTestState>(
                        listenWhen: (previous, current) {
                          final isLoadedNow = current is SessionTestLoaded;
                          if (!isLoadedNow) return false;

                          final hasNewStreak = current.newStreak != null;

                          // is prev was now loaded, run listener
                          if (previous is! SessionTestLoaded) {
                            return hasNewStreak;
                          }

                          // if it was loaded, then compare to the current
                          return hasNewStreak &&
                              current.newStreak != previous.newStreak;
                        },
                        listener: (context, state) {
                          if (state is! SessionTestLoaded) return;
                          final newStreak = state.newStreak;
                          if (newStreak == null) return;
                          print(
                            "Ha, new streak found, updating profile bloc now",
                          );
                          context.read<ProfileReaderCubit>().updateProfileState(
                            (profile) => profile.copyWith(streak: newStreak),
                          );

                          final profileState = context
                              .read<ProfileReaderCubit>()
                              .state;
                          final streakProfile =
                              (profileState as ProfileReaderIsLoaded)
                                  .profile
                                  .streak;
                          print("New streak from bloc state: $streakProfile");
                        },
                        child: BlocListener<SessionTestBloc, SessionTestState>(
                          listenWhen: (previous, current) {
                            final isLoaded = current is SessionTestLoaded;
                            return isLoaded &&
                                (current.status.isError ||
                                    current.status.isFinished);
                          },
                          listener: (context, state) {
                            if (state is! SessionTestLoaded) return;
                            if (state.status.isError) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    extractErrorMessage(state.error!),
                                  ),
                                ),
                              );
                            } else if (state.status.isFinished) {
                              final correctCount = state.session.correctCount;
                              final allCount = state.session.cardCount;

                              context.router.pop();
                              context.router.push(
                                CustomSessionResultRoute(
                                  scoreStatus: calculateScoreStatus(
                                    correctCount,
                                    allCount,
                                  ),
                                  correctCount: correctCount,
                                  allCount: allCount,
                                ),
                              );
                            }
                          },
                          child: BlocBuilder<SessionTestBloc, SessionTestState>(
                            buildWhen: (previous, current) =>
                                previous.runtimeType != current.runtimeType,
                            builder: (context, state) {
                              switch (state) {
                                case SessionTestInitial():
                                case SessionTestLoading():
                                  return Center(
                                    child: CircularProgressIndicator(
                                      color: context.colors.primary,
                                    ),
                                  );
                                case SessionTestLoaded():
                                  return _LoadedContent(state: state);
                                case SessionTestError(:final error):
                                  return ErrorScreen(
                                    errorMessage: extractErrorMessage(error),
                                    onReload: _onStart,
                                  );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadedContent extends StatelessWidget {
  final SessionTestLoaded state;

  const _LoadedContent({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pinned: stays at the top while the card scrolls.
        TopRowWithSessionBloc(),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QuestionContainerWithSessionBloc(),
                MainCardWithSessionBloc(),

                SizedBox(height: 40),
                MainButtonWithSessionBloc(),
                SizedBox(height: 40),

                AnswerWithSessionBloc(),
                SizedBox(height: 15),
              ],
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: EdgeInsets.only(top: 15),
            child: NextButtonWithSessionBloc(),
          ),
        ),
      ],
    );
  }
}

Future<void> _showSessionFinishedDialog({
  required BuildContext context,
  required int correctCount,
  required int allCount,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // Prevent closing by tapping outside
    builder: (context) {
      return AlertDialog(
        title: const Text('Session Complete 🎉'),
        content: Text(
          'Congratulations! You have successfully finished this custom session.'
          '\n\nWell done for staying focused and making progress.'
          ' Keep up the great work!'
          '\n\nYour score is $correctCount/$allCount',
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.router.pop();
              context.router.replaceAll([HomeRoute()]);
            },
            child: const Text('Back to Home'),
          ),
        ],
      );
    },
  );
}
