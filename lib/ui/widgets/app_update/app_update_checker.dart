import 'package:flashcards/data/services/app_update/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Tells the student when a newer version of the app is out (announced by
/// an admin): when the app opens, and when it comes back after a while.
class AppUpdateChecker extends StatefulWidget {
  final Widget child;
  final AppUpdateService? service;
  final SharedPreferencesAsync? prefs;

  /// Opens the store page (or reloads the website); replaced in tests.
  final Future<void> Function(UpdateNotice notice)? onUpdate;

  const AppUpdateChecker({
    super.key,
    required this.child,
    this.service,
    this.prefs,
    this.onUpdate,
  });

  /// After "Later", the notice comes back after this long.
  static const remindAfter = Duration(days: 3);

  /// Checked again when the app comes back after this long.
  static const checkEvery = Duration(hours: 1);

  @override
  State<AppUpdateChecker> createState() => _AppUpdateCheckerState();
}

class _AppUpdateCheckerState extends State<AppUpdateChecker>
    with WidgetsBindingObserver {
  late final _service = widget.service ?? AppUpdateService();
  SharedPreferencesAsync? _prefsInstance;
  SharedPreferencesAsync get _prefs =>
      widget.prefs ?? (_prefsInstance ??= SharedPreferencesAsync());
  DateTime? _checkedAt;
  var _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final checkedAt = _checkedAt;
    if (state == AppLifecycleState.resumed &&
        (checkedAt == null ||
            DateTime.now().difference(checkedAt) >
                AppUpdateChecker.checkEvery)) {
      _check();
    }
  }

  String _laterKey(int build) => 'update_later_$build';
  String _reloadedKey(int build) => 'update_reloaded_$build';

  Future<void> _check() async {
    if (_showing) return;
    _checkedAt = DateTime.now();
    UpdateNotice? notice;
    try {
      notice = await _service.check();
    } catch (_) {
      return; // Offline: next time.
    }
    if (notice == null || !mounted) return;
    try {
      // The website already reloaded for this version (it isn't deployed
      // yet): don't ask again.
      if (kIsWeb && await _prefs.getBool(_reloadedKey(notice.build)) == true) {
        return;
      }
      final later = await _prefs.getInt(_laterKey(notice.build));
      if (!notice.required &&
          later != null &&
          DateTime.now().difference(
                DateTime.fromMillisecondsSinceEpoch(later),
              ) <
              AppUpdateChecker.remindAfter) {
        return;
      }
    } catch (_) {
      // Storage unavailable: show it.
    }
    if (!mounted) return;
    _showing = true;
    final choice = await showAppUpdateDialog(
      context,
      notice,
      onUpdate: widget.onUpdate ?? _openUpdate,
    );
    _showing = false;
    if (choice == _Choice.later) {
      try {
        await _prefs.setInt(
          _laterKey(notice.build),
          DateTime.now().millisecondsSinceEpoch,
        );
      } catch (_) {}
    }
  }

  Future<void> _openUpdate(UpdateNotice notice) async {
    if (kIsWeb) {
      try {
        await _prefs.setBool(_reloadedKey(notice.build), true);
      } catch (_) {}
      await launchUrl(Uri.base, webOnlyWindowName: '_self');
      return;
    }
    final url = storeUrl(notice);
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.stz.flashcards';

/// Where this device gets the update; null when there's no link for it.
String? storeUrl(UpdateNotice notice) => switch (defaultTargetPlatform) {
  TargetPlatform.android => notice.androidUrl ?? _playStoreUrl,
  TargetPlatform.iOS || TargetPlatform.macOS => notice.iosUrl,
  _ => null,
};

enum _Choice { later, update }

/// The "new version" message. Without [UpdateNotice.required] it can be put
/// off with Later; otherwise it stays until the app is updated.
Future<_Choice?> showAppUpdateDialog(
  BuildContext context,
  UpdateNotice notice, {
  required Future<void> Function(UpdateNotice notice) onUpdate,
}) {
  return showDialog<_Choice>(
    context: context,
    barrierDismissible: !notice.required,
    builder: (context) => PopScope(
      canPop: !notice.required,
      child: AppUpdateDialog(notice: notice, onUpdate: onUpdate),
    ),
  );
}

class AppUpdateDialog extends StatelessWidget {
  final UpdateNotice notice;
  final Future<void> Function(UpdateNotice notice) onUpdate;

  const AppUpdateDialog({
    super.key,
    required this.notice,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canOpen = kIsWeb || storeUrl(notice) != null;
    final name = notice.version.isEmpty
        ? 'A new version of FlashPedz'
        : 'FlashPedz ${notice.version}';
    return AlertDialog(
      icon: Icon(
        Icons.system_update,
        size: 40,
        color: theme.colorScheme.primary,
      ),
      title: const Text('Update available'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kIsWeb
                  ? '$name is out. Reload the page to get it.'
                  : notice.required
                  ? '$name is out. Please update to keep using the app.'
                  : '$name is out.',
              style: theme.textTheme.bodyLarge,
            ),
            if (notice.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text("What's new", style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(notice.message),
            ],
            if (!canOpen) ...[
              const SizedBox(height: 12),
              const Text('Update it from your app store.'),
            ],
          ],
        ),
      ),
      actions: [
        if (!notice.required)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_Choice.later),
            child: const Text('Later'),
          ),
        if (canOpen)
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await onUpdate(notice);
              // A required update stays until the new version is installed.
              if (!notice.required && navigator.mounted) {
                navigator.pop(_Choice.update);
              }
            },
            child: Text(kIsWeb ? 'Reload' : 'Update'),
          ),
      ],
    );
  }
}
