import 'package:flashcards/data/services/local/daily_target.dart';
import 'package:flashcards/data/services/local/study_log_store.dart';
import 'package:flashcards/domain/models/progress/study_log.dart';
import 'package:flashcards/ui/widgets/flashcard/flashcard_test/listeners/session_milestone_listener.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notebook_test.dart' show FakeAuth;

class _MemoryPrefs implements SharedPreferencesAsync {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime(2026, 10, 13, 10);

  StudyLog goalLog() => StudyLog(
    goal: StudyGoal(
      examDate: DateTime(2027, 1, 12),
      packIds: const ['nicu', 'neo'],
    ),
  ).recordGoalProgress(studied: 132, target: 6471);

  test('the goal decides the cards per day', () {
    // 6339 cards left in 91 days, like the Progress tab.
    expect(goalCardsPerDay(goalLog(), now), 70);
    expect(goalCardsPerDay(const StudyLog(), now), isNull);
    expect(goalCardsPerDay(goalLog(), DateTime(2027, 2, 1)), isNull);
  });

  test('a goal pack studies the goal target, fixed for the day', () async {
    final prefs = _MemoryPrefs();
    final store = StudyLogStore(authService: FakeAuth(), prefs: prefs);
    await store.update((_) => goalLog());
    var clock = now;
    final service = DailyTargetService(
      logStore: store,
      auth: FakeAuth(),
      prefs: prefs,
      now: () => clock,
    );

    // Worked out before the goal was counted (e.g. by the streak parrot),
    // the goal still applies once it is known.
    await store.update((log) => log.copyWith(goalProgress: () => null));
    expect(await service.todayTarget(100), (target: 100, fromGoal: false));
    await store.update((_) => goalLog());

    expect(await service.isGoalPack(['nicu']), isTrue);
    expect(await service.isGoalPack(['oncology']), isFalse);
    expect(await service.todayTarget(100), (target: 70, fromGoal: true));

    // Studying 40 new cards today doesn't change today's target.
    await store.update((log) {
      var updated = log;
      for (var i = 0; i < 40; i++) {
        updated = updated
            .recordReview(now: clock, isNew: true, forgot: false)
            .recordGoalCard('nicu')
            .$1;
      }
      return updated;
    });
    expect((await service.todayTarget(100)).target, 70);
    final status = await service.status(100);
    expect(status.done, 40);
    expect(status.mood, DailyMood.excited);

    // Without a goal, the cards per session.
    await store.update((log) => log.setGoal(const StudyGoal(), clock));
    clock = DateTime(2026, 10, 14, 9);
    expect(await service.todayTarget(100), (target: 100, fromGoal: false));
    // Yesterday 40 of 70: sad.
    expect((await service.status(100)).mood, DailyMood.sad);
  });

  test('a daily plan sets the target, new cards and reviews', () async {
    final prefs = _MemoryPrefs();
    final store = StudyLogStore(authService: FakeAuth(), prefs: prefs);
    await store.update((_) => goalLog());
    final service = DailyTargetService(
      logStore: store,
      auth: FakeAuth(),
      prefs: prefs,
      now: () => now,
    );
    await store.update(
      (log) => log.setDailyLimits((newCards: 30, reviews: 90), now),
    );
    // The plan comes before the exam goal.
    expect(await service.todayTarget(100), (target: 120, fromGoal: false));

    await store.update((log) {
      var updated = log;
      for (var i = 0; i < 10; i++) {
        updated = updated.recordReview(now: now, isNew: i < 4, forgot: false);
      }
      return updated;
    });
    final status = await service.status(100);
    expect(status.plan, (newCards: 30, reviews: 90));
    expect(status.done, 10);
    expect(status.newDone, 4);
    expect(status.reviewDone, 6);
    // The goal is still offered as a suggestion.
    expect(status.goalPerDay, 70);

    // Plan off: back to the goal.
    await store.update((log) => log.setDailyLimits(null, now));
    expect((await service.status(100)).plan, isNull);
  });

  test('the parrot follows today and yesterday', () {
    DailyMood mood(int done, {int hour = 10, int? yDone, int? yTarget}) =>
        dailyMood(
          done: done,
          target: 70,
          now: DateTime(2026, 10, 13, hour),
          yesterdayDone: yDone,
          yesterdayTarget: yTarget,
        );
    expect(mood(70), DailyMood.happy);
    expect(mood(70, hour: 23), DailyMood.happy);
    expect(mood(35), DailyMood.excited);
    expect(mood(50, hour: 21), DailyMood.anxious);
    expect(mood(10, hour: 19), DailyMood.calm);
    expect(mood(10, yDone: 30, yTarget: 70), DailyMood.sad);
    expect(mood(10, yDone: 70, yTarget: 70), DailyMood.calm);
  });

  test('session milestones at 25, 50 and 75%', () {
    int? reached(int before, int after, int total) =>
        sessionMilestoneReached(before: before, after: after, total: total);
    expect(reached(24, 25, 100), 25);
    expect(reached(25, 26, 100), isNull);
    expect(reached(34, 35, 70), 50);
    expect(reached(17, 18, 70), 25);
    expect(reached(52, 53, 70), 75);
    expect(reached(69, 70, 70), isNull); // 100% shows the end page
  });
}
