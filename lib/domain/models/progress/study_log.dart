import 'dart:convert';
import 'dart:math';

/// The student's objective, used to draw the trajectory.
class StudyGoal {
  final DateTime? examDate;

  /// How many cards the student wants to have studied by the exam.
  final int? targetCards;

  /// OSCE score (in %) the student aims for on every station.
  final int targetOsceScore;

  /// The packs studied for this exam. Empty means every pack.
  final List<String> packIds;

  /// Day (see [dayKey]) the packs or the target were last changed. History
  /// from before then counted different cards, so it isn't drawn.
  final String? since;

  const StudyGoal({
    this.examDate,
    this.targetCards,
    this.targetOsceScore = 70,
    this.packIds = const [],
    this.since,
  });

  bool get isEmpty =>
      examDate == null && targetCards == null && packIds.isEmpty;

  bool get hasPacks => packIds.isNotEmpty;

  /// Whether cards of [packId] count towards the goal.
  bool includesPack(String packId) =>
      packIds.isEmpty || packIds.contains(packId);

  /// Whether [other] counts different cards, so progress starts over.
  bool countsDifferently(StudyGoal other) =>
      other.targetCards != targetCards || !_sameSet(other.packIds, packIds);

  StudyGoal copyWith({
    DateTime? Function()? examDate,
    int? Function()? targetCards,
    int? targetOsceScore,
    List<String>? packIds,
    String? Function()? since,
  }) => StudyGoal(
    examDate: examDate == null ? this.examDate : examDate(),
    targetCards: targetCards == null ? this.targetCards : targetCards(),
    targetOsceScore: targetOsceScore ?? this.targetOsceScore,
    packIds: packIds ?? this.packIds,
    since: since == null ? this.since : since(),
  );

  Map<String, dynamic> toJson() => {
    if (examDate != null) 'examDate': dayKey(examDate!),
    if (targetCards != null) 'targetCards': targetCards,
    'targetOsceScore': targetOsceScore,
    if (packIds.isNotEmpty) 'packs': packIds,
    if (since != null) 'since': since,
  };

  factory StudyGoal.fromJson(Map<String, dynamic> json) => StudyGoal(
    examDate: DateTime.tryParse(json['examDate'] as String? ?? ''),
    targetCards: (json['targetCards'] as num?)?.toInt(),
    targetOsceScore: (json['targetOsceScore'] as num?)?.toInt() ?? 70,
    packIds: [
      for (final id in json['packs'] as List<dynamic>? ?? const [])
        if (id is String) id,
    ],
    since: json['since'] as String?,
  );
}

bool _sameSet(List<String> a, List<String> b) =>
    a.length == b.length && a.toSet().containsAll(b);

/// Shares of the goal that are celebrated while studying, in percent.
const goalMilestones = [25, 50, 75, 100];

/// Bonus XP for reaching each of [goalMilestones].
const milestoneBonusXp = {25: 50, 50: 100, 75: 150, 100: 300};

/// How far the student is towards the goal, as last counted on the server
/// plus the new goal cards studied on this device since then.
class GoalProgress {
  final int studied;
  final int target;

  /// New cards of the goal's packs studied since [studied] was counted.
  final int newSince;

  /// Milestones (see [goalMilestones]) already shown for this goal.
  final List<int> reached;

  const GoalProgress({
    required this.studied,
    required this.target,
    this.newSince = 0,
    this.reached = const [],
  });

  int get estimate => studied + newSince;

  int get percent =>
      target <= 0 ? 0 : min(100, (estimate * 100 / target).floor());

  GoalProgress copyWith({int? newSince, List<int>? reached}) => GoalProgress(
    studied: studied,
    target: target,
    newSince: newSince ?? this.newSince,
    reached: reached ?? this.reached,
  );

  Map<String, dynamic> toJson() => {
    's': studied,
    't': target,
    'n': newSince,
    'r': reached,
  };

  factory GoalProgress.fromJson(Map<String, dynamic> json) => GoalProgress(
    studied: (json['s'] as num?)?.toInt() ?? 0,
    target: (json['t'] as num?)?.toInt() ?? 0,
    newSince: (json['n'] as num?)?.toInt() ?? 0,
    reached: [
      for (final m in json['r'] as List<dynamic>? ?? const [])
        if (m is num) m.toInt(),
    ],
  );
}

/// What the student did on one day.
class DayActivity {
  final int reviews;
  final int newCards;
  final int forgotten;

  const DayActivity({this.reviews = 0, this.newCards = 0, this.forgotten = 0});

  DayActivity add({required bool isNew, required bool forgot}) => DayActivity(
    reviews: reviews + 1,
    newCards: newCards + (isNew ? 1 : 0),
    forgotten: forgotten + (forgot ? 1 : 0),
  );

  List<int> toJson() => [reviews, newCards, forgotten];

  factory DayActivity.fromJson(List<dynamic> json) => DayActivity(
    reviews: (json.elementAtOrNull(0) as num?)?.toInt() ?? 0,
    newCards: (json.elementAtOrNull(1) as num?)?.toInt() ?? 0,
    forgotten: (json.elementAtOrNull(2) as num?)?.toInt() ?? 0,
  );
}

/// Running totals for one OSCE question (section), to find weak areas.
class OsceQuestionLog {
  final String text;
  final int attempts;
  final int achieved;
  final int max;

  const OsceQuestionLog({
    required this.text,
    this.attempts = 0,
    this.achieved = 0,
    this.max = 0,
  });

  double get percent => max == 0 ? 0 : achieved / max;

  Map<String, dynamic> toJson() => {
    't': text,
    'n': attempts,
    'a': achieved,
    'm': max,
  };

  factory OsceQuestionLog.fromJson(Map<String, dynamic> json) =>
      OsceQuestionLog(
        text: json['t'] as String? ?? '',
        attempts: (json['n'] as num?)?.toInt() ?? 0,
        achieved: (json['a'] as num?)?.toInt() ?? 0,
        max: (json['m'] as num?)?.toInt() ?? 0,
      );
}

/// What the device has recorded about one OSCE station.
class OsceStationLog {
  final String name;
  final Map<String, OsceQuestionLog> questions;

  /// How many times each checklist item was missed.
  final Map<String, int> missedChecks;

  const OsceStationLog({
    required this.name,
    this.questions = const {},
    this.missedChecks = const {},
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'q': questions.map((key, value) => MapEntry(key, value.toJson())),
    'miss': missedChecks,
  };

  factory OsceStationLog.fromJson(Map<String, dynamic> json) => OsceStationLog(
    name: json['name'] as String? ?? '',
    questions: (json['q'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(
        key,
        OsceQuestionLog.fromJson(value as Map<String, dynamic>),
      ),
    ),
    missedChecks: (json['miss'] as Map<String, dynamic>? ?? {}).map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    ),
  );
}

/// One finished OSCE question, as recorded by [StudyLog.recordOsce].
class OsceQuestionResult {
  final String text;
  final int achieved;
  final int max;
  final List<String> missedChecks;

  const OsceQuestionResult({
    required this.text,
    required this.achieved,
    required this.max,
    required this.missedChecks,
  });
}

/// Study history kept on the device. Firestore only stores the current state
/// of every card, so the daily activity, the number of studied cards over time
/// and OSCE details are recorded here as the student studies.
class StudyLog {
  static const _keepDays = 400;

  final Map<String, DayActivity> days;

  /// Number of studied cards, recorded once per day the progress is opened.
  final Map<String, int> studiedSnapshots;
  final Map<String, OsceStationLog> osce;
  final StudyGoal goal;

  /// This device's count towards the goal, for the milestones. Not shared
  /// between devices.
  final GoalProgress? goalProgress;

  /// XP of days older than the kept history, so the level never drops.
  final int archivedXp;

  /// XP earned for goal milestones.
  final int bonusXp;

  /// Cards of the day's session target studied on this device, by day and
  /// pack (or "goal"). The counts of all devices add up.
  final Map<String, Map<String, int>> sessions;

  /// The session target chosen for a pack (0: the default) and when it was
  /// chosen. The latest choice of any device counts.
  final Map<String, (int, int)> packTargets;

  /// The day's goal target, fixed when first worked out so every device
  /// studies the same number: day -> (target, when, goal signature).
  final Map<String, (int, int, int)> dayTargets;

  /// The most new cards and reviews to study a day (0: no limit chosen) and
  /// when they were chosen. The latest choice of any device counts.
  final (int, int, int)? limits;

  const StudyLog({
    this.days = const {},
    this.studiedSnapshots = const {},
    this.osce = const {},
    this.goal = const StudyGoal(),
    this.goalProgress,
    this.archivedXp = 0,
    this.bonusXp = 0,
    this.sessions = const {},
    this.packTargets = const {},
    this.dayTargets = const {},
    this.limits,
  });

  StudyLog copyWith({
    Map<String, DayActivity>? days,
    Map<String, int>? studiedSnapshots,
    Map<String, OsceStationLog>? osce,
    StudyGoal? goal,
    GoalProgress? Function()? goalProgress,
    int? archivedXp,
    int? bonusXp,
    Map<String, Map<String, int>>? sessions,
    Map<String, (int, int)>? packTargets,
    Map<String, (int, int, int)>? dayTargets,
    (int, int, int)? Function()? limits,
  }) => StudyLog(
    days: days ?? this.days,
    studiedSnapshots: studiedSnapshots ?? this.studiedSnapshots,
    osce: osce ?? this.osce,
    goal: goal ?? this.goal,
    goalProgress: goalProgress == null ? this.goalProgress : goalProgress(),
    archivedXp: archivedXp ?? this.archivedXp,
    bonusXp: bonusXp ?? this.bonusXp,
    sessions: sessions ?? this.sessions,
    packTargets: packTargets ?? this.packTargets,
    dayTargets: dayTargets ?? this.dayTargets,
    limits: limits == null ? this.limits : limits(),
  );

  /// The chosen daily limits: new cards and reviews a day, or null when the
  /// student hasn't set them (sessions then use their usual size).
  ({int newCards, int reviews})? get dailyLimits {
    final chosen = limits;
    if (chosen == null || (chosen.$1 <= 0 && chosen.$2 <= 0)) return null;
    return (newCards: max(0, chosen.$1), reviews: max(0, chosen.$2));
  }

  /// Sets the daily limits, or with null goes back to no limits.
  StudyLog setDailyLimits(
    ({int newCards, int reviews})? chosen,
    DateTime now,
  ) => copyWith(
    limits: () => (
      chosen?.newCards ?? 0,
      chosen?.reviews ?? 0,
      now.millisecondsSinceEpoch,
    ),
  );

  /// Days of session counts and day targets kept.
  static const _sessionDays = 3;

  Map<String, T> _recent<T>(Map<String, T> map, DateTime now) {
    final oldest = dayKey(now.subtract(const Duration(days: _sessionDays)));
    return Map.fromEntries(
      map.entries.where((entry) => entry.key.compareTo(oldest) >= 0),
    );
  }

  /// Cards of today's session target studied in [key] (a pack or "goal").
  int sessionDone(DateTime now, String key) => sessions[dayKey(now)]?[key] ?? 0;

  /// Counts one more card of today's session target in [key].
  StudyLog addSessionCard(DateTime now, String key) {
    final day = dayKey(now);
    final today = {...?sessions[day]};
    today[key] = (today[key] ?? 0) + 1;
    return copyWith(sessions: _recent({...sessions, day: today}, now));
  }

  /// The session target chosen for [packId], or null for the default.
  int? packTarget(String packId) {
    final target = packTargets[packId]?.$1 ?? 0;
    return target > 0 ? target : null;
  }

  /// Chooses [packId]'s session target; null goes back to the default.
  StudyLog setPackTarget(String packId, int? target, DateTime now) => copyWith(
    packTargets: {
      ...packTargets,
      packId: (target ?? 0, now.millisecondsSinceEpoch),
    },
  );

  /// Today's goal target if it was already worked out for this goal.
  int? dayTarget(DateTime now, int goalSignature) {
    final fixed = dayTargets[dayKey(now)];
    return fixed != null && fixed.$3 == goalSignature ? fixed.$1 : null;
  }

  /// Fixes today's goal target, unless it already is for this goal.
  StudyLog fixDayTarget(DateTime now, int target, int goalSignature) {
    if (dayTarget(now, goalSignature) != null) return this;
    return copyWith(
      dayTargets: _recent({
        ...dayTargets,
        dayKey(now): (target, now.millisecondsSinceEpoch, goalSignature),
      }, now),
    );
  }

  /// Experience points from everything studied: cards, OSCEs and goal
  /// milestones.
  int get xp {
    var total = archivedXp + bonusXp;
    for (final day in days.values) {
      total += dayXp(day);
    }
    for (final station in osce.values) {
      for (final q in station.questions.values) {
        total += q.attempts * osceQuestionXp + q.achieved;
      }
    }
    return total;
  }

  /// Sets a new goal. Counting towards it starts over when it counts
  /// different cards.
  StudyLog setGoal(StudyGoal newGoal, DateTime now) {
    final changed = goal.countsDifferently(newGoal);
    return copyWith(
      goal: changed ? newGoal.copyWith(since: () => dayKey(now)) : newGoal,
      goalProgress: changed ? () => null : null,
    );
  }

  /// Records the goal count from the server. Milestones already passed are
  /// marked as reached without being celebrated again.
  StudyLog recordGoalProgress({required int studied, required int target}) {
    final previous = goalProgress;
    final keepReached = previous != null && previous.target == target
        ? previous.reached
        : const <int>[];
    final percent = target <= 0 ? 0 : studied * 100 / target;
    return copyWith(
      goalProgress: () => GoalProgress(
        studied: studied,
        target: target,
        reached: {
          ...keepReached,
          for (final m in goalMilestones)
            if (percent >= m) m,
        }.toList()..sort(),
      ),
    );
  }

  /// Counts a new card of [packId] towards the goal. Returns the milestones
  /// this card reached.
  (StudyLog, List<int>) recordGoalCard(String packId) {
    final progress = goalProgress;
    if (progress == null || !goal.includesPack(packId)) return (this, const []);
    final updated = progress.copyWith(newSince: progress.newSince + 1);
    final reachedNow = [
      for (final m in goalMilestones)
        if (updated.percent >= m && !progress.reached.contains(m)) m,
    ];
    if (reachedNow.isEmpty) {
      return (copyWith(goalProgress: () => updated), const []);
    }
    return (
      copyWith(
        goalProgress: () =>
            updated.copyWith(reached: [...progress.reached, ...reachedNow]),
        bonusXp:
            bonusXp +
            reachedNow.fold(0, (sum, m) => sum + (milestoneBonusXp[m] ?? 0)),
      ),
      reachedNow,
    );
  }

  DayActivity activityOn(DateTime day) =>
      days[dayKey(day)] ?? const DayActivity();

  StudyLog recordReview({
    required DateTime now,
    required bool isNew,
    required bool forgot,
  }) {
    final key = dayKey(now);
    final updated = {
      ...days,
      key: (days[key] ?? const DayActivity()).add(isNew: isNew, forgot: forgot),
    };
    final kept = _trim(updated, now);
    final dropped = updated.entries
        .where((e) => !kept.containsKey(e.key))
        .fold(0, (sum, e) => sum + dayXp(e.value));
    return copyWith(days: kept, archivedXp: archivedXp + dropped);
  }

  StudyLog recordStudiedCount(DateTime now, int studied) => copyWith(
    studiedSnapshots: _trim({...studiedSnapshots, dayKey(now): studied}, now),
  );

  StudyLog recordOsce({
    required String osceId,
    required String name,
    required List<OsceQuestionResult> results,
  }) {
    final station = osce[osceId] ?? OsceStationLog(name: name);
    final questions = {...station.questions};
    final missed = {...station.missedChecks};
    for (final result in results) {
      final current =
          questions[result.text] ?? OsceQuestionLog(text: result.text);
      questions[result.text] = OsceQuestionLog(
        text: result.text,
        attempts: current.attempts + 1,
        achieved: current.achieved + result.achieved,
        max: current.max + result.max,
      );
      for (final check in result.missedChecks) {
        missed[check] = (missed[check] ?? 0) + 1;
      }
    }
    return copyWith(
      osce: {
        ...osce,
        osceId: OsceStationLog(
          name: name,
          questions: questions,
          missedChecks: missed,
        ),
      },
    );
  }

  /// Combines the history recorded on several devices: activity and OSCE
  /// results are added up, studied-card counts take the highest value.
  /// The goal comes from [goal] when given, otherwise from the first log.
  ///
  /// XP is added up as well; the goal count is this device's (the first
  /// log).
  static StudyLog merge(List<StudyLog> logs, {StudyGoal? goal}) {
    if (logs.isEmpty) return StudyLog(goal: goal ?? const StudyGoal());
    final days = <String, DayActivity>{};
    final studied = <String, int>{};
    final osce = <String, OsceStationLog>{};
    final sessions = <String, Map<String, int>>{};
    final packTargets = <String, (int, int)>{};
    final dayTargets = <String, (int, int, int)>{};
    final signature = goalSignature(goal ?? logs.first.goal);
    (int, int, int)? limits;
    for (final log in logs) {
      final chosen = log.limits;
      if (chosen != null && (limits == null || chosen.$3 > limits.$3)) {
        limits = chosen;
      }
      log.sessions.forEach((day, counts) {
        final merged = sessions[day] ??= {};
        counts.forEach((key, value) {
          merged[key] = (merged[key] ?? 0) + value;
        });
      });
      log.packTargets.forEach((packId, value) {
        final current = packTargets[packId];
        if (current == null || value.$2 > current.$2) {
          packTargets[packId] = value;
        }
      });
      // The first target worked out for the current goal counts.
      log.dayTargets.forEach((day, value) {
        final current = dayTargets[day];
        final matches = value.$3 == signature;
        final currentMatches = current?.$3 == signature;
        if (current == null ||
            (matches && !currentMatches) ||
            (matches == currentMatches && value.$2 < current.$2)) {
          dayTargets[day] = value;
        }
      });
      log.days.forEach((key, value) {
        final current = days[key] ?? const DayActivity();
        days[key] = DayActivity(
          reviews: current.reviews + value.reviews,
          newCards: current.newCards + value.newCards,
          forgotten: current.forgotten + value.forgotten,
        );
      });
      log.studiedSnapshots.forEach((key, value) {
        if (value > (studied[key] ?? -1)) studied[key] = value;
      });
      log.osce.forEach((id, station) {
        final current = osce[id];
        if (current == null) {
          osce[id] = station;
          return;
        }
        final questions = {...current.questions};
        station.questions.forEach((key, value) {
          final q = questions[key];
          questions[key] = q == null
              ? value
              : OsceQuestionLog(
                  text: value.text,
                  attempts: q.attempts + value.attempts,
                  achieved: q.achieved + value.achieved,
                  max: q.max + value.max,
                );
        });
        final missed = {...current.missedChecks};
        station.missedChecks.forEach((key, value) {
          missed[key] = (missed[key] ?? 0) + value;
        });
        osce[id] = OsceStationLog(
          name: current.name.isEmpty ? station.name : current.name,
          questions: questions,
          missedChecks: missed,
        );
      });
    }
    return StudyLog(
      days: days,
      studiedSnapshots: studied,
      osce: osce,
      goal: goal ?? logs.first.goal,
      goalProgress: logs.first.goalProgress,
      archivedXp: logs.fold(0, (sum, log) => sum + log.archivedXp),
      bonusXp: logs.fold(0, (sum, log) => sum + log.bonusXp),
      sessions: sessions,
      packTargets: packTargets,
      dayTargets: dayTargets,
      limits: limits,
    );
  }

  Map<String, T> _trim<T>(Map<String, T> map, DateTime now) {
    final oldest = dayKey(now.subtract(const Duration(days: _keepDays)));
    return Map.fromEntries(
      map.entries.where((entry) => entry.key.compareTo(oldest) >= 0),
    );
  }

  String encode() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
    'days': days.map((key, value) => MapEntry(key, value.toJson())),
    'studied': studiedSnapshots,
    'osce': osce.map((key, value) => MapEntry(key, value.toJson())),
    'goal': goal.toJson(),
    if (goalProgress != null) 'goalProgress': goalProgress!.toJson(),
    if (archivedXp > 0) 'xpArchived': archivedXp,
    if (bonusXp > 0) 'xpBonus': bonusXp,
    if (sessions.isNotEmpty) 'sessions': sessions,
    if (packTargets.isNotEmpty)
      'packTargets': packTargets.map(
        (key, value) => MapEntry(key, [value.$1, value.$2]),
      ),
    if (dayTargets.isNotEmpty)
      'dayTargets': dayTargets.map(
        (key, value) => MapEntry(key, [value.$1, value.$2, value.$3]),
      ),
    if (limits != null) 'limits': [limits!.$1, limits!.$2, limits!.$3],
  };

  factory StudyLog.decode(String? source) {
    if (source == null || source.isEmpty) return const StudyLog();
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      return StudyLog(
        days: (json['days'] as Map<String, dynamic>? ?? {}).map(
          (key, value) =>
              MapEntry(key, DayActivity.fromJson(value as List<dynamic>)),
        ),
        studiedSnapshots: (json['studied'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, (value as num).toInt()),
        ),
        osce: (json['osce'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(
            key,
            OsceStationLog.fromJson(value as Map<String, dynamic>),
          ),
        ),
        goal: StudyGoal.fromJson(
          json['goal'] as Map<String, dynamic>? ?? const {},
        ),
        goalProgress: json['goalProgress'] is Map<String, dynamic>
            ? GoalProgress.fromJson(
                json['goalProgress'] as Map<String, dynamic>,
              )
            : null,
        archivedXp: (json['xpArchived'] as num?)?.toInt() ?? 0,
        bonusXp: (json['xpBonus'] as num?)?.toInt() ?? 0,
        sessions: (json['sessions'] as Map<String, dynamic>? ?? {}).map(
          (day, counts) => MapEntry(
            day,
            (counts as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, (value as num).toInt()),
            ),
          ),
        ),
        packTargets: (json['packTargets'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, (
            ((value as List<dynamic>)[0] as num).toInt(),
            (value[1] as num).toInt(),
          )),
        ),
        dayTargets: (json['dayTargets'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, (
            ((value as List<dynamic>)[0] as num).toInt(),
            (value[1] as num).toInt(),
            (value[2] as num).toInt(),
          )),
        ),
        limits: json['limits'] is List && (json['limits'] as List).length == 3
            ? (
                ((json['limits'] as List)[0] as num).toInt(),
                ((json['limits'] as List)[1] as num).toInt(),
                ((json['limits'] as List)[2] as num).toInt(),
              )
            : null,
      );
    } on Object {
      // A damaged log shouldn't break the app, start over.
      return const StudyLog();
    }
  }
}

/// Local calendar day as "yyyy-mm-dd", which also sorts by date.
String dayKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

DateTime startOfDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// XP for each kind of review.
const newCardXp = 10;
const reviewXp = 5;
const forgottenXp = 2;

/// XP for each finished OSCE question, plus one per mark scored.
const osceQuestionXp = 5;

int dayXp(DayActivity day) {
  final others = max(0, day.reviews - day.newCards - day.forgotten);
  return day.newCards * newCardXp +
      others * reviewXp +
      day.forgotten * forgottenXp;
}

/// A number that changes when the goal changes, the same on every device.
int goalSignature(StudyGoal goal) {
  var hash = 17;
  for (final unit in jsonEncode(goal.toJson()).codeUnits) {
    hash = (hash * 31 + unit) & 0x3fffffff;
  }
  return hash;
}
