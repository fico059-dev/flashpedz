import 'package:flashcards/ui/widgets/flashcard/flashcard_test/rating_buttons/rating_segments.dart';
import 'package:flutter/material.dart';

/// Right and wrong answers so far, with a bar showing the share of each.
class SessionScoreBar extends StatelessWidget {
  final int correct;
  final int wrong;

  const SessionScoreBar({
    super.key,
    required this.correct,
    required this.wrong,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answered = correct + wrong;
    final percent = answered == 0 ? null : (correct * 100 / answered).round();
    final empty = theme.colorScheme.surfaceContainerHighest;
    return Semantics(
      label: '$correct correct, $wrong wrong',
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                // Small phones: the icons and numbers only.
                final words = constraints.maxWidth >= 360;
                return Row(
                  children: [
                    _Count(
                      icon: Icons.check_circle,
                      color: rememberedColor,
                      text: words ? '$correct correct' : '$correct',
                    ),
                    const SizedBox(width: 14),
                    _Count(
                      icon: Icons.cancel,
                      color: againColor,
                      text: words ? '$wrong wrong' : '$wrong',
                    ),
                    const Spacer(),
                    Text(
                      percent == null ? '' : '$percent%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: answered == 0
                    ? ColoredBox(color: empty)
                    : Row(
                        children: [
                          if (correct > 0)
                            Expanded(
                              flex: correct,
                              child: const ColoredBox(color: rememberedColor),
                            ),
                          if (wrong > 0)
                            Expanded(
                              flex: wrong,
                              child: const ColoredBox(color: againColor),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Count({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
