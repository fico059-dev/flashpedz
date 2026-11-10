import 'package:flashcards/data/services/app_update/app_update_service.dart';
import 'package:flashcards/ui/pages/profile/admin_dashboard/app_update_admin_page.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'package:flashcards/ui/widgets/app_update/app_update_checker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryPrefs implements SharedPreferencesAsync {
  final values = <String, Object>{};

  @override
  Future<int?> getInt(String key) async => values[key] as int?;
  @override
  Future<void> setInt(String key, int value) async => values[key] = value;
  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The notice in the database, and this app's build.
class _Backend {
  Map<String, dynamic>? doc;
  int installedBuild;
  final writes = <Map<String, dynamic>?>[];

  _Backend({this.doc, this.installedBuild = 157});

  AppUpdateService service() => AppUpdateService(
    read: () async => doc,
    write: (data) async {
      writes.add(data);
      doc = data;
    },
    installed: () async => (version: '1.1.2', build: installedBuild),
  );
}

const _notice = {
  'version': '1.1.3',
  'build': 158,
  'message': 'Faster exams and a live score.',
  'iosUrl': 'https://apps.apple.com/app/id123',
};

void main() {
  test('only older builds are told about the update', () async {
    final backend = _Backend(doc: Map.of(_notice));
    expect((await backend.service().check())?.version, '1.1.3');

    backend.installedBuild = 158;
    expect(await backend.service().check(), isNull);
    backend.installedBuild = 160;
    expect(await backend.service().check(), isNull);
    // Build number unknown: not bothered.
    backend.installedBuild = 0;
    expect(await backend.service().check(), isNull);
    // Turned off.
    backend
      ..installedBuild = 100
      ..doc = null;
    expect(await backend.service().check(), isNull);
  });

  Future<List<UpdateNotice>> open(
    WidgetTester tester,
    _Backend backend,
    _MemoryPrefs prefs,
  ) async {
    final opened = <UpdateNotice>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: lightThemeData,
        home: AppUpdateChecker(
          service: backend.service(),
          prefs: prefs,
          onUpdate: (notice) async => opened.add(notice),
          child: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('Update opens the store; Later waits a few days', (tester) async {
    final backend = _Backend(doc: Map.of(_notice));
    final prefs = _MemoryPrefs();
    var opened = await open(tester, backend, prefs);
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('FlashPedz 1.1.3 is out.'), findsOneWidget);
    expect(find.text('Faster exams and a live score.'), findsOneWidget);

    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(opened.single.build, 158);
    expect(find.text('Update available'), findsNothing);

    // Opening the app again (still not updated): asked again.
    await tester.pumpWidget(const SizedBox());
    opened = await open(tester, backend, prefs);
    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(prefs.values.keys, contains('update_later_158'));

    // Not again right after Later.
    await tester.pumpWidget(const SizedBox());
    await open(tester, backend, prefs);
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('a required update has no Later and stays', (tester) async {
    final backend = _Backend(doc: {..._notice, 'required': true});
    final prefs = _MemoryPrefs();
    final opened = await open(tester, backend, prefs);
    expect(find.text('Later'), findsNothing);
    expect(find.textContaining('Please update to keep using'), findsOneWidget);

    await tester.tapAt(const Offset(5, 5)); // Outside the dialog.
    await tester.pumpAndSettle();
    expect(find.text('Update available'), findsOneWidget);
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(opened, hasLength(1));
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets('up to date: nothing shown', (tester) async {
    final backend = _Backend(doc: Map.of(_notice), installedBuild: 158);
    await open(tester, backend, _MemoryPrefs());
    expect(find.text('Update available'), findsNothing);
  });

  testWidgets('admin publishes and turns off the notice', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = _Backend(installedBuild: 158);
    await tester.pumpWidget(
      MaterialApp(
        theme: lightThemeData,
        home: AppUpdateAdminPage(service: backend.service()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No update notice is on.'), findsOneWidget);
    // This app's version is filled in.
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Build number'))
          .controller!
          .text,
      '158',
    );

    await tester.enterText(
      find.widgetWithText(TextField, "What's new (shown to users)"),
      'Live score while studying.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'App Store link'),
      'https://apps.apple.com/app/id123',
    );
    await tester.tap(find.text('Publish update notice'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish'));
    await tester.pumpAndSettle();
    expect(backend.writes.single, {
      'version': '1.1.2',
      'build': 158,
      'message': 'Live score while studying.',
      'required': false,
      'iosUrl': 'https://apps.apple.com/app/id123',
    });
    expect(
      find.textContaining('On: users older than build 158'),
      findsOneWidget,
    );

    await tester.tap(find.text('Turn off notice'));
    await tester.pumpAndSettle();
    expect(backend.writes.last, isNull);
    expect(find.text('No update notice is on.'), findsOneWidget);
  });

  testWidgets('a wrong App Store link is caught', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final backend = _Backend(installedBuild: 158);
    await tester.pumpWidget(
      MaterialApp(home: AppUpdateAdminPage(service: backend.service())),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'App Store link'),
      'flashpedz app',
    );
    await tester.tap(find.text('Publish update notice'));
    await tester.pumpAndSettle();
    expect(find.textContaining('should start with'), findsOneWidget);
    expect(backend.writes, isEmpty);
  });
}
