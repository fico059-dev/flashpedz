import 'package:flashcards/bloc/custom_session/session_limit/session_limit_cubit.dart';
import 'package:flashcards/bloc/custom_session/session_tag_picker/session_tag_picker_cubit.dart';
import 'package:flashcards/bloc/custom_session/studied_filter.dart';
import 'package:flashcards/data/repositories/flashcards/custom_session_repository.dart';
import 'package:flashcards/domain/enums/pack_selected_filter.dart';
import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/ui/pages/custom_session/custom_session_maker/flashcard_limit_page.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class _Sessions implements CustomSessionRepository {
  final bool offline;
  _Sessions({this.offline = false});

  int? sessionSize;
  bool? matchAnyTag;

  @override
  Future<Result<({int allTags, int anyTag})>> countMatchingCards({
    required PackSelectedFilter filter,
    required List<String> tags,
    required List<String> packIds,
    List<String> topics = const [],
    List<String> excludeTags = const [],
    String? studied,
  }) async => offline
      ? Result.error(Exception('offline'))
      : Result.ok((allTags: 37, anyTag: 1250));

  @override
  Future<Result<void>> createCustomSession({
    required int sessionSize,
    required PackSelectedFilter filter,
    required List<String> tags,
    required List<String> packIds,
    String? name,
    List<String> topics = const [],
    List<String> excludeTags = const [],
    String? studied,
    bool matchAnyTag = false,
  }) async {
    this.sessionSize = sessionSize;
    this.matchAnyTag = matchAnyTag;
    return Result.error(Exception('stop here'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester, _Sessions sessions) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        BlocProvider(
          create: (_) => SessionLimitCubit(customSessionRepo: sessions),
        ),
        BlocProvider(create: (_) => SessionTagPickerCubit()),
        ChangeNotifierProvider(create: (_) => StudiedFilterNotifier()),
      ],
      child: GlobalLoaderOverlay(
        child: MaterialApp(
          theme: lightThemeData,
          home: const FlashcardLimitPage(
            selectedPacks: [
              AdminPack(
                packId: 'p',
                packName: 'Cardio',
                flashcardsCount: 3000,
                isPaid: false,
                tagCounts: {},
              ),
            ],
            filter: PackSelectedFilter.all,
            selectedTags: [
              Tag(id: 'dara', name: 'Dara'),
              Tag(id: 'cardiology', name: 'Cardiology'),
            ],
            // The old guess: the rarer tag's count.
            packFilterCount: 400,
            isCountExact: false,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the real number of matching cards, all of them by default', (
    tester,
  ) async {
    final sessions = _Sessions();
    await _open(tester, sessions);
    expect(
      find.text(
        '37 flashcards match your choices. How many would you like in '
        'your exam?',
      ),
      findsOneWidget,
    );
    expect(find.text('All these tags (37)'), findsOneWidget);
    expect(find.text('Any of these tags (1250)'), findsOneWidget);
    expect(find.text('37'), findsOneWidget);
    expect(find.text('This number is an estimate.'), findsNothing);

    // Any tag: every card with Dara or Cardiology.
    await tester.tap(find.text('Any of these tags (1250)'));
    await tester.pumpAndSettle();
    expect(find.text('1250'), findsOneWidget);
    expect(find.textContaining('Dara or Cardiology'), findsOneWidget);

    await tester.tap(find.text('Create exam'));
    await tester.pumpAndSettle();
    expect(sessions.sessionSize, 1250);
    expect(sessions.matchAnyTag, isTrue);
  });

  testWidgets('a typed number stays; Use all puts every card back', (
    tester,
  ) async {
    await _open(tester, _Sessions());
    await tester.enterText(find.byType(TextField).last, '10');
    await tester.tap(find.text('Any of these tags (1250)'));
    await tester.pumpAndSettle();
    expect(find.text('10'), findsOneWidget);
    await tester.tap(find.text('Use all 1250'));
    await tester.pump();
    expect(find.text('1250'), findsOneWidget);
  });

  testWidgets('offline: the estimate as before', (tester) async {
    await _open(tester, _Sessions(offline: true));
    expect(find.textContaining('Up to 400 flashcards'), findsOneWidget);
    expect(find.text('All these tags (37)'), findsNothing);
  });
}
