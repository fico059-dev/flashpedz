import 'package:fake_async/fake_async.dart';
import 'package:flashcards/data/services/local/session_progress_store.dart';
import 'package:flashcards/data/services/local/study_log_store.dart';
import 'package:flashcards/domain/models/progress/study_log.dart';
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

/// Stands in for the online copy shared by all devices.
class _FakeRemote implements StudyLogRemote {
  final devices = <String, String>{};
  String? goal;
  bool offline = false;
  int saves = 0;

  @override
  Future<({Map<String, String> devices, String? goal})> fetch() async {
    if (offline) throw Exception('No connection');
    return (devices: Map.of(devices), goal: goal);
  }

  @override
  Future<void> save({
    required String deviceId,
    required String log,
    String? goal,
  }) async {
    if (offline) throw Exception('No connection');
    saves++;
    devices[deviceId] = log;
    if (goal != null) this.goal = goal;
  }
}

void main() {
  final day = DateTime(2026, 10, 4, 10);

  StudyLogStore device(_FakeRemote remote) => StudyLogStore(
    authService: FakeAuth(),
    prefs: _MemoryPrefs(),
    remote: remote,
  );

  test('phone and website history are added up, not doubled', () async {
    final remote = _FakeRemote();
    final phone = device(remote);
    final web = device(remote);

    for (var i = 0; i < 3; i++) {
      await phone.update(
        (log) => log.recordReview(now: day, isNew: i == 0, forgot: false),
      );
    }
    await web.update(
      (log) => log.recordReview(now: day, isNew: false, forgot: true),
    );
    await phone.uploadNow();
    await web.uploadNow();
    // Uploading again must not count the same reviews twice.
    await phone.uploadNow();

    final seenOnWeb = await web.loadCombined();
    expect(seenOnWeb.activityOn(day).reviews, 4);
    expect(seenOnWeb.activityOn(day).newCards, 1);
    expect(seenOnWeb.activityOn(day).forgotten, 1);
    expect(remote.devices, hasLength(2));
  });

  test('reviews are uploaded by themselves shortly after studying', () {
    fakeAsync((async) {
      final remote = _FakeRemote();
      final phone = device(remote);
      phone.update(
        (log) => log.recordReview(now: day, isNew: true, forgot: false),
      );
      async.flushMicrotasks();
      expect(remote.saves, 0);
      async.elapse(StudyLogStore.uploadDelay + const Duration(seconds: 1));
      expect(remote.saves, 1);
    });
  });

  test('the exam goal set on one device shows on the other', () async {
    final remote = _FakeRemote();
    final phone = device(remote);
    final web = device(remote);

    await phone.saveGoal(
      StudyGoal(examDate: DateTime(2027, 3, 1), targetCards: 2000),
    );
    final onWeb = await web.loadCombined();
    expect(onWeb.goal.targetCards, 2000);
    expect(onWeb.goal.examDate, DateTime(2027, 3, 1));
  });

  test('offline it still shows what this device recorded', () async {
    final remote = _FakeRemote()..offline = true;
    final phone = device(remote);
    await phone.update(
      (log) => log.recordReview(now: day, isNew: false, forgot: false),
    );
    await phone.uploadNow();
    expect((await phone.loadCombined()).activityOn(day).reviews, 1);
  });

  test('OSCE details from both devices are combined', () {
    final a = const StudyLog().recordOsce(
      osceId: 's1',
      name: 'Asthma',
      results: const [
        OsceQuestionResult(
          text: 'History',
          achieved: 3,
          max: 5,
          missedChecks: ['Triggers'],
        ),
      ],
    );
    final b = const StudyLog().recordOsce(
      osceId: 's1',
      name: 'Asthma',
      results: const [
        OsceQuestionResult(
          text: 'History',
          achieved: 5,
          max: 5,
          missedChecks: ['Triggers'],
        ),
      ],
    );
    final merged = StudyLog.merge([a, b]);
    final question = merged.osce['s1']!.questions['History']!;
    expect(question.attempts, 2);
    expect(question.achieved, 8);
    expect(question.max, 10);
    expect(merged.osce['s1']!.missedChecks['Triggers'], 2);
  });

  test('a session continues on another device of the same account', () async {
    final remote = _FakeRemote();
    final phone = device(remote);
    final web = device(remote);
    var now = day;
    final phoneSession = SessionProgressStore(logStore: phone, now: () => now);
    final webSession = SessionProgressStore(logStore: web, now: () => now);

    for (var i = 0; i < 6; i++) {
      await phoneSession.add('u1', 'neo');
    }
    await phoneSession.flush();

    // The website opens the same pack: it continues at 6.
    await webSession.refresh();
    expect(await webSession.doneToday('u1', 'neo'), 6);
    await webSession.add('u1', 'neo');
    await webSession.flush();

    await phoneSession.refresh();
    expect(await phoneSession.doneToday('u1', 'neo'), 7);
    expect(await phoneSession.doneToday('u1', 'onc'), 0);

    // A pack's own target follows the latest choice on any device.
    await phoneSession.setPackTarget('u1', 'neo', 30);
    await webSession.refresh();
    expect(await webSession.packTarget('u1', 'neo'), 30);
    now = now.add(const Duration(minutes: 1));
    await webSession.setPackTarget('u1', 'neo', null);
    await phoneSession.refresh();
    expect(await phoneSession.packTarget('u1', 'neo'), isNull);

    // A new day starts a new session everywhere.
    now = day.add(const Duration(days: 1));
    expect(await phoneSession.doneToday('u1', 'neo'), 0);
  });

  test('the first day target worked out for the goal is used everywhere', () {
    const goal = StudyGoal(targetCards: 200);
    final signature = goalSignature(goal);
    final later = day.add(const Duration(hours: 2));
    final phone = const StudyLog(goal: goal).fixDayTarget(day, 70, signature);
    final web = const StudyLog(goal: goal).fixDayTarget(later, 64, signature);
    final merged = StudyLog.merge([web, phone]);
    expect(merged.dayTarget(later, signature), 70);
    // Once known, a device keeps the shared number.
    expect(
      merged.fixDayTarget(later, 50, signature).dayTarget(day, signature),
      70,
    );

    // A changed goal is worked out again.
    const newGoal = StudyGoal(targetCards: 300);
    final newSignature = goalSignature(newGoal);
    expect(merged.dayTarget(day, newSignature), isNull);
    final changed = StudyLog(
      goal: newGoal,
    ).fixDayTarget(later, 90, newSignature);
    expect(
      StudyLog.merge([
        phone,
        changed,
      ], goal: newGoal).dayTarget(day, newSignature),
      90,
    );

    // Saved and read back.
    final restored = StudyLog.decode(
      merged.addSessionCard(day, 'goal').setPackTarget('neo', 25, day).encode(),
    );
    expect(restored.dayTarget(day, signature), 70);
    expect(restored.sessionDone(day, 'goal'), 1);
    expect(restored.packTarget('neo'), 25);
  });

  test('daily limits are shared and count every session and device', () async {
    final remote = _FakeRemote();
    final phone = device(remote);
    final web = device(remote);
    var now = day;
    final phoneSession = SessionProgressStore(logStore: phone, now: () => now);
    final webSession = SessionProgressStore(logStore: web, now: () => now);

    expect(await phoneSession.dailyLimits(), isNull);
    await phoneSession.setDailyLimits((newCards: 20, reviews: 150));
    await webSession.refresh();
    expect(await webSession.dailyLimits(), (newCards: 20, reviews: 150));

    // 3 new cards and 2 reviews on the phone (a pack or a custom session).
    for (var i = 0; i < 5; i++) {
      await phone.update(
        (log) => log.recordReview(now: now, isNew: i < 3, forgot: false),
      );
    }
    await phone.uploadNow();
    await webSession.refresh();
    expect(await webSession.studiedToday(), (newCards: 3, reviews: 2));

    // The latest choice wins; turning them off is shared too.
    now = now.add(const Duration(minutes: 1));
    await webSession.setDailyLimits(null);
    await phoneSession.refresh();
    expect(await phoneSession.dailyLimits(), isNull);

    final restored = StudyLog.decode(
      const StudyLog().setDailyLimits((newCards: 5, reviews: 0), day).encode(),
    );
    expect(restored.dailyLimits, (newCards: 5, reviews: 0));
  });
}
