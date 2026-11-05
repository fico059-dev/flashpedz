import 'package:auto_route/auto_route.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/data/repositories/card_sets/card_set_repository.dart';
import 'package:flashcards/ui/dialogs/card_sets/card_set_dialogs.dart';
import 'package:flashcards/ui/pages/card_browser/card_browser_page.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

/// "My Sets": up to five named sets of cards the student collects while
/// studying, each studied and browsed like a pack.
class MySetsSection extends StatefulWidget {
  const MySetsSection({super.key});

  @override
  State<MySetsSection> createState() => _MySetsSectionState();
}

class _MySetsSectionState extends State<MySetsSection> {
  @override
  void initState() {
    super.initState();
    context.read<CardSetRepository>().load();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CardSetRepository>();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'My Sets (${repo.sets.length}/$maxCardSets)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: repo.isLoaded && repo.canAddSet
                  ? () => _newSet(context, repo)
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('New set'),
            ),
          ],
        ),
        if (!repo.isLoaded && repo.loadError == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (repo.loadError != null && !repo.isLoaded)
          Row(
            children: [
              Expanded(child: Text(extractErrorMessage(repo.loadError!))),
              TextButton(
                onPressed: () => repo.load(refresh: true),
                child: const Text('Retry'),
              ),
            ],
          )
        else if (repo.sets.isEmpty)
          Text(
            'Collect cards into your own sets (e.g. "Cardio weak spots"): '
            'while studying, tap ⋮ → Add to set.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          )
        else
          for (final set in repo.sets) _SetTile(set: set),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Examine Yourself',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  context.router.push(const CustomSessionWrapperRoute()),
              icon: const Icon(Icons.add),
              label: const Text('New exam'),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

Future<void> _newSet(BuildContext context, CardSetRepository repo) async {
  final name = await showSetNameDialog(context);
  if (name == null || !context.mounted) return;
  await _run(context, () => repo.create(name));
}

Future<void> _run(BuildContext context, Future<void> Function() work) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await work();
  } catch (error) {
    messenger.showSnackBar(SnackBar(content: Text(extractErrorMessage(error))));
  }
}

/// Starts studying a set: its cards in a random order.
Future<void> studySet(BuildContext context, CardSet set) async {
  final repo = context.read<CardSetRepository>();
  final router = context.router;
  final overlay = context.loaderOverlay;
  final messenger = ScaffoldMessenger.of(context);
  overlay.show();
  try {
    final session = await repo.study(set.id);
    overlay.hide();
    router.push(CustomSessionTestRoute(sessionSummary: session));
  } catch (error) {
    overlay.hide();
    messenger.showSnackBar(SnackBar(content: Text(extractErrorMessage(error))));
  }
}

enum _SetAction { browse, rename, delete }

class _SetTile extends StatelessWidget {
  final CardSet set;

  const _SetTile({required this.set});

  Future<void> _delete(BuildContext context) async {
    final repo = context.read<CardSetRepository>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${set.name}"?'),
        content: const Text(
          'The set is removed. The cards stay in their packs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(context, () => repo.delete(set.id));
    }
  }

  void _browse(BuildContext context) {
    final repo = context.read<CardSetRepository>();
    openCardBrowser(
      context,
      title: set.name,
      setId: set.id,
      loadIds: () async =>
          (repo.byId(set.id)?.flashcardIds ?? const []).reversed.toList(),
      onStudy: (context) => studySet(context, repo.byId(set.id) ?? set),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 16, right: 4),
        leading: CircleAvatar(
          backgroundColor: context.colors.primaryContainer,
          foregroundColor: context.colors.onPrimaryContainer,
          child: const Icon(Icons.collections_bookmark_outlined),
        ),
        title: Text(set.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${set.cardCount} cards'),
        onTap: () => _browse(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Study',
              onPressed: set.cardCount == 0
                  ? null
                  : () => studySet(context, set),
              icon: const Icon(Icons.play_circle_fill),
              color: context.colors.primary,
            ),
            PopupMenuButton<_SetAction>(
              tooltip: 'Set options',
              onSelected: (action) async {
                switch (action) {
                  case _SetAction.browse:
                    _browse(context);
                  case _SetAction.rename:
                    final repo = context.read<CardSetRepository>();
                    final name = await showSetNameDialog(
                      context,
                      current: set.name,
                      title: 'Rename set',
                    );
                    if (name != null && context.mounted) {
                      await _run(context, () => repo.rename(set.id, name));
                    }
                  case _SetAction.delete:
                    await _delete(context);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _SetAction.browse,
                  child: ListTile(
                    leading: Icon(Icons.view_list),
                    title: Text('Browse cards'),
                  ),
                ),
                PopupMenuItem(
                  value: _SetAction.rename,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Rename'),
                  ),
                ),
                PopupMenuItem(
                  value: _SetAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
