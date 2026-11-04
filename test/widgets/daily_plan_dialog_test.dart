import 'package:flashcards/data/services/local/session_progress_store.dart';
import 'package:flashcards/data/services/local/study_log_store.dart';
import 'package:flashcards/ui/dialogs/flashcard/daily_limits_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../notebook_test.dart' show FakeAuth;

class _MemoryPrefs implements SharedPreferencesAsync {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('total cards a day, how many new, and the goal suggestion', (
    tester,
  ) async {
    final prefs = _MemoryPrefs();
    final store = SessionProgressStore(
      prefs: prefs,
      logStore: StudyLogStore(authService: FakeAuth(), prefs: prefs),
    );
    await tester.pumpWidget(
      Provider.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDailyPlanDialog(context, goalPerDay: 70),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Daily plan'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '120');
    await tester.pump();
    expect(find.text('20 new + 100 reviews = 120 cards'), findsOneWidget);

    // The exam goal's number of new cards.
    await tester.tap(find.text('Use'));
    await tester.pump();
    expect(find.text('70 new + 50 reviews = 120 cards'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    expect(await tester.runAsync(store.dailyLimits), (
      newCards: 70,
      reviews: 50,
    ));
  });
}
