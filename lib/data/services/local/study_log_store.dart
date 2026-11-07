import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flashcards/data/services/api/users/auth_service.dart';
import 'package:flashcards/domain/models/progress/study_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the study history of all the user's devices is kept online.
abstract class StudyLogRemote {
  Future<({Map<String, String> devices, String? goal})> fetch();

  Future<void> save({
    required String deviceId,
    required String log,
    String? goal,
  });
}

/// Keeps each user's [StudyLog] on the device and copies it online, so the
/// Progress tab shows the same history on the phone and on the website.
///
/// Every device stores its own log online and they are added up when read,
/// so reviews are never counted twice.
class StudyLogStore {
  static const _deviceIdKey = 'study_log_device_id';

  /// Reviews are uploaded together a little while after the last one, soon
  /// enough for another device opened next to see them.
  static const uploadDelay = Duration(seconds: 5);

  /// The online copy is read again after this long.
  static const _remoteCacheDuration = Duration(minutes: 2);

  final AuthService _authService;
  final SharedPreferencesAsync _prefs;
  final StudyLogRemote? _remote;

  // Reviews can be saved quickly one after another, so writes are chained to
  // keep them from overwriting each other.
  Future<void> _pending = Future.value();

  Timer? _uploadTimer;
  String? _deviceId;
  (DateTime, String, ({Map<String, String> devices, String? goal}))?
  _remoteCache;

  StudyLogStore({
    required AuthService authService,
    SharedPreferencesAsync? prefs,
    StudyLogRemote? remote,
  }) : _authService = authService,
       _prefs = prefs ?? SharedPreferencesAsync(),
       _remote = remote;

  String? get _uid => _authService.getCurrentUser()?.uid;

  String? get _key {
    final uid = _uid;
    return uid == null ? null : 'study_log_$uid';
  }

  /// What this device recorded.
  Future<StudyLog> load() async {
    await _pending;
    return _readLocal();
  }

  /// This device's history added to what the user's other devices saved
  /// online. Falls back to this device only when offline.
  ///
  /// With [fresh] the online copy is read again now (waiting at most
  /// [timeout]), e.g. when a session starts, to continue where another
  /// device stopped.
  Future<StudyLog> loadCombined({
    bool fresh = false,
    Duration timeout = const Duration(seconds: 10),

    /// With [fresh]: the other devices' copy read this recently is used
    /// as it is (no waiting for the server).
    Duration? freshEnough,
  }) async {
    // Recent reviews go online in the background: this device's own
    // counts come from here, so nothing waits for the upload.
    if (_uploadTimer?.isActive ?? false) unawaited(uploadNow());
    final local = await load();
    final uid = _uid;
    if (_remote == null || uid == null) return local;

    final cache = _remoteCache;
    if (fresh &&
        !(freshEnough != null &&
            cache != null &&
            DateTime.now().difference(cache.$1) < freshEnough)) {
      _remoteCache = null;
    }
    final remote = await _fetchRemote(uid, timeout);
    if (remote == null) return local;

    final deviceId = await _getDeviceId();
    final others = [
      for (final entry in remote.devices.entries)
        if (entry.key != deviceId) StudyLog.decode(entry.value),
    ];
    final goalJson = remote.goal;
    StudyGoal? goal;
    if (goalJson != null) {
      try {
        goal = StudyGoal.fromJson(jsonDecode(goalJson) as Map<String, dynamic>);
      } on Object {
        goal = null;
      }
    }
    return StudyLog.merge([local, ...others], goal: goal ?? local.goal);
  }

  /// Applies [change] to the stored log and returns the new log.
  Future<StudyLog> update(StudyLog Function(StudyLog log) change) {
    final result = _pending.then((_) async {
      final key = _key;
      if (key == null) return const StudyLog();
      final updated = change(await _readLocal());
      try {
        await _prefs.setString(key, updated.encode());
      } on Object {
        // Progress history is a nice to have, never block studying for it.
      }
      _scheduleUpload();
      return updated;
    });
    _pending = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Saves the goal here and online straight away.
  Future<StudyLog> saveGoal(StudyGoal goal) async {
    final updated = await update((log) => log.setGoal(goal, DateTime.now()));
    await uploadNow(goal: updated.goal);
    return loadCombined();
  }

  /// Sends this device's history online now instead of waiting.
  Future<void> uploadNow({StudyGoal? goal}) async {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    final remote = _remote;
    final uid = _uid;
    if (remote == null || uid == null) return;
    try {
      final log = await load();
      await remote.save(
        deviceId: await _getDeviceId(),
        log: log.encode(),
        goal: goal == null ? null : jsonEncode(goal.toJson()),
      );
      _remoteCache = null;
    } on Object {
      // Tried again after the next review.
    }
  }

  void _scheduleUpload() {
    if (_remote == null) return;
    _uploadTimer?.cancel();
    _uploadTimer = Timer(uploadDelay, uploadNow);
  }

  Future<StudyLog> _readLocal() async {
    final key = _key;
    if (key == null) return const StudyLog();
    try {
      return StudyLog.decode(await _prefs.getString(key));
    } on Object {
      return const StudyLog();
    }
  }

  Future<({Map<String, String> devices, String? goal})?> _fetchRemote(
    String uid,
    Duration timeout,
  ) async {
    final cache = _remoteCache;
    if (cache != null &&
        cache.$2 == uid &&
        DateTime.now().difference(cache.$1) < _remoteCacheDuration) {
      return cache.$3;
    }
    try {
      final remote = await _remote!.fetch().timeout(timeout);
      _remoteCache = (DateTime.now(), uid, remote);
      return remote;
    } on Object {
      return null;
    }
  }

  Future<String> _getDeviceId() async {
    final known = _deviceId;
    if (known != null) return known;
    String? id;
    try {
      id = await _prefs.getString(_deviceIdKey);
    } on Object {
      id = null;
    }
    if (id == null || id.length < 6) {
      final random = Random.secure();
      const chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      id = List.generate(20, (_) => chars[random.nextInt(chars.length)]).join();
      try {
        await _prefs.setString(_deviceIdKey, id);
      } on Object {
        // Without storage the id lasts until the app is closed.
      }
    }
    return _deviceId = id;
  }
}

/// [StudyLogRemote] using the saveStudyLog / getStudyLog functions.
class CloudStudyLogRemote implements StudyLogRemote {
  final Future<({Map<String, String> devices, String? goal})> Function() _get;
  final Future<void> Function({
    required String deviceId,
    required String log,
    String? goal,
  })
  _save;

  CloudStudyLogRemote({
    required Future<({Map<String, String> devices, String? goal})> Function()
    get,
    required Future<void> Function({
      required String deviceId,
      required String log,
      String? goal,
    })
    save,
  }) : _get = get,
       _save = save;

  @override
  Future<({Map<String, String> devices, String? goal})> fetch() => _get();

  @override
  Future<void> save({
    required String deviceId,
    required String log,
    String? goal,
  }) => _save(deviceId: deviceId, log: log, goal: goal);
}
