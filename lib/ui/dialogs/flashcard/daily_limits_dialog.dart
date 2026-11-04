import 'dart:math';

import 'package:flashcards/data/services/local/session_progress_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Lets the student choose their daily plan: how many cards to study a day
/// and how many of them are new (the rest are reviews). It sets today's
/// target on the home page and the size of every pack's session.
/// [goalPerDay] is what the exam goal needs, offered as a suggestion.
/// Returns whether the plan changed.
Future<bool> showDailyPlanDialog(
  BuildContext context, {
  int? goalPerDay,
}) async {
  final store = context.read<SessionProgressStore>();
  final messenger = ScaffoldMessenger.of(context);
  final current = await store.dailyLimits();
  if (!context.mounted) return false;
  final chosen = await showDialog<_Choice>(
    context: context,
    builder: (context) =>
        DailyPlanDialog(current: current, goalPerDay: goalPerDay),
  );
  if (chosen == null) return false;
  await store.setDailyLimits(chosen.limits);
  final plan = chosen.limits;
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        plan == null
            ? 'Daily plan off: sessions use your cards per session.'
            : 'Every day: ${plan.newCards + plan.reviews} cards, '
                  '${plan.newCards} new and ${plan.reviews} reviews.',
      ),
    ),
  );
  return true;
}

class _Choice {
  final ({int newCards, int reviews})? limits;

  const _Choice(this.limits);
}

class DailyPlanDialog extends StatefulWidget {
  final ({int newCards, int reviews})? current;
  final int? goalPerDay;

  const DailyPlanDialog({super.key, required this.current, this.goalPerDay});

  @override
  State<DailyPlanDialog> createState() => _DailyPlanDialogState();
}

class _DailyPlanDialogState extends State<DailyPlanDialog> {
  static const _maxTotal = 2000;

  late bool _on = widget.current != null;
  late final _total = TextEditingController(
    text:
        '${widget.current == null ? 100 : widget.current!.newCards + widget.current!.reviews}',
  );
  late int _newCards = widget.current?.newCards ?? 20;
  String? _error;

  int get _totalValue => int.tryParse(_total.text.trim()) ?? 0;

  @override
  void dispose() {
    _total.dispose();
    super.dispose();
  }

  void _useGoal() {
    final goal = widget.goalPerDay!;
    setState(() {
      _newCards = goal;
      if (_totalValue < goal) _total.text = '${goal * 2}';
      _on = true;
      _error = null;
    });
  }

  void _save() {
    if (!_on) {
      Navigator.of(context).pop(const _Choice(null));
      return;
    }
    final total = _totalValue;
    if (total <= 0 || total > _maxTotal) {
      setState(() => _error = 'Enter 1 to $_maxTotal cards a day.');
      return;
    }
    final newCards = min(_newCards, total);
    Navigator.of(
      context,
    ).pop(_Choice((newCards: newCards, reviews: total - newCards)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _totalValue.clamp(0, _maxTotal);
    final newCards = min(_newCards, total);
    final goal = widget.goalPerDay;
    return AlertDialog(
      title: const Text('Daily plan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'How many cards to study each day, and how many of them are '
              'new. It sets today\'s target and every pack\'s session, on all '
              'your devices.',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use a daily plan'),
              value: _on,
              onChanged: (value) => setState(() {
                _on = value;
                _error = null;
              }),
            ),
            TextField(
              controller: _total,
              enabled: _on,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Cards a day',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Text(
              'New cards: $newCards',
              style: theme.textTheme.titleSmall?.copyWith(
                color: _on ? null : theme.disabledColor,
              ),
            ),
            Slider(
              value: newCards.toDouble(),
              max: max(1, total).toDouble(),
              divisions: max(1, total),
              label: '$newCards new',
              onChanged: _on && total > 0
                  ? (value) => setState(() => _newCards = value.round())
                  : null,
            ),
            Text(
              '$newCards new + ${total - newCards} reviews = $total cards',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (goal != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your exam goal needs about $goal new cards a day.',
                      ),
                    ),
                    TextButton(onPressed: _useGoal, child: const Text('Use')),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (!_on) ...[
              const SizedBox(height: 10),
              Text(
                'Off: each session uses your cards per session (or your exam '
                'goal), mostly reviews when many are due.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
