import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/flashcards/flashcard/flashcard_bloc.dart';
import 'package:flashcards/bloc/flashcards/flashcard/flashcard_event.dart';
import 'package:flashcards/bloc/flashcards/flashcard/flashcard_state.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_cubit.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_state.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pp_repository.dart';
import 'package:flashcards/data/repositories/users/auth_repository.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/users/profile_repository.dart';
import 'package:flashcards/data/services/local/local_storage_service.dart';
import 'package:flashcards/data/services/local/session_progress_store.dart';
import 'package:flashcards/data/services/local/daily_target.dart';
import 'package:flashcards/domain/models/flashcards/pack/pack.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flashcards/ui/widgets/core/loading_overlay_listener.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/answer_container/flashcard_answer_with_flashcard_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_main_button/main_button_with_flashcard_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/image_containers/question/question_container_with_flashcard_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/listeners/fc_bloc_status_listener.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/listeners/streak_listener_with_fc_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/listeners/session_milestone_listener.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/listeners/tutorial_seen_listener_with_fc_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/main_card/main_card_with_flashcard_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_page_pop_scope.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/rating_buttons/flashcard_rating_buttons.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/flashcard_top_row/top_row_with_flashcard_bloc.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/timer_container.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/ui/widgets/rewards/study_rewards_widgets.dart';
import 'package:flashcards/ui/widgets/flashcard/picture_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:flashcards/l10n/app_localizations.dart';

@RoutePage()
class FlashcardPage extends StatelessWidget {
  final TestType testType;
  final Pack? pack;

  const FlashcardPage({super.key, required this.testType, this.pack});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FlashcardBloc(
        flashcardRepo: context.read<FlashcardRepository>(),
        fcpRepo: context.read<FcpRepository>(),
        authRepo: context.read<AuthRepository>(),
        profileRepo: context.read<ProfileRepository>(),
        ppRepo: context.read<PpRepository>(),
        localStorageService: context.read<LocalStorageService>(),
        dailyTarget: context.read<DailyTargetService>(),
        sessionProgress: context.read<SessionProgressStore>(),
      ),
      child: _FlashcardView(testType: testType, pack: pack),
    );
  }
}

class _FlashcardView extends StatefulWidget {
  final TestType testType;
  final Pack? pack;

  const _FlashcardView({required this.testType, this.pack});

  @override
  State<_FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<_FlashcardView> {
  void _onStart() {
    final profileState = context.read<ProfileReaderCubit>().state;
    if (profileState case ProfileReaderIsLoaded(:final profile)) {
      context.read<FlashcardBloc>().add(
        FlashcardTestStarted(
          userStreak: profile.streak,
          testType: widget.testType,
          pack: widget.pack,
          cardsPerSession: profile.profileSettings.cardsPerSession,
        ),
      );
    } else {
      throw Exception("You didn't include ProfileLoadedGuard on this route");
    }
  }

  final _subscriptions = <StreamSubscription<Object>>[];
  final _cardScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsFlutterBinding.ensureInitialized();
    final bloc = context.read<FlashcardBloc>();
    _subscriptions
      ..add(
        bloc.saveErrors.listen((error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Couldn't save your progress: ${extractErrorMessage(error)}",
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
    _cardScroll.dispose();
    super.dispose();
  }

  void _showAnswerFromKeyboard() {
    final state = context.read<FlashcardBloc>().state;
    if ((state.status.isLoaded || state.flashcard != null) &&
        !state.answerVisible) {
      context.read<FlashcardBloc>().add(FlashcardAnswerShown());
    }
  }

  void _rateFromKeyboard(fsrs.Rating rating) {
    final state = context.read<FlashcardBloc>().state;
    final profileState = context.read<ProfileReaderCubit>().state;
    if (!state.answerVisible || profileState is! ProfileReaderIsLoaded) return;
    context.read<FlashcardBloc>().add(
      FlashcardRatingGiven(
        rating: rating,
        userStreak: profileState.profile.streak,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = switch (widget.testType) {
      TestType.regular => AppLocalizations.of(context)!.flashcardPage_packTitle,
      TestType.bookmark => AppLocalizations.of(
        context,
      )!.flashcardPage_bookmarksTitle,
    };

    final subTextForDialog = switch (widget.testType) {
      TestType.regular => AppLocalizations.of(
        context,
      )!.flashcardPage_packSubtext,
      TestType.bookmark => AppLocalizations.of(
        context,
      )!.flashcardPage_bookmarksSubtext,
    };

    return FlashcardPagePopScope(
      child: Scaffold(
        appBar: AppBar(
          title: Text(titleText),
          leading: IconButton(
            onPressed: () => context.router.maybePop(),
            icon: Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: ReadableWidth(
            child: StudyRewardsListener(
              child: ReviewShortcuts(
                onShowAnswer: _showAnswerFromKeyboard,
                onRate: _rateFromKeyboard,
                onUndo: () =>
                    context.read<FlashcardBloc>().add(FlashcardUndoPressed()),
                child: LoadingOverlayListener<FlashcardBloc, FlashcardState>(
                  isLoading: (state) => state.status.isLoading,
                  child: SessionMilestoneListener(
                    child: TutorialSeenListenerWithFcBloc(
                      child: StreakListenerWithFcBloc(
                        child: FcBlocStatusListener(
                          testType: widget.testType,
                          child: Padding(
                            padding: flashcardPagePadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pinned: stays at the top while the card
                                // scrolls.
                                TimerContainer<FlashcardBloc, FlashcardState>(
                                  listenWhen: (previous, current) =>
                                      current.status.isLoaded,
                                  shouldStartTimer: (state) =>
                                      state.status.isLoaded,
                                ),
                                SizedBox(height: 4),
                                TopRowWithFlashcardBloc(),
                                Expanded(
                                  child:
                                      BlocSelector<
                                        FlashcardBloc,
                                        FlashcardState,
                                        List<String>
                                      >(
                                        selector: (state) =>
                                            state.flashcard == null
                                            ? const []
                                            : cardPictureUrls(
                                                state.flashcard!,
                                                answerShown:
                                                    state.answerVisible,
                                              ),
                                        builder: (context, pictures) => PictureHint(
                                          pictureUrls: pictures,
                                          controller: _cardScroll,
                                          child: SingleChildScrollView(
                                            controller: _cardScroll,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                QuestionContainerWithFlashcardBloc(),
                                                MainCardWithFlashcardBloc(
                                                  onStart: _onStart,
                                                ),

                                                SizedBox(height: 40),
                                                MainButtonWithFlashcardBloc(),
                                                SizedBox(height: 40),

                                                FlashcardAnswerWithFlashcardBloc(),
                                                SizedBox(height: 15),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                ),

                                SafeArea(
                                  top: false,
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 15),
                                    child: FlashcardRatingButtons(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
