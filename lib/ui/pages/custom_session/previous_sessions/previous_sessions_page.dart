import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/custom_session/custom_session_getter/custom_session_getter_bloc.dart';
import 'package:flashcards/bloc/custom_session/custom_session_getter/custom_session_getter_event.dart';
import 'package:flashcards/bloc/custom_session/custom_session_getter/custom_session_getter_state.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/domain/models/flashcards/custom_session_summary/custom_session_summary.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/dialogs/previous_session/prev_sessions_options_bottom_sheet.dart';
import 'package:flashcards/ui/widgets/core/card_factory.dart';
import 'package:flashcards/ui/widgets/core/error_screen.dart';
import 'package:flashcards/ui/widgets/core/loading_overlay_listener.dart';
import 'package:flashcards/ui/widgets/previous_sessions/previous_session_card.dart';
import 'package:flashcards/data/repositories/flashcards/custom_session_repository.dart';
import 'package:flashcards/ui/pages/card_browser/card_browser_page.dart';
import 'package:flashcards/ui/widgets/card_sets/my_sets_section.dart';
import 'package:flashcards/data/repositories/card_sets/card_set_repository.dart';
import 'package:flashcards/ui/dialogs/card_sets/card_set_dialogs.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flashcards/ui/dialogs/previous_session/rename_session_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

@RoutePage()
class PreviousSessionsPage extends StatelessWidget {
  const PreviousSessionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _View();
  }
}

class _View extends StatefulWidget {
  const _View({super.key});

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  Future<void> handleRefresh(BuildContext context) {
    final completer = Completer<void>();
    context.read<CustomSessionGetterBloc>().add(
      CustomSessionGetterRefresh(completer: completer),
    );

    return completer.future.catchError((error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(extractErrorMessage(error))));
    });
  }

  void onSessionDelete(String sessionId) {
    context.read<CustomSessionGetterBloc>().add(
      CustomSessionGetterDelete(sessionId: sessionId),
    );
  }

  void onSessionReset(String sessionId) {
    context.read<CustomSessionGetterBloc>().add(
      CustomSessionGetterReset(sessionId: sessionId),
    );
  }

  void onSessionRename(CustomSessionSummary session) async {
    final bloc = context.read<CustomSessionGetterBloc>();
    final name = await showRenameSessionDialog(
      context,
      currentName: session.name ?? '',
    );
    if (name == null) return;
    bloc.add(CustomSessionGetterRename(sessionId: session.id, name: name));
  }

  void onSessionStart(CustomSessionSummary session) async {
    if (session.isPaid) {
      final ok = await ensureCardsAccess(context);
      if (!ok) return;
    }

    context.router.push(CustomSessionTestRoute(sessionSummary: session));
  }

  void onSessionBrowse(CustomSessionSummary session) {
    final repo = context.read<CustomSessionRepository>();
    openCardBrowser(
      context,
      title: session.displayName,
      loadIds: () async {
        final result = await repo.getCustomSessionFlashcardIds(
          sessionSummary: session,
        );
        return switch (result) {
          Ok(:final value) => value.flashcardIds,
          Error(:final error) => throw error,
        };
      },
      onStudy: session.isFinished
          ? null
          : (context) async => onSessionStart(session),
    );
  }

  /// Keeps the session's cards as one of My Sets.
  Future<void> onSessionSaveAsSet(CustomSessionSummary session) async {
    final sets = context.read<CardSetRepository>();
    final sessions = context.read<CustomSessionRepository>();
    final messenger = ScaffoldMessenger.of(context);
    await sets.load();
    if (!mounted) return;
    if (sets.isLoaded && !sets.canAddSet) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'You have $maxCardSets sets, the most. Delete one first.',
          ),
        ),
      );
      return;
    }
    final name = await showSetNameDialog(
      context,
      current: session.displayName,
      title: 'Save as set',
    );
    if (name == null) return;
    try {
      final result = await sessions.getCustomSessionFlashcardIds(
        sessionSummary: session,
      );
      final ids = switch (result) {
        Ok(:final value) => value.flashcardIds,
        Error(:final error) => throw error,
      };
      await sets.create(name, flashcardIds: ids);
      messenger.showSnackBar(
        SnackBar(content: Text('Saved "$name" with ${ids.length} cards')),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(extractErrorMessage(error))),
      );
    }
  }

  void onSessionTap(CustomSessionSummary session) {
    showPrevSessionsOptionsBottomSheet(
      context: context,
      session: session,
      onSessionDelete: () => onSessionDelete(session.id),
      onSessionReset: () => onSessionReset(session.id),
      onSessionRename: () => onSessionRename(session),
      onSessionStart: !session.isFinished
          ? () => onSessionStart(session)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlayListener<
      CustomSessionGetterBloc,
      CustomSessionGetterState
    >(
      isLoading: (state) => state.status.isActionLoading,
      child: BlocListener<CustomSessionGetterBloc, CustomSessionGetterState>(
        listenWhen: (previous, current) =>
            current.status.isResetSuccessful ||
            current.status.isDeleteSuccessful ||
            current.status == CustomSessionGetterStatus.renameSuccessful ||
            current.status.isActionError,
        listener: (context, state) {
          switch (state.status) {
            case CustomSessionGetterStatus.deleteSuccessful:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Successfully deleted session")),
              );
              break;
            case CustomSessionGetterStatus.renameSuccessful:
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Session renamed")));
              break;
            case CustomSessionGetterStatus.resetSuccessful:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Successfully reset session progress")),
              );
              break;
            case CustomSessionGetterStatus.actionError:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(extractErrorMessage(state.error!))),
              );
              break;
            default:
          }
        },
        child: Scaffold(
          body: Container(
            margin: EdgeInsets.only(top: 20),
            padding: EdgeInsets.symmetric(horizontal: horizontalScreenPadding),
            child:
                BlocBuilder<CustomSessionGetterBloc, CustomSessionGetterState>(
                  builder: (context, state) {
                    return RefreshIndicator(
                      onRefresh: () => handleRefresh(context),
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: MySetsSection()),

                          PagedSliverList(
                            state: state.pagingState,
                            fetchNextPage: context
                                .read<CustomSessionGetterBloc>()
                                .fetchNextPage,
                            builderDelegate: PagedChildBuilderDelegate(
                              firstPageErrorIndicatorBuilder: (context) =>
                                  ErrorScreen(
                                    errorMessage: extractErrorMessage(
                                      state.pagingState.error!,
                                    ),
                                    onReload: context
                                        .read<CustomSessionGetterBloc>()
                                        .fetchNextPage,
                                  ),
                              noItemsFoundIndicatorBuilder: (context) =>
                                  _EmptyListContainer(),
                              firstPageProgressIndicatorBuilder: (context) =>
                                  PreviousSessionsShimmer(),
                              itemBuilder: (context, item, index) {
                                final session = item as CustomSessionSummary;

                                return PreviousSessionCard(
                                  hasCards: state.hasCards,
                                  session: session,
                                  onDeletePressed: () =>
                                      onSessionDelete(session.id),
                                  onStartPressed: !session.isFinished
                                      ? () => onSessionStart(session)
                                      : null,
                                  onResetPressed: () =>
                                      onSessionReset(session.id),
                                  onRenamePressed: () =>
                                      onSessionRename(session),
                                  onBrowsePressed: () =>
                                      onSessionBrowse(session),
                                  onSaveAsSetPressed: () =>
                                      onSessionSaveAsSet(session),
                                  onTap: () => onSessionTap(session),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ),
      ),
    );
  }
}

class _EmptyListContainer extends StatelessWidget {
  const _EmptyListContainer({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        spacing: 15,
        children: [
          Text("Looks like you didn't create any custom sessions yet."),

          FilledButton(
            onPressed: () =>
                context.replaceRoute(const CustomSessionWrapperRoute()),
            child: Text("Create new custom session"),
          ),
        ],
      ),
    );
  }
}
