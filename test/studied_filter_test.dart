import 'package:flashcards/bloc/custom_session/pack_filter/pack_filter_bloc.dart';
import 'package:flashcards/bloc/custom_session/studied_filter.dart';
import 'package:flashcards/data/repositories/flashcards/fcp_repository.dart';
import 'package:flashcards/domain/models/flashcards/flashcard_filter_counts/pack_filter_counts.dart';
import 'package:flashcards/ui/pages/custom_session/custom_session_maker/flashcards_filter_page.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class _Fcp implements FcpRepository {
  @override
  Future<Result<PackFilterCounts>> getFilterCounts(
    List<String> packIds,
    int allCount,
  ) async => Result.ok(
    const PackFilterCounts(
      allCount: 100,
      seenCount: 40,
      bookmarkedCount: 3,
      ignoredCount: 0,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('only a choice other than all is sent', () {
    expect(StudiedCardsFilter.all.requestValue, isNull);
    expect(StudiedCardsFilter.hard.requestValue, 'hard');
    expect(StudiedCardsFilter.forgotten.requestValue, 'forgotten');
  });

  testWidgets('seen cards: choose the hard ones', (tester) async {
    final studied = StudiedFilterNotifier();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          BlocProvider(create: (_) => PackFilterBloc(fcpRepo: _Fcp())),
          ChangeNotifierProvider.value(value: studied),
        ],
        child: GlobalLoaderOverlay(
          child: MaterialApp(
            theme: lightThemeData,
            home: const FlashcardsFilterPage(
              selectedPacks: ['p'],
              allCount: 100,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Which studied cards?'), findsNothing);

    await tester.tap(find.text('Seen cards 40'));
    await tester.pumpAndSettle();
    expect(find.text('Which studied cards?'), findsOneWidget);
    await tester.tap(find.text('Hard for me'));
    await tester.pumpAndSettle();
    expect(studied.value, StudiedCardsFilter.hard);
    expect(find.textContaining('difficult for you'), findsOneWidget);
  });
}
