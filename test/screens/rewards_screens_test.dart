// Renders the milestone, level-up, summary, share and goal screens to PNGs:
// flutter test test/screens/rewards_screens_test.dart
@Tags(['screens'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flashcards/data/services/local/study_rewards.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/progress/card_progress.dart';
import 'package:flashcards/domain/models/progress/level.dart';
import 'package:flashcards/domain/models/progress/study_log.dart';
import 'package:flashcards/ui/dialogs/flashcard/share_card_dialog.dart';
import 'package:flashcards/ui/dialogs/progress/goal_packs_dialog.dart';
import 'package:flashcards/ui/dialogs/progress/study_goal_sheet.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'dart:math' show Random;
import 'package:flashcards/ui/widgets/home/card_garden.dart';
import 'package:flashcards/ui/widgets/auth/social_sign_in_buttons.dart';
import 'package:flashcards/ui/widgets/rewards/study_rewards_widgets.dart';
import 'package:flashcards/ui/widgets/rewards/bird_badge.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/listeners/session_milestone_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

final _shotKey = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  // Let asset images decode.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final widget = element.widget as Image;
      await precacheImage(widget.image, element);
    }
  });
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/screens')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _app(
  WidgetTester tester,
  Widget Function(BuildContext) open,
) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _shotKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: lightThemeData,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showDialog<void>(context: context, builder: open),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {});

  Future<void> setup(WidgetTester tester) async {
    await tester.runAsync(() async {
      await _loadFont('Roboto', [
        'Roboto-Regular.ttf',
        'Roboto-Medium.ttf',
        'Roboto-Bold.ttf',
      ]);
      await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
    });
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  testWidgets('milestone 50%', (tester) async {
    await setup(tester);
    await _app(
      tester,
      (_) => const MilestoneDialog(
        reward: MilestoneReward(
          percent: 50,
          studied: 620,
          target: 1240,
          bonusXp: 100,
        ),
      ),
    );
    expect(find.text('Halfway there!'), findsOneWidget);
    await _shot(tester, 'reward_milestone_50');
  });

  testWidgets('milestone 100%', (tester) async {
    await setup(tester);
    await _app(
      tester,
      (_) => const MilestoneDialog(
        reward: MilestoneReward(
          percent: 100,
          studied: 1240,
          target: 1240,
          bonusXp: 300,
        ),
      ),
    );
    await _shot(tester, 'reward_milestone_100');
  });

  testWidgets('level up', (tester) async {
    await setup(tester);
    await _app(tester, (_) => LevelUpDialog(level: LevelInfo.fromXp(1050)));
    expect(find.text('You earned the Kingfisher'), findsOneWidget);
    expect(find.text('Uncommon badge'), findsOneWidget);
    await _shot(tester, 'reward_level_up');
  });

  testWidgets('bird badge collection', (tester) async {
    await setup(tester);
    await _app(
      tester,
      (_) => const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: BirdBadgeCollection(level: 17),
        ),
      ),
    );
    expect(find.text('Phoenix'), findsOneWidget);
    await _shot(tester, 'reward_badges');
  });

  testWidgets('session summary', (tester) async {
    await setup(tester);
    final start = DateTime(2026, 10, 13, 9);
    await _app(
      tester,
      (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SessionSummaryCard(
            summary: SessionSummary(
              startedAt: start,
              lastReviewAt: start.add(const Duration(minutes: 18)),
              reviewed: 40,
              newCards: 12,
              again: 5,
              hard: 7,
              good: 22,
              easy: 6,
              xpAtStart: 950,
              xpNow: 1215,
              milestones: const [50],
              goal: const GoalProgress(
                studied: 600,
                target: 1240,
                newSince: 20,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('88%'), findsOneWidget);
    await _shot(tester, 'reward_session_summary');
  });

  testWidgets('share card', (tester) async {
    await setup(tester);
    await _app(
      tester,
      (_) => const ShareCardDialog(
        flashcard: Flashcard(
          id: 'c1',
          packId: 'p',
          question:
              'What is the first-line treatment for **neonatal** '
              'hypoglycaemia in a symptomatic infant?',
          answer:
              'IV **10% dextrose** bolus 2 mL/kg, then an infusion of '
              '4–6 mg/kg/min.\n| Glucose | Action |\n|---|---|\n'
              '| < 2.6 | Treat |\n| ≥ 2.6 | Monitor |',
          tags: [],
        ),
      ),
    );
    expect(find.text('With highlights'), findsOneWidget);
    await _shot(tester, 'share_card');
  });

  testWidgets('goal packs picker', (tester) async {
    await setup(tester);
    await _app(
      tester,
      (_) => Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {});
          return const SizedBox();
        },
      ),
    );
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    showGoalPacksDialog(
      context,
      packs: const [
        PackInfo(id: 'r1', name: 'Foundation Pack for R1', totalCards: 0),
        PackInfo(
          id: 'neo',
          name: 'Neonatal essentials',
          totalCards: 420,
          parentId: 'r1',
        ),
        PackInfo(
          id: 'peds',
          name: 'Pediatric essentials',
          totalCards: 610,
          parentId: 'r1',
        ),
        PackInfo(
          id: 'call',
          name: 'On-call essentials',
          totalCards: 210,
          parentId: 'r1',
        ),
        PackInfo(id: 'nr', name: 'Neoreview 2004', totalCards: 380),
        PackInfo(id: 'onc', name: 'Oncology', totalCards: 150),
      ],
      selected: const [],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foundation Pack for R1'));
    await tester.pumpAndSettle();
    expect(find.text('4 packs · 1240 cards'), findsOneWidget);
    await _shot(tester, 'goal_packs_picker');

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets('goal sheet', (tester) async {
    await setup(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lightThemeData,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showStudyGoalSheet(
                    context,
                    goal: StudyGoal(
                      examDate: DateTime.now().add(const Duration(days: 90)),
                      packIds: const ['neo', 'peds', 'call', 'r1'],
                    ),
                    totalCards: 1770,
                    loadPacks: () async => const [
                      PackInfo(id: 'r1', name: 'Foundation R1', totalCards: 0),
                      PackInfo(
                        id: 'neo',
                        name: 'Neonatal essentials',
                        totalCards: 420,
                        parentId: 'r1',
                      ),
                      PackInfo(
                        id: 'peds',
                        name: 'Pediatric essentials',
                        totalCards: 610,
                        parentId: 'r1',
                      ),
                      PackInfo(
                        id: 'call',
                        name: 'On-call essentials',
                        totalCards: 210,
                        parentId: 'r1',
                      ),
                    ],
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Packs for this exam'), findsOneWidget);
    await _shot(tester, 'goal_sheet');
  });

  testWidgets('session milestone 50%', (tester) async {
    await setup(tester);
    await _app(
      tester,
      (_) => const SessionMilestoneDialog(percent: 50, done: 35, total: 70),
    );
    expect(find.text('Halfway through today!'), findsOneWidget);
    await _shot(tester, 'session_milestone_50');
  });

  testWidgets('sign in with Google', (tester) async {
    await setup(tester);
    await _app(
      tester,
      (_) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: SocialSignInButtons(),
        ),
      ),
    );
    expect(find.text('Continue with Google'), findsOneWidget);
    await _shot(tester, 'social_sign_in');
  });

  for (final (name, counts) in [
    (
      'garden_now',
      const GardenCounts(
        unseen: 6316,
        learning: 40,
        reviewing: 115,
        mastered: 0,
      ),
    ),
    (
      'garden_later',
      const GardenCounts(
        unseen: 2600,
        learning: 500,
        reviewing: 2100,
        mastered: 1271,
      ),
    ),
    (
      'garden_small',
      const GardenCounts(
        unseen: 300,
        learning: 60,
        reviewing: 200,
        mastered: 160,
      ),
    ),
  ]) {
    for (final grid in [false, true]) {
      testWidgets('$name grid=$grid', (tester) async {
        await setup(tester);
        await _app(
          tester,
          (_) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(8),
              color: grid ? const Color(0x11000000) : const Color(0xFFE8F5E1),
              child: CardGarden(plots: gardenPlots(counts), asGrid: grid),
            ),
          ),
        );
        await _shot(tester, '${name}_${grid ? 'grid' : 'garden'}');
      });
    }
  }

  for (final studied in [155, 2400]) {
    for (final grid in [false, true]) {
      testWidgets('scattered garden $studied grid=$grid', (tester) async {
        await setup(tester);
        final random = Random(7);
        final levels = List.filled(6471, 0);
        final order = List.generate(6471, (i) => i)..shuffle(random);
        for (final i in order.take(studied)) {
          final r = random.nextDouble();
          levels[i] = r < 0.15 ? 1 : (r < 0.75 || studied < 1000 ? 2 : 3);
        }
        await _app(
          tester,
          (_) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(8),
              color: grid ? const Color(0x11000000) : const Color(0xFFE8F5E1),
              child: CardGarden(
                plots: gardenPlotsFromCards(levels),
                asGrid: grid,
              ),
            ),
          ),
        );
        await _shot(tester, 'scatter_${studied}_${grid ? 'grid' : 'garden'}');
      });
    }
  }
}
