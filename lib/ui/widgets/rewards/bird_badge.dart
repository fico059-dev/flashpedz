import 'dart:math';

import 'package:flashcards/domain/models/progress/level.dart';
import 'package:flutter/material.dart';

/// Ring colours of each rarity, light to dark.
(Color, Color) rarityColors(BirdRarity rarity) => switch (rarity) {
  BirdRarity.common => (const Color(0xFFD7B48A), const Color(0xFF8D6E63)),
  BirdRarity.uncommon => (const Color(0xFF9CCC65), const Color(0xFF2E7D32)),
  BirdRarity.rare => (const Color(0xFF64B5F6), const Color(0xFF1565C0)),
  BirdRarity.epic => (const Color(0xFFCE93D8), const Color(0xFF6A1B9A)),
  BirdRarity.legendary => (const Color(0xFFFFE082), const Color(0xFFFF8F00)),
};

/// A round badge with the level's bird, in a ring of its rarity's colour.
class BirdBadgeIcon extends StatelessWidget {
  final int level;
  final double size;

  const BirdBadgeIcon({super.key, required this.level, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final badge = birdBadgeFor(level);
    final (light, dark) = rarityColors(badge.rarity);
    return Tooltip(
      message: '${badge.displayName(level)} · ${badge.rarity.label}',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.07),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [light, dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: badge.rarity == BirdRarity.legendary
              ? [BoxShadow(color: light.withValues(alpha: 0.7), blurRadius: 8)]
              : null,
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFFBF2),
          ),
          child: CustomPaint(painter: BirdPainter(badge.name)),
        ),
      ),
    );
  }
}

enum _Beak { short, long, big, hooked, needle, bent }

enum _Tail { short, long, forked, fan, streamer }

enum _Crest { none, tuft, cap, ears, plumes, flame }

/// How one bird looks.
class _Look {
  final Color body;
  final Color wing;
  final Color? belly;
  final Color? head;
  final Color beakColor;
  final _Beak beak;
  final _Tail tail;
  final _Crest crest;
  final Color? crestColor;
  final Color? tailColor;
  final bool bigEye;
  final double legs;

  const _Look({
    required this.body,
    required this.wing,
    this.belly,
    this.head,
    this.beakColor = const Color(0xFFFFA000),
    this.beak = _Beak.short,
    this.tail = _Tail.short,
    this.crest = _Crest.none,
    this.crestColor,
    this.tailColor,
    this.bigEye = false,
    this.legs = 1,
  });
}

const _looks = <String, _Look>{
  'Pigeon': _Look(
    body: Color(0xFF90A4AE),
    wing: Color(0xFF78909C),
    head: Color(0xFF607D8B),
    belly: Color(0xFFB0BEC5),
    beakColor: Color(0xFF455A64),
  ),
  'Sparrow': _Look(
    body: Color(0xFFA1887F),
    wing: Color(0xFF6D4C41),
    belly: Color(0xFFD7CCC8),
    beakColor: Color(0xFF5D4037),
  ),
  'Robin': _Look(
    body: Color(0xFF8D6E63),
    wing: Color(0xFF6D4C41),
    belly: Color(0xFFFF7043),
    beakColor: Color(0xFF3E2723),
  ),
  'Swallow': _Look(
    body: Color(0xFF283593),
    wing: Color(0xFF1A237E),
    belly: Color(0xFFFFF3E0),
    head: Color(0xFF283593),
    beakColor: Color(0xFF212121),
    tail: _Tail.forked,
  ),
  'Kingfisher': _Look(
    body: Color(0xFF039BE5),
    wing: Color(0xFF0277BD),
    belly: Color(0xFFFF8F00),
    beakColor: Color(0xFF212121),
    beak: _Beak.long,
  ),
  'Woodpecker': _Look(
    body: Color(0xFF424242),
    wing: Color(0xFF212121),
    belly: Color(0xFFF5F5F5),
    beakColor: Color(0xFF616161),
    beak: _Beak.long,
    crest: _Crest.cap,
    crestColor: Color(0xFFE53935),
  ),
  'Parrot': _Look(
    body: Color(0xFF43A047),
    wing: Color(0xFF1E88E5),
    head: Color(0xFFE53935),
    beakColor: Color(0xFFFFE0B2),
    beak: _Beak.hooked,
    tail: _Tail.long,
    tailColor: Color(0xFFFDD835),
  ),
  'Owl': _Look(
    body: Color(0xFF8D6E63),
    wing: Color(0xFF5D4037),
    belly: Color(0xFFD7CCC8),
    beakColor: Color(0xFFFFB300),
    beak: _Beak.hooked,
    crest: _Crest.ears,
    bigEye: true,
  ),
  'Toucan': _Look(
    body: Color(0xFF212121),
    wing: Color(0xFF000000),
    belly: Color(0xFFFFF59D),
    beakColor: Color(0xFFFF9800),
    beak: _Beak.big,
  ),
  'Flamingo': _Look(
    body: Color(0xFFF48FB1),
    wing: Color(0xFFEC407A),
    beakColor: Color(0xFF212121),
    beak: _Beak.bent,
    legs: 1.9,
  ),
  'Hummingbird': _Look(
    body: Color(0xFF26A69A),
    wing: Color(0xFF00796B),
    head: Color(0xFF7B1FA2),
    belly: Color(0xFFE0F2F1),
    beakColor: Color(0xFF263238),
    beak: _Beak.needle,
  ),
  'Peacock': _Look(
    body: Color(0xFF1565C0),
    wing: Color(0xFF00897B),
    beakColor: Color(0xFF9E9E9E),
    tail: _Tail.fan,
    tailColor: Color(0xFF2E7D32),
    crest: _Crest.plumes,
    crestColor: Color(0xFF1565C0),
  ),
  'Falcon': _Look(
    body: Color(0xFF546E7A),
    wing: Color(0xFF37474F),
    belly: Color(0xFFECEFF1),
    head: Color(0xFF37474F),
    beakColor: Color(0xFFFFC107),
    beak: _Beak.hooked,
  ),
  'Golden Eagle': _Look(
    body: Color(0xFF6D4C41),
    wing: Color(0xFF4E342E),
    head: Color(0xFFFFB300),
    beakColor: Color(0xFFFFD54F),
    beak: _Beak.hooked,
  ),
  'Bird of Paradise': _Look(
    body: Color(0xFF6D4C41),
    wing: Color(0xFF4E342E),
    head: Color(0xFFFDD835),
    belly: Color(0xFF00897B),
    beakColor: Color(0xFF90A4AE),
    tail: _Tail.streamer,
    tailColor: Color(0xFFFFA000),
  ),
  'Quetzal': _Look(
    body: Color(0xFF2E7D32),
    wing: Color(0xFF1B5E20),
    belly: Color(0xFFD32F2F),
    beakColor: Color(0xFFFDD835),
    tail: _Tail.streamer,
    tailColor: Color(0xFF43A047),
    crest: _Crest.tuft,
    crestColor: Color(0xFF2E7D32),
  ),
  'Phoenix': _Look(
    body: Color(0xFFFF7043),
    wing: Color(0xFFFFB300),
    belly: Color(0xFFFFE082),
    head: Color(0xFFF4511E),
    beakColor: Color(0xFFFFD54F),
    beak: _Beak.hooked,
    tail: _Tail.streamer,
    tailColor: Color(0xFFFF3D00),
    crest: _Crest.flame,
    crestColor: Color(0xFFFFC107),
  ),
};

/// Draws a bird facing right on a 100 × 100 grid.
class BirdPainter extends CustomPainter {
  final String bird;

  BirdPainter(this.bird);

  @override
  void paint(Canvas canvas, Size size) {
    final look = _looks[bird] ?? _looks['Pigeon']!;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final fill = Paint()..style = PaintingStyle.fill;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0x55000000);

    // Long-legged birds stand higher.
    final lift = (look.legs - 1) * 12;
    final bodyCenter = Offset(46, 58 - lift);
    final headCenter = Offset(69, 38 - lift);

    // Tail, behind the body.
    final tailColor = look.tailColor ?? look.wing;
    switch (look.tail) {
      case _Tail.fan:
        for (var i = 0; i < 7; i++) {
          final angle = pi * (0.55 + i * 0.13);
          final tip = bodyCenter + Offset(cos(angle), -sin(angle)) * 44;
          canvas.drawLine(
            bodyCenter,
            tip,
            Paint()
              ..color = tailColor
              ..strokeWidth = 7
              ..strokeCap = StrokeCap.round,
          );
          canvas.drawCircle(tip, 5, fill..color = const Color(0xFF00ACC1));
          canvas.drawCircle(tip, 2.4, fill..color = const Color(0xFF283593));
        }
      case _Tail.streamer:
        final path = Path()
          ..moveTo(26, bodyCenter.dy + 2)
          ..quadraticBezierTo(10, bodyCenter.dy + 20, 2, bodyCenter.dy + 36)
          ..quadraticBezierTo(14, bodyCenter.dy + 18, 30, bodyCenter.dy + 8)
          ..close();
        canvas.drawPath(path, fill..color = tailColor);
        final second = Path()
          ..moveTo(28, bodyCenter.dy + 4)
          ..quadraticBezierTo(18, bodyCenter.dy + 26, 14, bodyCenter.dy + 40)
          ..quadraticBezierTo(22, bodyCenter.dy + 24, 32, bodyCenter.dy + 8)
          ..close();
        canvas.drawPath(second, fill..color = tailColor.withValues(alpha: 0.8));
      case _Tail.forked:
        final path = Path()
          ..moveTo(28, bodyCenter.dy)
          ..lineTo(4, bodyCenter.dy - 4)
          ..lineTo(18, bodyCenter.dy + 4)
          ..lineTo(4, bodyCenter.dy + 14)
          ..lineTo(28, bodyCenter.dy + 8)
          ..close();
        canvas.drawPath(path, fill..color = tailColor);
      case _Tail.long:
        final path = Path()
          ..moveTo(28, bodyCenter.dy - 2)
          ..lineTo(4, bodyCenter.dy + 14)
          ..lineTo(10, bodyCenter.dy + 18)
          ..lineTo(30, bodyCenter.dy + 8)
          ..close();
        canvas.drawPath(path, fill..color = tailColor);
      case _Tail.short:
        final path = Path()
          ..moveTo(26, bodyCenter.dy - 4)
          ..lineTo(10, bodyCenter.dy + 2)
          ..lineTo(14, bodyCenter.dy + 10)
          ..lineTo(28, bodyCenter.dy + 8)
          ..close();
        canvas.drawPath(path, fill..color = tailColor);
    }

    // Legs.
    final legPaint = Paint()
      ..color = bird == 'Flamingo'
          ? const Color(0xFFF06292)
          : const Color(0xFF6D4C41)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final legTop = bodyCenter.dy + 16;
    final legBottom = min(97.0, legTop + 12 * look.legs);
    for (final x in [42.0, 51.0]) {
      canvas.drawLine(Offset(x, legTop), Offset(x, legBottom), legPaint);
      canvas.drawLine(Offset(x, legBottom), Offset(x + 4, legBottom), legPaint);
    }

    // Body and belly.
    final body = Rect.fromCenter(center: bodyCenter, width: 50, height: 38);
    canvas.drawOval(body, fill..color = look.body);
    if (look.belly case final belly?) {
      canvas.save();
      canvas.clipPath(Path()..addOval(body));
      canvas.drawOval(
        Rect.fromCenter(
          center: bodyCenter + const Offset(8, 10),
          width: 40,
          height: 26,
        ),
        fill..color = belly,
      );
      canvas.restore();
    }
    canvas.drawOval(body, outline);

    // Wing.
    canvas.save();
    canvas.translate(bodyCenter.dx - 4, bodyCenter.dy - 2);
    canvas.rotate(-0.25);
    final wing = Rect.fromCenter(center: Offset.zero, width: 36, height: 20);
    canvas.drawOval(wing, fill..color = look.wing);
    canvas.drawOval(wing, outline);
    canvas.restore();

    // Crest behind the head.
    final crestColor = look.crestColor ?? look.head ?? look.body;
    switch (look.crest) {
      case _Crest.tuft:
        final path = Path()
          ..moveTo(headCenter.dx - 8, headCenter.dy - 6)
          ..quadraticBezierTo(
            headCenter.dx - 2,
            headCenter.dy - 26,
            headCenter.dx + 8,
            headCenter.dy - 10,
          )
          ..close();
        canvas.drawPath(path, fill..color = crestColor);
      case _Crest.plumes:
        for (final dx in [-6.0, 0.0, 6.0]) {
          final top = headCenter + Offset(dx, -24);
          canvas.drawLine(
            headCenter + Offset(dx / 2, -10),
            top,
            Paint()
              ..color = crestColor
              ..strokeWidth = 1.6,
          );
          canvas.drawCircle(top, 2.6, fill..color = crestColor);
        }
      case _Crest.ears:
        for (final dx in [-9.0, 5.0]) {
          final path = Path()
            ..moveTo(headCenter.dx + dx, headCenter.dy - 8)
            ..lineTo(headCenter.dx + dx + 2, headCenter.dy - 22)
            ..lineTo(headCenter.dx + dx + 7, headCenter.dy - 9)
            ..close();
          canvas.drawPath(path, fill..color = look.wing);
        }
      case _Crest.flame:
        for (var i = 0; i < 3; i++) {
          final x = headCenter.dx - 8 + i * 6.0;
          final path = Path()
            ..moveTo(x - 3, headCenter.dy - 8)
            ..quadraticBezierTo(
              x - 4,
              headCenter.dy - 22,
              x + 2,
              headCenter.dy - 30 + i * 4,
            )
            ..quadraticBezierTo(
              x + 3,
              headCenter.dy - 18,
              x + 4,
              headCenter.dy - 8,
            )
            ..close();
          canvas.drawPath(
            path,
            fill..color = i.isEven ? crestColor : const Color(0xFFFF5722),
          );
        }
      case _Crest.cap:
      case _Crest.none:
        break;
    }

    // Head.
    canvas.drawCircle(headCenter, 14, fill..color = look.head ?? look.body);
    if (look.crest == _Crest.cap) {
      canvas.save();
      canvas.clipPath(
        Path()..addOval(Rect.fromCircle(center: headCenter, radius: 14)),
      );
      canvas.drawRect(
        Rect.fromLTWH(headCenter.dx - 14, headCenter.dy - 14, 28, 9),
        fill..color = crestColor,
      );
      canvas.restore();
    }
    canvas.drawCircle(headCenter, 14, outline);

    // Beak.
    final b = headCenter + const Offset(12, 2);
    final beakPath = switch (look.beak) {
      _Beak.short =>
        Path()
          ..moveTo(b.dx, b.dy - 4)
          ..lineTo(b.dx + 10, b.dy)
          ..lineTo(b.dx, b.dy + 4),
      _Beak.long =>
        Path()
          ..moveTo(b.dx, b.dy - 4)
          ..lineTo(b.dx + 20, b.dy + 1)
          ..lineTo(b.dx, b.dy + 4),
      _Beak.needle =>
        Path()
          ..moveTo(b.dx, b.dy - 2)
          ..lineTo(b.dx + 24, b.dy + 2)
          ..lineTo(b.dx, b.dy + 2),
      _Beak.big =>
        Path()
          ..moveTo(b.dx - 2, b.dy - 9)
          ..quadraticBezierTo(b.dx + 22, b.dy - 10, b.dx + 26, b.dy + 2)
          ..quadraticBezierTo(b.dx + 14, b.dy + 8, b.dx - 2, b.dy + 7),
      _Beak.hooked =>
        Path()
          ..moveTo(b.dx - 1, b.dy - 5)
          ..quadraticBezierTo(b.dx + 12, b.dy - 6, b.dx + 10, b.dy + 7)
          ..quadraticBezierTo(b.dx + 6, b.dy + 2, b.dx - 1, b.dy + 4),
      _Beak.bent =>
        Path()
          ..moveTo(b.dx - 1, b.dy - 4)
          ..lineTo(b.dx + 10, b.dy - 2)
          ..quadraticBezierTo(b.dx + 14, b.dy + 2, b.dx + 10, b.dy + 12)
          ..lineTo(b.dx + 6, b.dy + 4)
          ..lineTo(b.dx - 1, b.dy + 4),
    }..close();
    canvas.drawPath(beakPath, fill..color = look.beakColor);
    if (look.beak == _Beak.big) {
      canvas.drawPath(
        Path()
          ..moveTo(b.dx + 18, b.dy - 7)
          ..quadraticBezierTo(b.dx + 25, b.dy - 4, b.dx + 26, b.dy + 2)
          ..lineTo(b.dx + 20, b.dy + 2)
          ..close(),
        fill..color = const Color(0xFF212121),
      );
    }

    // Eye.
    final eye = headCenter + const Offset(4, -3);
    if (look.bigEye) {
      canvas.drawCircle(eye, 6, fill..color = const Color(0xFFFFC107));
      canvas.drawCircle(eye, 3.4, fill..color = Colors.black);
    } else {
      canvas.drawCircle(eye, 2.6, fill..color = Colors.black);
    }
    canvas.drawCircle(
      eye + const Offset(-0.8, -0.8),
      0.9,
      fill..color = Colors.white,
    );

    // The phoenix glows.
    if (bird == 'Phoenix') {
      canvas.drawCircle(
        bodyCenter,
        30,
        Paint()
          ..color = const Color(0x33FFC107)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BirdPainter old) => old.bird != bird;
}

/// Every bird badge; those not earned yet are grey with a lock.
class BirdBadgeCollection extends StatelessWidget {
  /// The student's level: badges up to it are earned.
  final int level;

  const BirdBadgeCollection({super.key, required this.level});

  static const _grey = ColorFilter.matrix([
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0.45, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < birdBadges.length; i++)
          SizedBox(
            width: 76,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    i < level
                        ? BirdBadgeIcon(level: i + 1, size: 60)
                        : ColorFiltered(
                            colorFilter: _grey,
                            child: BirdBadgeIcon(level: i + 1, size: 60),
                          ),
                    if (i >= level)
                      const Icon(Icons.lock, size: 20, color: Colors.black54),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  birdBadges[i].name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: text.labelSmall?.copyWith(
                    fontWeight: i < level ? FontWeight.w700 : null,
                  ),
                ),
                Text(
                  birdBadges[i].rarity.label,
                  style: text.labelSmall?.copyWith(
                    fontSize: 9,
                    color: rarityColors(birdBadges[i].rarity).$2,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Shows all the bird badges.
Future<void> showBirdBadgeCollection(BuildContext context, int level) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          children: [
            Text(
              'Your bird badges',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Study to earn rarer birds, from a pigeon to a phoenix.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            BirdBadgeCollection(level: level),
          ],
        ),
      ),
    ),
  );
}
