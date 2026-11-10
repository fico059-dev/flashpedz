import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/custom_session/custom_session_getter/custom_session_getter_bloc.dart';
import 'package:flashcards/bloc/custom_session/custom_session_getter/custom_session_getter_event.dart';
import 'package:flashcards/bloc/osces/osce_getter/osce_getter_bloc.dart';
import 'package:flashcards/bloc/osces/osce_getter/osce_getter_event.dart';
import 'package:flashcards/bloc/pack/packs_getter/packs_getter_bloc.dart';
import 'package:flashcards/bloc/pack/packs_getter/packs_getter_event.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/data/repositories/algolia_search/flashcards_searcher_repository.dart';
import 'package:flashcards/data/repositories/flashcards/custom_session_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pack_repository.dart';
import 'package:flashcards/data/repositories/osces/osce_repository.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/ui/pages/main_tab_pages/main_tab_routes.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flashcards/ui/widgets/core/app_bar_streak.dart';
import 'package:flutter/cupertino.dart';
import 'package:flashcards/ui/widgets/app_update/app_update_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class MainTabPage extends StatefulWidget implements AutoRouteWrapper {
  const MainTabPage({super.key});

  @override
  State<MainTabPage> createState() => _MainTabPageState();

  @override
  Widget wrappedRoute(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              PacksGetterBloc(packRepository: context.read<PackRepository>()),
        ),
        BlocProvider(
          create: (context) =>
              OsceGetterBloc(osceRepo: context.read<OsceRepository>()),
        ),
        BlocProvider(
          create: (context) => CustomSessionGetterBloc(
            sessionRepo: context.read<CustomSessionRepository>(),
          ),
        ),
      ],
      child: this,
    );
  }
}

class _MainTabPageState extends State<MainTabPage> with AutoRouteAware {
  TabsRouter? _tabsRouter;
  AutoRouteObserver? _observer;
  List<Widget> appBarActions = [];

  @override
  void initState() {
    super.initState();
    // Gets flashcard search ready in the background once the first screen
    // has loaded, so the first search doesn't wait for the download.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      try {
        // A problem here only matters once the user searches.
        context.read<FlashcardsSearcherRepository>().preload().catchError(
          (Object _) => const Result<void>.ok(null),
        );
      } on ProviderNotFoundException {
        // Not available (tests).
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _observer = RouterScope.of(
      context,
    ).firstObserverOfType<AutoRouteObserver>();
    if (_observer != null) {
      _observer!.subscribe(this, context.routeData);
    }
  }

  @override
  void didPopNext() {
    super.didPopNext();

    if (_tabsRouter!.isRouteActive(PacksRoute.name)) {
      context.read<PacksGetterBloc>().add(PacksGetterCacheRead());
      return;
    }

    if (_tabsRouter!.isRouteActive(OsceListRoute.name)) {
      context.read<OsceGetterBloc>().add(OsceGetterCacheRead());
    }

    if (_tabsRouter!.isRouteActive(PreviousSessionsRoute.name)) {
      context.read<CustomSessionGetterBloc>().add(
        CustomSessionGetterStateReset(),
      );
    }

    // print("[DEBUG] calling assign from pop");
    _assignAppBarActions();
  }

  void _assignAppBarActions() {
    if (_tabsRouter!.isRouteActive(OsceListRoute.name)) {
      print("[DEBUG] osce list active");

      appBarActions = [
        IconButton(
          onPressed: () => context.router.push(OsceTutorialRoute()),
          icon: const Icon(CupertinoIcons.question_circle),
        ),
      ];
    } else if (_tabsRouter!.isRouteActive(PacksRoute.name)) {
      print("[DEBUG] packs active");

      appBarActions = [
        IconButton(
          onPressed: () => context.router.push(FlashcardsTutorialRoute()),
          icon: const Icon(CupertinoIcons.question_circle),
        ),
        IconButton(
          tooltip: 'Search flashcards',
          onPressed: () => context.router.push(StudySearchRoute()),
          icon: const Icon(Icons.search),
        ),
      ];
    } else if (_tabsRouter!.isRouteActive(PreviousSessionsRoute.name) ||
        _tabsRouter!.isRouteActive(CustomSessionResultRoute.name)) {
      print("[DEBUG] previous sessions active");

      appBarActions = [
        IconButton(
          onPressed: () => context.router.push(CustomSessionWrapperRoute()),
          icon: const Icon(CupertinoIcons.add),
        ),
      ];
    } else if (_tabsRouter!.isRouteActive(PacksTabRoute.name)) {
      print("[DEBUG] packs tab active");
      appBarActions = [
        IconButton(
          onPressed: () => context.router.push(FlashcardsTutorialRoute()),
          icon: const Icon(CupertinoIcons.question_circle),
        ),
        IconButton(
          tooltip: 'Search flashcards',
          onPressed: () => context.router.push(StudySearchRoute()),
          icon: const Icon(Icons.search),
        ),
      ];
    } else {
      print("[DEBUG] no actions tabs active");
      appBarActions = [];
    }
  }

  @override
  void dispose() {
    _observer?.unsubscribe(this);
    super.dispose();
  }

  static const _destinations = [
    (icon: Icons.home_outlined, selected: Icons.home, label: "Home"),
    (icon: Icons.list_alt_outlined, selected: Icons.list_alt, label: "OSCE"),
    (icon: Icons.style_outlined, selected: Icons.style, label: "Cards"),
    (
      icon: Icons.insights_outlined,
      selected: Icons.insights,
      label: "Progress",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Tells the student when a new app version is out.
    return AppUpdateChecker(
      child: AutoTabsRouter(
        routes: MainTabRoutes.mainTabPages,
        builder: (context, child) {
          final tabsRouter = AutoTabsRouter.of(context);
          _tabsRouter ??= tabsRouter;

          final title = MainTabRoutes.getRouteTitle(context, tabsRouter);
          _assignAppBarActions();

          // Computers get a side menu, phones the bottom tab bar.
          final wide = isWideLayout(context);

          return Scaffold(
            appBar: AppBar(
              title: Text(title),
              leading: wide
                  ? null
                  : IconButton(
                      icon: Icon(CupertinoIcons.profile_circled),
                      onPressed: () {
                        context.router.push(ProfileRoute());
                      },
                    ),
              automaticallyImplyLeading: false,
              actions: [...appBarActions, const AppBarStreak()],
            ),
            body: wide
                ? Row(
                    children: [
                      NavigationRail(
                        extended: MediaQuery.sizeOf(context).width >= 1100,
                        minExtendedWidth: 200,
                        selectedIndex: tabsRouter.activeIndex,
                        onDestinationSelected: tabsRouter.setActiveIndex,
                        labelType: MediaQuery.sizeOf(context).width >= 1100
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        destinations: [
                          for (final d in _destinations)
                            NavigationRailDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selected),
                              label: Text(d.label),
                            ),
                        ],
                        trailingAtBottom: true,
                        trailing: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: IconButton(
                            tooltip: "Profile",
                            icon: Icon(CupertinoIcons.profile_circled),
                            onPressed: () {
                              context.router.push(ProfileRoute());
                            },
                          ),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: ReadableWidth(maxWidth: 1000, child: child),
                      ),
                    ],
                  )
                : child,
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    onDestinationSelected: tabsRouter.setActiveIndex,
                    selectedIndex: tabsRouter.activeIndex,
                    destinations: [
                      for (final d in _destinations)
                        NavigationDestination(
                          selectedIcon: Icon(d.selected),
                          icon: Icon(d.icon),
                          label: d.label,
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
