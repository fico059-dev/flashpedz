// Renders the OSCE gym to PNG files:
// flutter test test/screens/osce_gym_screens_test.dart
@Tags(['screens'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flashcards/domain/models/progress/osce_progress.dart';
import 'package:flashcards/ui/theme/themes.dart';
import 'package:flashcards/ui/widgets/progress/osce_arms.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File(
      '${Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter'}'
      '/bin/cache/artifacts/material_fonts/$file',
    ).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

OsceProgressStats _stats() {
  final start = DateTime(2026, 9, 1);
  final scores = [30, 42, 55, 48, 61, 70, 66, 78, 52, 81, 90, 74, 85, 95];
  return OsceProgressStats(
    stationsTotal: 10,
    stations: [
      for (var s = 0; s < 3; s++)
        OsceStationStat(
          osceId: 's$s',
          name: ['Chest pain', 'Neonatal resus', 'Breaking bad news'][s],
          attempts: [
            for (var i = s; i < scores.length; i += 3)
              OsceAttemptPoint(
                start.add(Duration(days: i)),
                scores[i].toDouble(),
              ),
          ],
        ),
    ],
    untriedStations: const [],
    allAttempts: const [],
    targetScore: 80,
    weakAreas: const [],
    missedChecks: const [],
    advice: const [],
  );
}

void main() {
  test('arm strength follows the score', () {
    expect(armLevel(49.9), ArmLevel.skinny);
    expect(armLevel(50), ArmLevel.moderate);
    expect(armLevel(74), ArmLevel.moderate);
    expect(armLevel(75), ArmLevel.strong);
    final sessions = osceSessions(_stats());
    expect(sessions, hasLength(14));
    expect(sessions.first.percent, 30);
    expect(sessions.last.percent, 95);
  });

  for (final grid in [false, true]) {
    testWidgets('osce gym ${grid ? 'grid' : 'arms'}', (tester) async {
      await tester.runAsync(() async {
        await _loadFont('Roboto', [
          'Roboto-Regular.ttf',
          'Roboto-Medium.ttf',
          'Roboto-Bold.ttf',
        ]);
        await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
      });
      tester.view.physicalSize = const Size(390 * 2, 420 * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lightThemeData,
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: OsceGymCard(stats: _stats()),
              ),
            ),
          ),
        ),
      );
      if (grid) {
        await tester.tap(find.byIcon(Icons.grid_view));
        await tester.pumpAndSettle();
      }
      expect(find.text('Your OSCE gym'), findsOneWidget);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('build/screens')..createSync(recursive: true);
        File(
          '${dir.path}/osce_gym_${grid ? 'grid' : 'arms'}.png',
        ).writeAsBytesSync(data!.buffer.asUint8List());
      });
    });
  }

  testWidgets('the OSCE tab shows the latest arms; tap opens the gym', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightThemeData,
        home: Scaffold(body: OsceGymStrip(load: () async => _stats())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your OSCE gym'), findsOneWidget);
    // The latest 8 of 14 sessions.
    expect(
      find.descendant(
        of: find.byType(OsceGymStrip),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ArmPainter,
        ),
      ),
      findsNWidgets(8),
    );
    await tester.tap(find.text('Your OSCE gym'));
    await tester.pumpAndSettle();
    expect(find.text('Each arm is one OSCE session'), findsOneWidget);
  });
}
