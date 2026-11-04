import 'package:flashcards/bloc/authorization/auth/auth_bloc.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_cubit.dart';
import 'package:flashcards/bloc/theme/theme_cubit.dart';
import 'package:flashcards/data/remote/cloud_storage_service.dart';
import 'package:flashcards/data/remote/firestore_db_context.dart';
import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/data/remote/network_service.dart';
import 'package:flashcards/data/repositories/algolia_search/flashcards_searcher_repository.dart';
import 'package:flashcards/data/repositories/algolia_search/packs_searcher_repository.dart';
import 'package:flashcards/data/repositories/flashcards/custom_session_repository.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pack_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pp_repository.dart';
import 'package:flashcards/data/repositories/flashcards/report_repository.dart';
import 'package:flashcards/data/repositories/flashcards/tag_repository.dart';
import 'package:flashcards/data/repositories/osces/osce_performance_repository.dart';
import 'package:flashcards/data/repositories/users/auth_repository.dart';
import 'package:flashcards/data/repositories/osces/osce_repository.dart';
import 'package:flashcards/data/repositories/users/profile_repository.dart';
import 'package:flashcards/data/repositories/users/user_roles_repository.dart';
import 'package:flashcards/data/repositories/utils/cache/data_cache/data_cache.dart';
import 'package:flashcards/data/repositories/utils/cache/page_cache/page_cache.dart';
import 'package:flashcards/data/services/api/algolia_search/flashcards_searcher_service.dart';
import 'package:flashcards/data/services/api/flashcards/custom_session_service.dart';
import 'package:flashcards/data/services/api/algolia_search/packs_searcher_service.dart';
import 'package:flashcards/data/services/api/flashcards/tag_service.dart';
import 'package:flashcards/data/services/api/notifications/notification_service.dart';
import 'package:flashcards/data/services/api/osce/osce_performance_service.dart';
import 'package:flashcards/data/services/api/osce/osce_service.dart';
import 'package:flashcards/data/services/api/users/auth_service.dart';
import 'package:flashcards/data/services/api/flashcards/fcp_service.dart';
import 'package:flashcards/data/services/api/flashcards/flashcard_service.dart';
import 'package:flashcards/data/services/api/flashcards/pack_service.dart';
import 'package:flashcards/data/services/api/flashcards/pp_service.dart';
import 'package:flashcards/data/services/api/flashcards/report_service.dart';
import 'package:flashcards/data/services/api/users/profile_service.dart';
import 'package:flashcards/data/services/api/users/user_roles_service.dart';
import 'package:flashcards/data/services/local/session_progress_store.dart';
import 'package:flashcards/data/services/local/local_storage_service.dart';
import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/domain/models/flashcards/pack/pack.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/data/repositories/progress/progress_repository.dart';
import 'package:flashcards/data/services/local/study_log_store.dart';
import 'package:flashcards/data/services/local/study_rewards.dart';
import 'package:flashcards/data/services/local/daily_target.dart';
import 'package:flashcards/data/repositories/card_sets/card_set_repository.dart';
import 'package:flashcards/data/repositories/notebook/highlight_repository.dart';
import 'package:flashcards/data/repositories/osces/osce_library_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

class AppDependencies {
  final bool isDev;

  late final DataCache<Tag> _tagCache;
  late final PageCache<Pack> _packsCache;
  late final PageCache<AdminPack> _adminPacksCache;

  late final FirestoreDbContext _dbContext;
  late final CloudFunctionService _functions;
  late final CloudStorageService _storage;
  late final AuthService _authService;
  late final LocalStorageService _localStorageService;
  late final StudyLogStore _studyLogStore;
  late final StudyRewards _studyRewards;
  late final DailyTargetService _dailyTarget;
  late final SessionProgressStore _sessionProgress;

  late final NotificationService _notificationService;

  late final ThemeCubit _themeCubit;

  AppDependencies({required this.isDev});

  /// [onStep] is told what is being set up, to name it if starting fails.
  Future<void> initialize({void Function(String step)? onStep}) async {
    void step(String name) => onStep?.call(name);

    // I declare caches here because some caches are used in multiple repos,
    // and i inject them to the repo directly from here
    _tagCache = DataCache<Tag>(
      cacheDuration: Duration(minutes: 45),
      getId: (item) => item.id,
    );
    _packsCache = PageCache<Pack>(
      cacheDuration: Duration(minutes: 20),
      getId: (item) => item.id,
    );
    _adminPacksCache = PageCache<AdminPack>(
      cacheDuration: Duration(minutes: 20),
      getId: (item) => item.packId,
    );

    // Database
    step('database (Firestore)');
    _dbContext = FirestoreDbContext();
    step('server functions');
    _functions = CloudFunctionService();
    step('file storage (images)');
    _storage = CloudStorageService();

    step('notifications');
    _notificationService = NotificationService();
    await _notificationService.init();

    step('sign-in');
    _authService = AuthService();
    step('saved settings');
    _localStorageService = LocalStorageService(authService: _authService);
    _studyLogStore = StudyLogStore(
      authService: _authService,
      remote: CloudStudyLogRemote(
        get: _functions.getStudyLog,
        save: _functions.saveStudyLog,
      ),
    );
    _studyRewards = StudyRewards(store: _studyLogStore);
    _dailyTarget = DailyTargetService(
      logStore: _studyLogStore,
      auth: _authService,
    );
    _sessionProgress = SessionProgressStore(logStore: _studyLogStore);

    step('theme');
    _themeCubit = ThemeCubit(storageService: _localStorageService);
    await _themeCubit.loadTheme();
  }

  void invalidateAllCaches() {
    _packsCache.invalidate();
    _adminPacksCache.invalidate();
    _tagCache.invalidate();
  }

  void dispose() {
    invalidateAllCaches();
    _themeCubit.close();
  }

  List<SingleChildWidget> getProviders() {
    return [
      Provider<NotificationService>.value(value: _notificationService),

      Provider(create: (context) => NetworkService(), lazy: false),

      //Services
      Provider.value(value: _authService),
      Provider.value(value: _localStorageService),
      Provider.value(value: _studyLogStore),
      Provider.value(value: _studyRewards),
      Provider.value(value: _dailyTarget),
      Provider.value(value: _sessionProgress),
      Provider(create: (context) => ProfileService(dbContext: _dbContext)),
      Provider(
        create: (context) =>
            PackService(dbContext: _dbContext, functions: _functions),
      ),
      Provider(create: (context) => FcpService(dbContext: _dbContext)),
      Provider(
        create: (context) => FlashcardService(
          dbContext: _dbContext,
          functions: _functions,
          storage: _storage,
        ),
      ),
      Provider(
        create: (context) =>
            OsceService(dbContext: _dbContext, storage: _storage),
      ),
      Provider(
        create: (context) =>
            PpService(dbContext: _dbContext, functions: _functions),
      ),
      Provider(
        create: (context) => OscePerformanceService(dbContext: _dbContext),
      ),
      Provider(create: (context) => ReportService(dbContext: _dbContext)),
      Provider(create: (context) => UserRolesService(functions: _functions)),
      Provider(create: (context) => TagService(dbContext: _dbContext)),
      Provider(
        create: (context) => CustomSessionService(
          dbContext: _dbContext,
          cloudFunctionService: _functions,
        ),
      ),
      Provider(
        create: (context) => PacksSearcherService(dbContext: _dbContext),
      ),
      Provider(
        create: (context) => FlashcardsSearcherService(functions: _functions),
      ),

      // Repositories
      Provider(
        create: (context) => AuthRepository(
          invalidateAllCaches: invalidateAllCaches,
          authService: context.read<AuthService>(),
          profileService: context.read<ProfileService>(),
        ),
      ),
      Provider(
        create: (context) => ProfileRepository(
          profileService: context.read<ProfileService>(),
          authService: context.read<AuthService>(),
          functions: _functions,
        ),
      ),
      Provider(
        create: (context) => PackRepository(
          packService: context.read<PackService>(),
          authService: context.read<AuthService>(),
          fcpService: context.read<FcpService>(),
          adminPacksCache: _adminPacksCache,
          packCache: _packsCache,
        ),
      ),
      Provider(
        create: (context) => FlashcardRepository(
          flashcardService: context.read<FlashcardService>(),
          packService: context.read<PackService>(),
          tagService: context.read<TagService>(),
          authService: context.read<AuthService>(),
          fcpService: context.read<FcpService>(),
          adminPacksCache: _adminPacksCache,
          tagCache: _tagCache,
          packCache: _packsCache,
        ),
      ),
      Provider(
        create: (context) => OsceRepository(
          osceService: context.read<OsceService>(),
          oscePerfService: context.read<OscePerformanceService>(),
        ),
      ),
      Provider(
        create: (context) => OsceLibraryRepository(
          osceService: context.read<OsceService>(),
          osceRepository: context.read<OsceRepository>(),
          functions: _functions,
        ),
      ),
      Provider(
        create: (context) => OscePerformanceRepository(
          oscePerfService: context.read<OscePerformanceService>(),
          dbContext: _dbContext,
          authService: context.read<AuthService>(),
        ),
      ),
      Provider(
        create: (context) => FcpRepository(
          fcpService: context.read<FcpService>(),
          authService: context.read<AuthService>(),
          flashcardService: context.read<FlashcardService>(),
          packService: context.read<PackService>(),
          packCache: _packsCache,
          studyLog: _studyLogStore,
          rewards: _studyRewards,
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => CardSetRepository(
          functions: _functions,
          authService: context.read<AuthService>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => HighlightRepository(
          functions: _functions,
          authService: context.read<AuthService>(),
        ),
      ),
      Provider(
        create: (context) => ProgressRepository(
          fcpService: context.read<FcpService>(),
          packService: context.read<PackService>(),
          osceService: context.read<OsceService>(),
          oscePerfService: context.read<OscePerformanceService>(),
          authService: context.read<AuthService>(),
          logStore: _studyLogStore,
        ),
      ),
      Provider(
        create: (context) => PpRepository(
          ppService: context.read<PpService>(),
          authService: context.read<AuthService>(),
          packsCache: _packsCache,
        ),
      ),
      Provider(
        create: (context) => ReportRepository(
          reportService: context.read<ReportService>(),
          authService: context.read<AuthService>(),
          packService: context.read<PackService>(),
          dbContext: _dbContext,
        ),
      ),
      Provider(
        create: (context) => UserRolesRepository(
          userRolesService: context.read<UserRolesService>(),
        ),
      ),
      Provider(
        create: (context) => TagRepository(
          tagService: context.read<TagService>(),
          tagCache: _tagCache,
        ),
      ),
      Provider(
        create: (context) => CustomSessionRepository(
          customSessionService: context.read<CustomSessionService>(),
          authService: context.read<AuthService>(),
        ),
      ),
      Provider(
        create: (context) => PacksSearcherRepository(
          packSearcherService: context.read<PacksSearcherService>(),
        ),
      ),
      Provider(
        create: (context) => FlashcardsSearcherRepository(
          flashcardsSearcherService: context.read<FlashcardsSearcherService>(),
        ),
      ),

      // Global blocs (some blocs will be injected directly into pages,
      // saving memory. Meaning you call BlocProvider inside page not here)
      BlocProvider<AuthBloc>(
        create: (context) => AuthBloc(
          authRepository: context.read<AuthRepository>(),
          profileRepository: context.read<ProfileRepository>(),
        ),
      ),
      BlocProvider<ProfileReaderCubit>(
        create: (context) =>
            ProfileReaderCubit(profileRepo: context.read<ProfileRepository>()),
      ),
      BlocProvider.value(value: _themeCubit),
    ];
  }
}
