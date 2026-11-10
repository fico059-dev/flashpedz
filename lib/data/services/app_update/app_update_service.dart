import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The update an admin announced: users of an older build are told about
/// it when they open the app.
class UpdateNotice {
  /// The version shown to users, e.g. "1.1.3".
  final String version;

  /// The build number of that version (e.g. 158). Apps with a lower build
  /// number see the notice.
  final int build;

  /// What's new, shown in the notice.
  final String message;

  /// The notice can't be put off: the app can't be used until updated.
  final bool required;

  final String? iosUrl;
  final String? androidUrl;

  const UpdateNotice({
    required this.version,
    required this.build,
    required this.message,
    this.required = false,
    this.iosUrl,
    this.androidUrl,
  });

  static UpdateNotice? fromMap(Map<String, dynamic>? data) {
    final build = (data?['build'] as num?)?.toInt();
    if (data == null || build == null || build <= 0) return null;
    String? text(String key) {
      final value = (data[key] as String?)?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    return UpdateNotice(
      version: text('version') ?? '',
      build: build,
      message: text('message') ?? '',
      required: data['required'] == true,
      iosUrl: text('iosUrl'),
      androidUrl: text('androidUrl'),
    );
  }

  Map<String, dynamic> toMap() => {
    'version': version,
    'build': build,
    'message': message,
    'required': required,
    'iosUrl': ?iosUrl,
    'androidUrl': ?androidUrl,
  };
}

/// This app's version and build number.
typedef InstalledVersion = ({String version, int build});

/// Reads and (for admins) saves the update notice, kept in
/// app_config/update.
class AppUpdateService {
  final Future<Map<String, dynamic>?> Function() _read;
  final Future<void> Function(Map<String, dynamic>? data) _write;
  final Future<InstalledVersion> Function() _installed;

  AppUpdateService({
    Future<Map<String, dynamic>?> Function()? read,
    Future<void> Function(Map<String, dynamic>? data)? write,
    Future<InstalledVersion> Function()? installed,
  }) : _read = read ?? _readFirestore,
       _write = write ?? _writeFirestore,
       _installed = installed ?? _packageVersion;

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('app_config').doc('update');

  static Future<Map<String, dynamic>?> _readFirestore() async =>
      (await _doc.get()).data();

  static Future<void> _writeFirestore(Map<String, dynamic>? data) =>
      data == null
      ? _doc.delete()
      : _doc.set({...data, 'updatedAt': FieldValue.serverTimestamp()});

  static Future<InstalledVersion> _packageVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (
      version: info.version,
      build: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  Future<InstalledVersion> installed() => _installed();

  /// The announced update, whether or not this app has it.
  Future<UpdateNotice?> current() async => UpdateNotice.fromMap(await _read());

  /// The announced update if this app is older; null when up to date (or
  /// the build number can't be read).
  Future<UpdateNotice?> check() async {
    final notice = await current();
    if (notice == null) return null;
    final installed = await _installed();
    if (installed.build <= 0 || installed.build >= notice.build) return null;
    return notice;
  }

  Future<void> publish(UpdateNotice notice) => _write(notice.toMap());

  Future<void> turnOff() => _write(null);
}
