// Renders the home page to a PNG file:
// flutter test test/screens/home_screens_test.dart
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
@Tags(['screens'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flashcards/bloc/profile/profile_reader/profile_reader_cubit.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_state.dart';
import 'package:flashcards/data/repositories/progress/progress_repository.dart';
import 'package:flashcards/data/repositories/users/profile_repository.dart';
import 'package:flashcards/data/services/local/daily_target.dart';
import 'package:flashcards/domain/models/profile/education_level.dart';
import 'package:flashcards/domain/models/profile/profile.dart';
import 'package:flashcards/domain/models/profile/profile_settings/profile_settings.dart';
import 'package:flashcards/domain/models/profile/streak/streak.dart';
import 'package:flashcards/domain/models/progress/card_progress.dart';
import 'package:flashcards/domain/models/progress/study_log.dart';
import 'package:flashcards/ui/pages/main_tab_pages/home_page.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:provider/provider.dart';

final _now = DateTime.now();
final _goal = StudyGoal(
  examDate: _now.add(const Duration(days: 91)),
  packIds: const ['nicu', 'neo'],
);

fsrs.Card _card(fsrs.State state, double stability) => fsrs.Card()
  ..state = state
  ..reps = 2
  ..stability = stability
  ..difficulty = 5
  ..lastReview = _now.subtract(const Duration(days: 1))
  ..due = _now.add(const Duration(days: 2));

class _Progress implements ProgressRepository {
  @override
  Future<Result<CardProgressStats>> getCardStats({bool refresh = false}) async {
    var n = 0;
    CardProgressItem item(String pack, fsrs.State state, double stability) =>
        CardProgressItem(
          flashcardId: '${n++}',
          packId: pack,
          question: 'q',
          tags: const [],
          card: _card(state, stability),
        );
    return Result.ok(
      CardProgressStats.calculate(
        items: [
          for (var i = 0; i < 900; i++) item('nicu', fsrs.State.review, 5),
          for (var i = 0; i < 400; i++) item('nicu', fsrs.State.review, 40),
          for (var i = 0; i < 160; i++) item('neo', fsrs.State.learning, 1),
          for (var i = 0; i < 300; i++) item('neo', fsrs.State.review, 5),
        ],
        packs: const [
          PackInfo(id: 'nicu', name: 'NICU BANK', totalCards: 3800),
          PackInfo(id: 'neo', name: 'Solid Neonatology', totalCards: 2671),
          PackInfo(id: 'onc', name: 'Oncology', totalCards: 900),
        ],
        log: StudyLog(goal: _goal),
        now: _now,
      ),
    );
  }

  @override
  Future<StudyLog> getLog() async => StudyLog(goal: _goal);

  @override
  Future<List<int>?> goalCardLevels(StudyGoal goal) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Daily implements DailyTargetService {
  final bool withPlan;

  _Daily({this.withPlan = false});

  @override
  Future<DailyStatus> status(int cardsPerSession) async => withPlan
      ? const DailyStatus(
          target: 120,
          done: 50,
          fromGoal: false,
          mood: DailyMood.calm,
          plan: (newCards: 30, reviews: 90),
          newDone: 12,
          reviewDone: 38,
          goalPerDay: 70,
        )
      : const DailyStatus(
          target: 70,
          done: 42,
          fromGoal: true,
          mood: DailyMood.excited,
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProfileRepo implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
      '/bin/cache/artifacts/material_fonts/$file',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  for (final withPlan in [false, true]) {
    testWidgets(withPlan ? 'home page with a daily plan' : 'home page', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await _loadFont('Roboto', [
          'Roboto-Regular.ttf',
          'Roboto-Medium.ttf',
          'Roboto-Bold.ttf',
        ]);
        await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
      });
      tester.view.physicalSize = const Size(390 * 2, 1250 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      final profile = ProfileReaderCubit(profileRepo: _ProfileRepo())
        ..emit(
          ProfileReaderState.isLoaded(
            profile: Profile(
              name: 'Faisal',
              surname: 'A',
              username: 'f',
              email: 'f@x.com',
              phoneNumber: '',
              educationLevel: EducationLevel.values.first,
              streak: Streak(count: 3, lastStreakDate: _now),
              profileSettings: const ProfileSettings(cardsPerSession: 100),
            ),
          ),
        );
      final key = GlobalKey();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProgressRepository>.value(value: _Progress()),
            Provider<DailyTargetService>.value(
              value: _Daily(withPlan: withPlan),
            ),
            BlocProvider.value(value: profile),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: lightThemeData,
            home: RepaintBoundary(key: key, child: const HomePage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Today's plan"), findsOneWidget);
      expect(find.text('Your knowledge garden'), findsOneWidget);
      if (withPlan) {
        expect(find.text('Study 120 cards today'), findsOneWidget);
        expect(find.text('12/30'), findsOneWidget);
        expect(find.text('38/90'), findsOneWidget);
      } else {
        expect(
          find.text('Choose cards a day and how many are new'),
          findsOneWidget,
        );
      }

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('build/screens')..createSync(recursive: true);
        File(
          '${dir.path}/${withPlan ? 'home_page_plan' : 'home_page'}.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }
}
