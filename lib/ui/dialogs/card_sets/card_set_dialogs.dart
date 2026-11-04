import 'package:flashcards/data/repositories/card_sets/card_set_repository.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Asks for a set's name. Returns null when cancelled.
Future<String?> showSetNameDialog(
  BuildContext context, {
  String current = '',
  String title = 'New set',
}) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) {
      void save() {
        final name = controller.text.trim();
        if (name.isNotEmpty) Navigator.of(context).pop(name);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Cardio weak spots',
          ),
          onSubmitted: (_) => save(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: save, child: const Text('Save')),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}

/// Lets the student put a card in their sets (or take it out), and make a
/// new set for it.
Future<void> showAddToSetSheet(BuildContext context, String flashcardId) {
  final repo = context.read<CardSetRepository>();
  repo.load();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _AddToSetSheet(flashcardId: flashcardId, repo: repo),
  );
}

class _AddToSetSheet extends StatelessWidget {
  final String flashcardId;
  final CardSetRepository repo;

  const _AddToSetSheet({required this.flashcardId, required this.repo});

  Future<void> _run(BuildContext context, Future<void> Function() work) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await work();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(extractErrorMessage(error))),
      );
    }
  }

  Future<void> _newSet(BuildContext context) async {
    final name = await showSetNameDialog(context);
    if (name == null || !context.mounted) return;
    await _run(context, () async {
      final set = await repo.create(name);
      await repo.setCard(set.id, flashcardId, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final sets = repo.sets;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add to My Sets',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Up to $maxCardSets sets. Study and browse them from '
                  'Packs → Sets & Sessions.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (!repo.isLoaded && repo.loadError == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (repo.loadError != null)
                  Text(extractErrorMessage(repo.loadError!)),
                for (final set in sets)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(set.name),
                    subtitle: Text('${set.cardCount} cards'),
                    value: set.contains(flashcardId),
                    onChanged: (value) => _run(
                      context,
                      () => repo.setCard(set.id, flashcardId, value ?? false),
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: repo.isLoaded && repo.canAddSet
                      ? () => _newSet(context)
                      : null,
                  icon: const Icon(Icons.add),
                  label: Text(
                    repo.isLoaded && !repo.canAddSet
                        ? 'You have $maxCardSets sets (the most)'
                        : 'New set',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
