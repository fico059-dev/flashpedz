import 'package:flashcards/data/services/local/session_progress_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Lets the student choose how many new cards and reviews to study a day,
/// so new cards keep coming even when many reviews are due.
Future<void> showDailyLimitsDialog(BuildContext context) async {
  final store = context.read<SessionProgressStore>();
  final messenger = ScaffoldMessenger.of(context);
  final current = await store.dailyLimits();
  if (!context.mounted) return;
  final chosen = await showDialog<_Choice>(
    context: context,
    builder: (context) => _DailyLimitsDialog(current: current),
  );
  if (chosen == null) return;
  await store.setDailyLimits(chosen.limits);
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        chosen.limits == null
            ? 'Daily limits off: sessions use their usual size.'
            : 'Every day: up to ${chosen.limits!.newCards} new cards and '
                  '${chosen.limits!.reviews} reviews.',
      ),
    ),
  );
}

class _Choice {
  final ({int newCards, int reviews})? limits;

  const _Choice(this.limits);
}

class _DailyLimitsDialog extends StatefulWidget {
  final ({int newCards, int reviews})? current;

  const _DailyLimitsDialog({required this.current});

  @override
  State<_DailyLimitsDialog> createState() => _DailyLimitsDialogState();
}

class _DailyLimitsDialogState extends State<_DailyLimitsDialog> {
  late bool _on = widget.current != null;
  late final _newCards = TextEditingController(
    text: '${widget.current?.newCards ?? 20}',
  );
  late final _reviews = TextEditingController(
    text: '${widget.current?.reviews ?? 200}',
  );
  String? _error;

  @override
  void dispose() {
    _newCards.dispose();
    _reviews.dispose();
    super.dispose();
  }

  void _save() {
    if (!_on) {
      Navigator.of(context).pop(const _Choice(null));
      return;
    }
    final newCards = int.tryParse(_newCards.text.trim());
    final reviews = int.tryParse(_reviews.text.trim());
    if (newCards == null ||
        reviews == null ||
        newCards > 1000 ||
        reviews > 5000 ||
        newCards + reviews == 0) {
      setState(() => _error = 'Enter 0–1000 new cards and 0–5000 reviews.');
      return;
    }
    Navigator.of(context).pop(_Choice((newCards: newCards, reviews: reviews)));
  }

  Widget _field(TextEditingController controller, String label, String help) =>
      TextField(
        controller: controller,
        enabled: _on,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          helperText: help,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _save(),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Daily new cards & reviews'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose how many new cards and reviews to study each day, like '
              'in Anki. You keep getting new cards every day even when many '
              'reviews are due. Counts every pack, custom session and device.',
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use daily limits'),
              value: _on,
              onChanged: (value) => setState(() {
                _on = value;
                _error = null;
              }),
            ),
            const SizedBox(height: 8),
            _field(_newCards, 'New cards per day', 'Cards you have never seen'),
            const SizedBox(height: 16),
            _field(_reviews, 'Reviews per day', 'Cards due again'),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (!_on) ...[
              const SizedBox(height: 10),
              Text(
                'Off: each session uses your cards per session (or your exam '
                'goal), mostly reviews when many are due.',
                style: Theme.of(context).textTheme.bodySmall,
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
