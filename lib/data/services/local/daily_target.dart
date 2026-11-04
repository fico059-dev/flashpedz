import 'dart:convert';
import 'dart:math';

import 'package:flashcards/data/services/api/users/auth_service.dart';
import 'package:flashcards/data/services/local/study_log_store.dart';
import 'package:flashcards/domain/models/progress/study_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cards a day the exam goal needs: what is left divided by the days to the
/// exam (like "Needed: 70 new cards/day" on the Progress tab). Null when
/// there is no exam date or the goal hasn't been counted yet.
int? goalCardsPerDay(StudyLog log, DateTime now) {
  final exam = log.goal.examDate;
  final progress = log.goalProgress;
  if (exam == null || progress == null || progress.target <= 0) return null;
  final daysLeft = startOfDay(exam).difference(startOfDay(now)).inDays;
  if (daysLeft <= 0) return null;
  // Counted from the start of the day, so studying today doesn't lower
  // today's number.
  final newToday = min(progress.newSince, log.activityOn(now).newCards);
  final remaining = max(0, progress.target - (progress.estimate - newToday));
  if (remaining == 0) return null;
  return max(1, (remaining / daysLeft).ceil());
}

/// How the student is doing with today's cards, shown as a parrot.
enum DailyMood {
  /// Today's target is done.
  happy,

  /// Half of today's target is done.
  excited,

  /// Less than 4 hours left today and the target isn't done.
  anxious,

  /// Yesterday's target wasn't reached.
  sad,

  /// Nothing special: keep going.
  calm,
}

DailyMood dailyMood({
  required int done,
  required int target,
  required DateTime now,
  int? yesterdayDone,
  int? yesterdayTarget,
}) {
  if (target > 0 && done >= target) return DailyMood.happy;
  final midnight = startOfDay(now).add(const Duration(days: 1));
  if (midnight.difference(now) <= const Duration(hours: 4)) {
    return DailyMood.anxious;
  }
  if (target > 0 && done * 2 >= target) return DailyMood.excited;
  if (yesterdayTarget != null &&
      yesterdayTarget > 0 &&
      (yesterdayDone ?? 0) < yesterdayTarget) {
    return DailyMood.sad;
  }
  return DailyMood.calm;
}

/// Today's card target and how much of it is done.
class DailyStatus {
  final int target;
  final int done;
  final int? yesterdayTarget;
  final int? yesterdayDone;

  /// Whether the target comes from the exam goal (else cards per session).
  final bool fromGoal;
  final DailyMood mood;

  /// The student's daily plan: new cards and reviews a day. When set, the
  /// target is their sum.
  final ({int newCards, int reviews})? plan;

  /// New cards and reviews studied today, on all devices.
  final int newDone;
  final int reviewDone;

  /// What the exam goal needs a day, to suggest for the plan.
  final int? goalPerDay;

  const DailyStatus({
    required this.target,
    required this.done,
    required this.fromGoal,
    required this.mood,
    this.yesterdayTarget,
    this.yesterdayDone,
    this.plan,
    this.newDone = 0,
    this.reviewDone = 0,
    this.goalPerDay,
  });

  double get progress => target <= 0 ? 0 : min(1.0, done / target);
}

/// Works out the day's card target. With an exam goal it is what the goal
/// needs per day; otherwise the student's cards per session. The goal's
/// target is fixed for the day when first worked out and shared with the
/// user's other devices, so studying doesn't move it and every device shows
/// the same number. Cards studied count from all devices.
class DailyTargetService {
  final StudyLogStore _logStore;
  final AuthService _auth;
  final DateTime Function() _now;
  SharedPreferencesAsync? _prefsInstance;

  SharedPreferencesAsync get _prefs =>
      _prefsInstance ??= SharedPreferencesAsync();

  DailyTargetService({
    required StudyLogStore logStore,
    required AuthService auth,
    SharedPreferencesAsync? prefs,
    DateTime Function()? now,
  }) : _logStore = logStore,
       _auth = auth,
       _prefsInstance = prefs,
       _now = now ?? DateTime.now;

  String? get _key {
    final uid = _auth.getCurrentUser()?.uid;
    return uid == null ? null : 'daily_targets_$uid';
  }

  Future<Map<String, int>> _readTargets() async {
    final key = _key;
    if (key == null) return {};
    try {
      final saved = await _prefs.getString(key);
      if (saved == null) return {};
      return (jsonDecode(saved) as Map<String, dynamic>).map(
        (day, value) => MapEntry(day, (value as num).toInt()),
      );
    } catch (_) {
      return {};
    }
  }

  /// Today's target: the student's daily plan (new cards + reviews), else
  /// what the exam goal needs per day, else the cards per session.
  /// Remembered per day, to know later whether it was reached.
  Future<({int target, bool fromGoal})> todayTarget(int cardsPerSession) async {
    final now = _now();
    final today = dayKey(now);
    final log = await _logStore.loadCombined();
    final plan = log.dailyLimits;
    final signature = goalSignature(log.goal);
    var fromGoal = plan != null ? null : log.dayTarget(now, signature);
    if (plan == null && fromGoal == null) {
      fromGoal = goalCardsPerDay(log, now);
      final fixed = fromGoal;
      if (fixed != null) {
        await _logStore.update(
          (log) => log.fixDayTarget(now, fixed, signature),
        );
      }
    }
    final target = plan != null
        ? plan.newCards + plan.reviews
        : fromGoal ?? cardsPerSession;
    final targets = await _readTargets();
    final key = _key;
    if (key != null && targets[today] != target) {
      final oldest = dayKey(now.subtract(const Duration(days: 7)));
      final kept = {
        for (final e in targets.entries)
          if (e.key.compareTo(oldest) >= 0) e.key: e.value,
        today: target,
      };
      try {
        await _prefs.setString(key, jsonEncode(kept));
      } catch (_) {
        // Only yesterday's parrot can be wrong.
      }
    }
    return (target: target, fromGoal: fromGoal != null);
  }

  /// Whether studying [packIds] counts towards the exam goal's daily target.
  Future<bool> isGoalPack(Iterable<String> packIds) async {
    final log = await _logStore.loadCombined();
    final now = _now();
    if (log.dayTarget(now, goalSignature(log.goal)) == null &&
        goalCardsPerDay(log, now) == null) {
      return false;
    }
    return packIds.any(log.goal.includesPack);
  }

  /// Today's target, cards studied today and the mood that goes with it.
  Future<DailyStatus> status(int cardsPerSession) async {
    final now = _now();
    final today = await todayTarget(cardsPerSession);
    final log = await _logStore.loadCombined();
    final yesterday = now.subtract(const Duration(days: 1));
    final targets = await _readTargets();
    // Not opened yesterday: yesterday's target was likely the same.
    final studiedBefore = log.days.keys.any(
      (day) => day.compareTo(dayKey(yesterday)) < 0,
    );
    final yesterdayTarget =
        targets[dayKey(yesterday)] ?? (studiedBefore ? today.target : null);
    final activity = log.activityOn(now);
    final done = activity.reviews;
    final yesterdayDone = log.activityOn(yesterday).reviews;
    return DailyStatus(
      target: today.target,
      done: done,
      fromGoal: today.fromGoal,
      plan: log.dailyLimits,
      newDone: activity.newCards,
      reviewDone: max(0, activity.reviews - activity.newCards),
      goalPerDay: goalCardsPerDay(log, now),
      yesterdayTarget: yesterdayTarget,
      yesterdayDone: yesterdayDone,
      mood: dailyMood(
        done: done,
        target: today.target,
        now: now,
        yesterdayDone: yesterdayDone,
        yesterdayTarget: yesterdayTarget,
      ),
    );
  }
}
