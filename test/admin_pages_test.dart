import 'dart:convert';
import 'dart:io';

import 'package:flashcards/bloc/flashcards/anki_import/anki_import_cubit.dart';
import 'package:flashcards/bloc/profile/profile_reader/profile_reader_cubit.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/pack_repository.dart';
import 'package:flashcards/data/repositories/users/profile_repository.dart';
import 'package:flashcards/data/repositories/users/user_roles_repository.dart';
import 'package:flashcards/data/services/anki/anki_import_models.dart';
import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/domain/models/profile/admin_user/admin_user.dart';
import 'package:flashcards/l10n/app_localizations.dart';
import 'package:flashcards/ui/dialogs/profile/admin_dashboard/flashcard_builder/pack_premium_dialog.dart';
import 'package:flashcards/ui/pages/profile/admin_dashboard/assign_admin_page.dart';
import 'package:flashcards/ui/pages/profile/admin_dashboard/flashcard_builder/anki_import_page.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFlashcardRepository implements FlashcardRepository {
  List<AnkiCard>? importedCards;

  @override
  Future<FlashcardImportSummary> importFlashcardsToPack({
    required String packId,
    required List<AnkiCard> cards,
    required bool importTags,
    required void Function(int processed, int total) onProgress,
    Tag? topic,
  }) async {
    importedCards = cards;
    onProgress(cards.length, cards.length);
    return FlashcardImportSummary(
      imported: cards.length - 1,
      skippedDuplicates: 1,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserRolesRepository implements UserRolesRepository {
  final removed = <String>[];

  @override
  Future<Result<List<AdminUser>>> getAdmins() async => Result.ok(const [
    AdminUser(uid: 'a', email: 'first@flashpedz.com', displayName: 'First'),
    AdminUser(uid: 'b', email: 'second@flashpedz.com'),
  ]);

  @override
  Future<Result<void>> removeAdminRole(String uid) async {
    removed.add(uid);
    return Result.ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePackRepository implements PackRepository {
  final calls = <(String, bool)>[];

  @override
  Future<Result<void>> setPackPremium(String packId, bool isPaid) async {
    calls.add((packId, isPaid));
    return Result.ok(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child, List<RepositoryProvider> providers) {
  return MultiRepositoryProvider(
    providers: providers,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  const pack = AdminPack(
    packId: 'pack1',
    packName: 'Cardiology',
    flashcardsCount: 3,
    isPaid: false,
    tagCounts: {},
  );

  setUp(() {
    // path_provider has no implementation in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );

    // Phone sized screen.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  testWidgets('Anki import: instructions, preview, import, done', (
    tester,
  ) async {
    final repo = _FakeFlashcardRepository();
    await tester.pumpWidget(
      _app(const AnkiImportPage(pack: pack), [
        RepositoryProvider<FlashcardRepository>.value(value: repo),
      ]),
    );

    expect(find.text('Import from Anki'), findsOneWidget);
    expect(find.text('Choose Anki file'), findsOneWidget);

    final cubit = BlocProvider.of<AnkiImportCubit>(
      tester.element(find.text('Choose Anki file')),
    );
    await tester.runAsync(
      () => cubit.readFile(
        fileName: 'deck.txt',
        bytes: utf8.encode(
          '#separator:tab\n#tags column:3\n'
          'What is the most common arrhythmia?\tAtrial fibrillation\tCardio::AF\n'
          '{{c1::Digoxin}} slows {{c2::AV node}} conduction\t\t\n',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('deck.txt'), findsOneWidget);
    expect(find.text('Cards to import'), findsOneWidget);
    expect(find.text('Import Anki tags'), findsOneWidget);
    expect(find.text('What is the most common arrhythmia?'), findsOneWidget);
    expect(find.text('{Digoxin} slows AV node conduction'), findsOneWidget);

    await tester.tap(find.text('Import 3 cards into "Cardiology"'));
    await tester.pumpAndSettle();

    expect(repo.importedCards, hasLength(3));
    expect(find.text('Import complete'), findsOneWidget);
    expect(find.text('2 cards were added to "Cardiology".'), findsOneWidget);
    expect(
      find.text('1 cards were already in the pack with no changes.'),
      findsOneWidget,
    );
  });

  testWidgets('Anki import shows a readable error for bad files', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const AnkiImportPage(pack: pack), [
        RepositoryProvider<FlashcardRepository>.value(
          value: _FakeFlashcardRepository(),
        ),
      ]),
    );
    final cubit = BlocProvider.of<AnkiImportCubit>(
      tester.element(find.text('Choose Anki file')),
    );
    await tester.runAsync(
      () => cubit.readFile(
        fileName: 'deck.apkg',
        path: (File(
          '${Directory.systemTemp.path}/bad_deck.apkg',
        )..writeAsStringSync('nope')).path,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("This file couldn't be imported"), findsOneWidget);
    expect(
      find.text("This file isn't a valid Anki package (.apkg)."),
      findsOneWidget,
    );
  });

  testWidgets('Assign admin page lists admins and removes one', (tester) async {
    final rolesRepo = _FakeUserRolesRepository();
    await tester.pumpWidget(
      BlocProvider(
        create: (_) =>
            ProfileReaderCubit(profileRepo: _FakeProfileRepository()),
        child: _app(const Scaffold(body: AssignAdminPage()), [
          RepositoryProvider<UserRolesRepository>.value(value: rolesRepo),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current admins (2)'), findsOneWidget);
    expect(find.text('first@flashpedz.com'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove admin').last);
    await tester.pumpAndSettle();
    expect(find.text('Remove admin?'), findsOneWidget);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(rolesRepo.removed, ['b']);
    expect(find.text('Current admins (1)'), findsOneWidget);
    expect(
      find.text('second@flashpedz.com is no longer an admin'),
      findsOneWidget,
    );
  });

  testWidgets('Premium switch asks for confirmation and updates the pack', (
    tester,
  ) async {
    final packRepo = _FakePackRepository();
    bool? result;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => PackPremiumTile(
              isPaid: false,
              onTap: () async =>
                  result = await showChangePackPremiumDialog(context, pack),
            ),
          ),
        ),
        [RepositoryProvider<PackRepository>.value(value: packRepo)],
      ),
    );

    expect(find.text('Free for everyone'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Make pack Premium?'), findsOneWidget);

    await tester.tap(find.text('Make Premium'));
    await tester.pumpAndSettle();

    expect(packRepo.calls, [('pack1', true)]);
    expect(result, isTrue);
    expect(find.text('"Cardiology" is now Premium'), findsOneWidget);
  });
}
