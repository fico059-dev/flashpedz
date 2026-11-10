import 'package:flashcards/data/services/app_update/app_update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lets an admin announce a new app version: everyone on an older build
/// sees an "Update available" message when they open the app.
class AppUpdateAdminPage extends StatefulWidget {
  final AppUpdateService? service;

  const AppUpdateAdminPage({super.key, this.service});

  @override
  State<AppUpdateAdminPage> createState() => _AppUpdateAdminPageState();
}

class _AppUpdateAdminPageState extends State<AppUpdateAdminPage> {
  late final _service = widget.service ?? AppUpdateService();
  final _version = TextEditingController();
  final _build = TextEditingController();
  final _message = TextEditingController();
  final _iosUrl = TextEditingController();
  final _androidUrl = TextEditingController();
  var _required = false;
  InstalledVersion? _installed;
  UpdateNotice? _current;
  var _loading = true;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_version, _build, _message, _iosUrl, _androidUrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    InstalledVersion? installed;
    UpdateNotice? current;
    String? error;
    try {
      installed = await _service.installed();
    } catch (_) {}
    try {
      current = await _service.current();
    } catch (e) {
      error = "Couldn't read the current notice. Check your connection.";
    }
    if (!mounted) return;
    setState(() {
      _installed = installed;
      _current = current;
      _error = error;
      _loading = false;
      // This app's version is the usual one to announce (it was just
      // released); the links are kept from the last notice.
      _version.text = installed?.version ?? current?.version ?? '';
      _build.text = '${installed?.build ?? current?.build ?? ''}';
      _message.text = current?.message ?? '';
      _iosUrl.text = current?.iosUrl ?? '';
      _androidUrl.text = current?.androidUrl ?? '';
      _required = false;
    });
  }

  Future<void> _publish() async {
    final build = int.tryParse(_build.text.trim()) ?? 0;
    final ios = _iosUrl.text.trim();
    if (build <= 0) {
      setState(() => _error = 'Enter the build number, e.g. 158.');
      return;
    }
    if (ios.isNotEmpty &&
        !ios.startsWith('https://apps.apple.com/') &&
        !ios.startsWith('itms-apps://')) {
      setState(
        () => _error =
            'The App Store link should start with '
            'https://apps.apple.com/',
      );
      return;
    }
    final notice = UpdateNotice(
      version: _version.text.trim(),
      build: build,
      message: _message.text.trim(),
      required: _required,
      iosUrl: ios.isEmpty ? null : ios,
      androidUrl: _androidUrl.text.trim().isEmpty
          ? null
          : _androidUrl.text.trim(),
    );
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish the update notice?'),
        content: Text(
          'Everyone using a build older than $build will see '
          '"Update available"${notice.version.isEmpty ? '' : ' (FlashPedz ${notice.version})'} '
          'when they open the app.'
          '${notice.required ? ' They must update to keep using it.' : ''}'
          '${ios.isEmpty ? '\n\nThere is no App Store link, so iPhone users '
                    'will be told to update from the App Store.' : ''}'
          '\n\nOnly publish once the version is live on the App Store.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    await _save(() => _service.publish(notice), 'Update notice published.');
    if (mounted) setState(() => _current = notice);
  }

  Future<void> _turnOff() async {
    await _save(_service.turnOff, 'Update notice turned off.');
    if (mounted) setState(() => _current = null);
  }

  Future<void> _save(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (_) {
      if (mounted) {
        setState(() => _error = "Couldn't save. Check your connection.");
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final installed = _installed;
    final current = _current;
    return Scaffold(
      appBar: AppBar(title: const Text('App update notice')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 14,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 6,
                            children: [
                              Text(
                                current == null
                                    ? 'No update notice is on.'
                                    : 'On: users older than build '
                                          '${current.build} see '
                                          '"FlashPedz ${current.version}"'
                                          '${current.required ? ' (must update)' : ''}.',
                                style: theme.textTheme.titleSmall,
                              ),
                              if (installed != null)
                                Text(
                                  'This app: ${installed.version} '
                                  '(build ${installed.build})',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        spacing: 12,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _version,
                              decoration: const InputDecoration(
                                labelText: 'Version',
                                hintText: '1.1.3',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _build,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Build number',
                                hintText: '158',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _message,
                        minLines: 3,
                        maxLines: 8,
                        maxLength: 500,
                        decoration: const InputDecoration(
                          labelText: "What's new (shown to users)",
                          hintText:
                              'Faster exams, a live score while studying…',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      TextField(
                        controller: _iosUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'App Store link',
                          hintText: 'https://apps.apple.com/app/id…',
                          helperText:
                              'App Store Connect → your app → App Information '
                              '→ "View on App Store", copy that link.',
                          helperMaxLines: 2,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        controller: _androidUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Google Play link (optional)',
                          helperText:
                              'Empty: the FlashPedz page on Google Play.',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Users must update'),
                        subtitle: const Text(
                          'No "Later": the app can\'t be used until updated. '
                          'Only for updates that are really needed.',
                        ),
                        value: _required,
                        onChanged: (value) => setState(() => _required = value),
                      ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      FilledButton.icon(
                        onPressed: _saving ? null : _publish,
                        icon: const Icon(Icons.campaign_outlined),
                        label: const Text('Publish update notice'),
                      ),
                      OutlinedButton(
                        onPressed: _saving || current == null ? null : _turnOff,
                        child: const Text('Turn off notice'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
