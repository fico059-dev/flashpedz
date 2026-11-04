import 'package:flashcards/data/services/local/study_log_store.dart';
import 'package:flashcards/data/services/local/study_rewards.dart';
import 'package:flashcards/domain/models/progress/card_progress.dart';
import 'package:flashcards/domain/models/progress/level.dart';
import 'package:flashcards/domain/models/progress/study_log.dart';
import 'package:flashcards/ui/dialogs/progress/goal_packs_dialog.dart';
import 'package:fsrs/fsrs.dart';
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

class _Remote implements StudyLogRemote {
  final Map<String, String> devices;
  String? goal;

  _Remote([this.devices = const {}]);

  @override
  Future<({Map<String, String> devices, String? goal})> fetch() async =>
      (devices: Map.of(devices), goal: goal);

  @override
  Future<void> save({
    required String deviceId,
    required String log,
    String? goal,
  }) async {}
}

void main() {
  final day = DateTime(2026, 10, 13, 10);

  group('XP and levels', () {
    test('levels need 100 more XP each time', () {
      expect([1, 2, 3, 4, 5].map(xpForLevel), [0, 100, 300, 600, 1000]);
      expect(LevelInfo.fromXp(0).level, 1);
      expect(LevelInfo.fromXp(99).level, 1);
      expect(LevelInfo.fromXp(100).level, 2);
      final info = LevelInfo.fromXp(450);
      expect(info.level, 3);
      expect(info.xpIntoLevel, 150);
      expect(info.xpToNextLevel, 150);
      expect(info.progress, 0.5);
      expect(LevelInfo.fromXp(0).title, 'Pigeon');
      expect(LevelInfo.fromXp(1000).title, 'Kingfisher');
      expect(LevelInfo.fromXp(1000).nextTitle, 'Woodpecker');
      expect(LevelInfo.fromXp(13600).title, 'Phoenix');
      expect(LevelInfo.fromXp(15300).title, 'Phoenix ★2');
      expect(birdBadgeFor(1).rarity, BirdRarity.common);
      expect(birdBadgeFor(17).rarity, BirdRarity.legendary);
    });

    test('XP comes from new cards, reviews, lapses and OSCEs', () {
      var log = const StudyLog();
      log = log.recordReview(now: day, isNew: true, forgot: false); // 10
      log = log.recordReview(now: day, isNew: false, forgot: false); // 5
      log = log.recordReview(now: day, isNew: false, forgot: true); // 2
      expect(log.xp, 17);
      log = log.recordOsce(
        osceId: 'o',
        name: 'Station',
        results: const [
          OsceQuestionResult(
            text: 'History',
            achieved: 6,
            max: 8,
            missedChecks: [],
          ),
        ],
      );
      expect(log.xp, 17 + 5 + 6);
    });

    test('old days leave the history but keep their XP', () {
      var log = const StudyLog().recordReview(
        now: DateTime(2025, 1, 1),
        isNew: true,
        forgot: false,
      );
      log = log.recordReview(now: day, isNew: true, forgot: false);
      expect(log.days.length, 1);
      expect(log.xp, 20);
    });

    test('XP of all devices is added up and survives saving', () {
      final phone = const StudyLog(
        archivedXp: 40,
        bonusXp: 50,
      ).recordReview(now: day, isNew: true, forgot: false);
      final web = const StudyLog(
        bonusXp: 100,
      ).recordReview(now: day, isNew: false, forgot: false);
      final merged = StudyLog.merge([phone, web]);
      expect(merged.xp, phone.xp + web.xp);
      expect(StudyLog.decode(phone.encode()).xp, phone.xp);
    });
  });

  group('goal milestones', () {
    StudyLog withGoal({List<String> packs = const []}) => const StudyLog()
        .setGoal(StudyGoal(packIds: packs), day)
        .recordGoalProgress(studied: 20, target: 100);

    test('passed milestones are not celebrated again', () {
      final log = const StudyLog().recordGoalProgress(studied: 55, target: 100);
      expect(log.goalProgress!.reached, [25, 50]);
    });

    test('a new card that reaches a milestone celebrates it once', () {
      var log = withGoal();
      final reached = <int>[];
      for (var i = 0; i < 31; i++) {
        final (updated, now) = log.recordGoalCard('p1');
        log = updated;
        reached.addAll(now);
      }
      expect(reached, [25, 50]);
      expect(log.goalProgress!.estimate, 51);
      expect(log.bonusXp, 150);
      expect(StudyLog.decode(log.encode()).goalProgress!.reached, [25, 50]);
    });

    test('only cards of the goal packs count', () {
      var log = withGoal(packs: ['nicu']);
      for (var i = 0; i < 10; i++) {
        log = log.recordGoalCard('other').$1;
      }
      expect(log.goalProgress!.newSince, 0);
      final (updated, reached) = log.recordGoalCard('nicu');
      expect(updated.goalProgress!.newSince, 1);
      expect(reached, isEmpty);
    });

    test('changing the packs starts the goal count over', () {
      final log = withGoal(packs: ['a']);
      final same = log.setGoal(
        log.goal.copyWith(examDate: () => DateTime(2027)),
        day,
      );
      expect(same.goalProgress, isNotNull);
      final changed = log.setGoal(const StudyGoal(packIds: ['a', 'b']), day);
      expect(changed.goalProgress, isNull);
      expect(changed.goal.since, dayKey(day));
      final json = StudyGoal.fromJson(changed.goal.toJson());
      expect(json.packIds, ['a', 'b']);
      expect(json.since, dayKey(day));
    });
  });

  test('the trajectory only counts the goal packs', () {
    Card studied() => Card()
      ..state = State.review
      ..reps = 1
      ..stability = 5
      ..difficulty = 5
      ..lastReview = day
      ..due = day.add(const Duration(days: 3));
    CardProgressItem item(String id, String pack, {bool seen = true}) =>
        CardProgressItem(
          flashcardId: id,
          packId: pack,
          question: id,
          tags: const [],
          card: seen ? studied() : Card(),
          ignored: false,
        );
    final packs = const [
      PackInfo(id: 'nicu', name: 'NICU', totalCards: 10),
      PackInfo(id: 'onc', name: 'Oncology', totalCards: 30),
    ];
    final items = [
      item('1', 'nicu'),
      item('2', 'nicu'),
      item('3', 'onc'),
      item('4', 'onc'),
      item('5', 'onc'),
    ];
    final stats = CardProgressStats.calculate(
      items: items,
      packs: packs,
      log: const StudyLog(goal: StudyGoal(packIds: ['nicu'])),
      now: day,
    );
    expect(stats.studied, 5);
    expect(stats.trajectory.studied, 2);
    expect(stats.trajectory.target, 10);
    expect(stats.trajectory.packNames, ['NICU']);
    expect(
      goalTarget(
        packs: packs,
        goal: const StudyGoal(packIds: ['onc']),
      ),
      30,
    );
  });

  test('the pack picker lists sub-packs under their pack', () {
    final rows = goalPackRows(const [
      PackInfo(id: 'r1', name: 'Foundation R1', totalCards: 0),
      PackInfo(id: 'neo', name: 'Neonatal', totalCards: 5, parentId: 'r1'),
      PackInfo(id: 'onc', name: 'Oncology', totalCards: 5),
      PackInfo(id: 'peds', name: 'Pediatric', totalCards: 5, parentId: 'r1'),
      PackInfo(id: 'neo2', name: 'NICU drugs', totalCards: 5, parentId: 'neo'),
    ]);
    expect(rows.map((r) => '${r.depth}:${r.pack.id}'), [
      '0:r1',
      '1:neo',
      '2:neo2',
      '1:peds',
      '0:onc',
    ]);
    expect(rows.first.descendantIds, ['neo', 'neo2', 'peds']);
  });

  group('StudyRewards', () {
    test('reviews give XP, milestones and level ups to the session', () async {
      final store = StudyLogStore(
        authService: FakeAuth(),
        prefs: _MemoryPrefs(),
        remote: _Remote({'other-device': const StudyLog(bonusXp: 90).encode()}),
      );
      await store.update(
        (log) => log.recordGoalProgress(studied: 0, target: 4),
      );
      var now = day;
      final rewards = StudyRewards(store: store, now: () => now);
      final seen = <StudyReward>[];
      rewards.rewards.listen(seen.add);

      await rewards.startSession();
      expect(rewards.session!.xpAtStart, 90);

      // New card: 10 XP, 25% of the goal (+50 XP) and level 2 (100 XP).
      now = day.add(const Duration(minutes: 3));
      final earned = await rewards.recordReview(
        packId: 'p',
        isNew: true,
        forgot: false,
        rating: Rating.good,
      );
      expect(earned.whereType<MilestoneReward>().single.percent, 25);
      expect(earned.whereType<LevelUpReward>().single.level.level, 2);
      await rewards.recordReview(
        packId: 'p',
        isNew: false,
        forgot: true,
        rating: Rating.again,
      );
      await Future<void>.delayed(Duration.zero);
      expect(seen.length, 2);

      final s = rewards.session!;
      expect(s.reviewed, 2);
      expect(s.newCards, 1);
      expect(s.again, 1);
      expect(s.good, 1);
      expect(s.recall, 0.5);
      expect(s.xpEarned, 10 + 50 + 2);
      expect(s.levelsGained, 1);
      expect(s.milestones, [25]);
      expect(s.goal!.percent, 25);
      expect(s.duration, const Duration(minutes: 3));
    });
  });
}
