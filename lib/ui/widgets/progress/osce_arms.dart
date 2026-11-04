import 'dart:math';

import 'package:flashcards/domain/models/progress/osce_progress.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/progress/progress_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// How strong an OSCE session was.
enum ArmLevel { skinny, moderate, strong }

/// Below 50% skinny, 50–74% moderate, 75% and more very muscular.
ArmLevel armLevel(double percent) => percent >= 75
    ? ArmLevel.strong
    : percent >= 50
    ? ArmLevel.moderate
    : ArmLevel.skinny;

/// Colors for the grid (and the sleeves of the arms).
Color armColor(ArmLevel level) => switch (level) {
  ArmLevel.skinny => const Color(0xFFE57373),
  ArmLevel.moderate => const Color(0xFFFFB74D),
  ArmLevel.strong => const Color(0xFF43A047),
};

/// One finished OSCE station.
class OsceSession {
  final String name;
  final DateTime date;
  final double percent;

  const OsceSession(this.name, this.date, this.percent);

  ArmLevel get level => armLevel(percent);
}

/// Every attempt of every station, oldest first.
List<OsceSession> osceSessions(OsceProgressStats stats) => [
  for (final station in stats.stations)
    for (final attempt in station.attempts)
      OsceSession(station.name, attempt.date, attempt.percent),
]..sort((a, b) => a.date.compareTo(b.date));

/// The latest OSCE sessions as small arms, at the top of the OSCE tab.
/// Tapping it opens the whole gym.
class OsceGymStrip extends StatefulWidget {
  /// Loads the OSCE results; null leaves the strip out.
  final Future<OsceProgressStats?> Function() load;

  const OsceGymStrip({super.key, required this.load});

  @override
  State<OsceGymStrip> createState() => _OsceGymStripState();
}

class _OsceGymStripState extends State<OsceGymStrip> {
  OsceProgressStats? _stats;

  @override
  void initState() {
    super.initState();
    widget
        .load()
        .then((stats) {
          if (mounted) setState(() => _stats = stats);
        })
        .catchError((Object _) {});
  }

  void _openGym(OsceProgressStats stats) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: OsceGymCard(stats: stats),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();
    final sessions = osceSessions(stats);
    final latest = sessions.reversed.take(8).toList().reversed.toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFFE3F0FB),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openGym(stats),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              const Icon(Icons.fitness_center, color: Color(0xFF1E3A5F)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your OSCE gym',
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E3A5F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (latest.isEmpty)
                      Text(
                        'Finish a station to grow your first arm.',
                        style: context.text.bodySmall?.copyWith(
                          color: const Color(0xFF1E3A5F),
                        ),
                      )
                    else
                      SizedBox(
                        height: 40,
                        child: Row(
                          children: [
                            for (final session in latest)
                              SizedBox.square(
                                dimension: 40,
                                child: CustomPaint(
                                  painter: ArmPainter(session.level),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF1E3A5F)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The OSCE gym: an arm per OSCE session, stronger with better scores, or
/// colored squares.
class OsceGymCard extends StatefulWidget {
  final OsceProgressStats stats;

  const OsceGymCard({super.key, required this.stats});

  @override
  State<OsceGymCard> createState() => _OsceGymCardState();
}

class _OsceGymCardState extends State<OsceGymCard> {
  bool _grid = false;

  @override
  Widget build(BuildContext context) {
    final sessions = osceSessions(widget.stats);
    int count(ArmLevel level) => sessions.where((s) => s.level == level).length;

    return ProgressSectionCard(
      title: 'Your OSCE gym',
      subtitle: 'Each ${_grid ? 'square' : 'arm'} is one OSCE session',
      icon: Icons.fitness_center,
      trailing: SegmentedButton<bool>(
        showSelectedIcon: false,
        // Narrow, to fit next to the title on small phones.
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 4)),
        ),
        segments: const [
          ButtonSegment(
            value: false,
            icon: Icon(Icons.fitness_center, size: 18),
            tooltip: 'Arms',
          ),
          ButtonSegment(
            value: true,
            icon: Icon(Icons.grid_view, size: 18),
            tooltip: 'Grid',
          ),
        ],
        selected: {_grid},
        onSelectionChanged: (value) => setState(() => _grid = value.first),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Finish an OSCE station to grow your first arm.'),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _grid
                    ? context.colors.surfaceContainerHighest.withValues(
                        alpha: 0.5,
                      )
                    : const Color(0xFFE3F0FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: _grid ? 3 : 0,
                runSpacing: _grid ? 3 : 0,
                children: [
                  for (final session in sessions)
                    Tooltip(
                      message:
                          '${session.name}\n${session.percent.round()}% · '
                          '${DateFormat('d MMM').format(session.date)}',
                      triggerMode: TooltipTriggerMode.tap,
                      child: _grid
                          ? Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: armColor(session.level),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                          : SizedBox.square(
                              dimension: 56,
                              child: CustomPaint(
                                painter: ArmPainter(session.level),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final (level, label) in [
                (ArmLevel.skinny, _grid ? 'Below 50%' : 'Skinny: below 50%'),
                (ArmLevel.moderate, _grid ? '50–74%' : 'Muscular: 50–74%'),
                (ArmLevel.strong, _grid ? '75% +' : 'Very muscular: 75% +'),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: armColor(level),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '$label (${count(level)})',
                        style: context.text.labelMedium,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A flexed arm: thin with no biceps when skinny, a round biceps when
/// muscular, and a big biceps with power lines when very muscular. The
/// sleeve has the level's color. The hand holds a dumbbell, heavier for a
/// stronger arm.
class ArmPainter extends CustomPainter {
  final ArmLevel level;

  ArmPainter(this.level);

  static const _skin = Color(0xFFF1C27D);
  static const _shade = Color(0xFFE0A96D);
  static const _outline = Color(0xFF9C6B3E);

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);

    final (thick, bulge) = switch (level) {
      ArmLevel.skinny => (0.085, 0.0),
      ArmLevel.moderate => (0.13, 0.15),
      ArmLevel.strong => (0.165, 0.25),
    };
    final t = thick * s;
    final shoulder = Offset(0.14 * s, 0.78 * s);
    final elbow = Offset(0.66 * s, 0.76 * s);
    // A skinny arm can't quite flex.
    final fist = level == ArmLevel.skinny
        ? Offset(0.7 * s, 0.34 * s)
        : Offset(0.64 * s, 0.26 * s);
    final bicepCenter = Offset(0.4 * s, 0.76 * s - t * 0.45);
    final bicep = Rect.fromCenter(
      center: bicepCenter,
      width: 0.36 * s,
      height: bulge * s * 2,
    );

    void limbs(Paint paint, double extra) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(shoulder, elbow, paint..strokeWidth = t + extra);
      canvas.drawLine(elbow, fist, paint..strokeWidth = t * 0.9 + extra);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(fist, t * 0.75 + extra / 2, paint);
      if (bulge > 0) canvas.drawOval(bicep.inflate(extra / 2), paint);
    }

    // The dumbbell first, so the hand closes over its bar.
    _dumbbell(canvas, fist, s);

    // Outline first, then the skin on top, so the parts look joined.
    limbs(Paint()..color = _outline, max(2.0, s * 0.05));
    limbs(Paint()..color = _skin, 0);

    // Biceps shading.
    if (bulge > 0) {
      canvas.drawArc(
        bicep.deflate(bicep.height * 0.18),
        0.2,
        pi - 0.4,
        false,
        Paint()
          ..color = _shade
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.0, s * 0.025)
          ..strokeCap = StrokeCap.round,
      );
    }

    // Sleeve at the shoulder.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: shoulder.translate(-0.02 * s, 0),
          width: 0.16 * s,
          height: t * 1.6,
        ),
        Radius.circular(s * 0.04),
      ),
      Paint()..color = armColor(level),
    );

    // Power lines above a big biceps.
    if (level == ArmLevel.strong) {
      final lines = Paint()
        ..color = const Color(0xFFFFA000)
        ..strokeWidth = max(1.2, s * 0.03)
        ..strokeCap = StrokeCap.round;
      final top = bicep.topCenter;
      for (final (dx, angle) in [(-0.17, -2.6), (-0.1, -2.1), (-0.02, -1.7)]) {
        final start = top.translate(dx * s, -0.06 * s);
        canvas.drawLine(
          start,
          start + Offset(cos(angle), sin(angle)) * 0.1 * s,
          lines,
        );
      }
    }
    canvas.restore();
  }

  void _dumbbell(Canvas canvas, Offset hand, double s) {
    final plate = switch (level) {
      ArmLevel.skinny => 0.16,
      ArmLevel.moderate => 0.22,
      ArmLevel.strong => 0.28,
    };
    final half = 0.25 * s;
    final bar = Paint()
      ..color = const Color(0xFF616161)
      ..strokeWidth = max(1.5, s * 0.045)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(hand.translate(-half, 0), hand.translate(half, 0), bar);
    final plates = Paint()..color = const Color(0xFF37474F);
    for (final side in [-1, 1]) {
      // An inner and a smaller outer plate on each end.
      for (final (offset, scale) in [(0.15, 1.0), (0.215, 0.72)]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: hand.translate(side * offset * s, 0),
              width: 0.065 * s,
              height: plate * s * scale,
            ),
            Radius.circular(s * 0.015),
          ),
          plates,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ArmPainter old) => old.level != level;
}
