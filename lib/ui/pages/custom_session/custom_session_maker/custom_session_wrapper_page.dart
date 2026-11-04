import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/custom_session/pack_filter/pack_filter_bloc.dart';
import 'package:flashcards/bloc/custom_session/pack_picker/pack_picker_bloc.dart';
import 'package:flashcards/bloc/custom_session/session_limit/session_limit_cubit.dart';
import 'package:flashcards/bloc/custom_session/session_tag_picker/session_tag_picker_cubit.dart';
import 'package:flashcards/data/repositories/flashcards/custom_session_repository.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pack_repository.dart';
import 'package:flashcards/ui/widgets/custom_session/custom_session_bottom_navigation_bar.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flutter/material.dart';
import 'package:flashcards/bloc/custom_session/studied_filter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

@RoutePage()
class CustomSessionWrapperPage extends StatelessWidget
    implements AutoRouteWrapper {
  const CustomSessionWrapperPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentName = context.topRoute.name;

    final stepIndex = getStepIndex(currentName);
    final title = getTitle(stepIndex);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ReadableWidth(maxWidth: 820, child: AutoRouter()),
      bottomNavigationBar: CustomSessionBottomNavigationBar(
        stepIndex: stepIndex,
      ),
    );
  }

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              PackPickerBloc(packRepo: context.read<PackRepository>()),
        ),
        BlocProvider(
          create: (context) =>
              PackFilterBloc(fcpRepo: context.read<FcpRepository>()),
        ),
        BlocProvider(create: (context) => SessionTagPickerCubit()),
        ChangeNotifierProvider(create: (context) => StudiedFilterNotifier()),
        BlocProvider(
          create: (context) => SessionLimitCubit(
            customSessionRepo: context.read<CustomSessionRepository>(),
          ),
        ),
      ],
      child: this,
    );
  }
}

int getStepIndex(String currentName) {
  return switch (currentName) {
    "PackSelectionRoute" => 0,
    "FlashcardsFilterRoute" => 1,
    "FlashcardTagSelectionRoute" => 2,
    "FlashcardLimitRoute" => 3,
    _ => -1,
  };
}

String getTitle(int stepIndex) {
  return switch (stepIndex) {
    0 => 'Select Packs',
    1 => 'Choose Filters',
    2 => 'Pick Tags',
    3 => 'Summary',
    _ => '',
  };
}
