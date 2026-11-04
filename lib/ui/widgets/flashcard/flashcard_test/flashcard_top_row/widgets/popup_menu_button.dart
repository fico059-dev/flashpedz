import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flutter/material.dart';

enum Menu { ignore, report }

class PopupMenuButtonTopRow extends StatelessWidget {
  final VoidCallback? onIgnore;
  final VoidCallback? onReport;
  final VoidCallback? onAddToSet;
  final bool enabled;

  const PopupMenuButtonTopRow({
    super.key,
    required this.onReport,
    required this.enabled,
    this.onIgnore,
    this.onAddToSet,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Menu>(
      enabled: enabled,
      icon: Icon(Icons.more_vert, color: context.colors.primaryContainer),
      itemBuilder: (context) => <PopupMenuEntry<Menu>>[
        if (onAddToSet != null)
          PopupMenuItem(
            onTap: onAddToSet,
            child: ListTile(
              leading: Icon(Icons.playlist_add, color: context.colors.primary),
              title: Text("Add to set…"),
              titleTextStyle: TextStyle(
                fontWeight: FontWeight.normal,
                color: context.colors.primary,
              ),
            ),
          ),
        if (onIgnore != null)
          PopupMenuItem(
            onTap: () => _showIgnoreDialog(context, onIgnore!),
            child: ListTile(
              leading: Icon(
                Icons.visibility_off,
                color: context.colors.primary,
              ),
              title: Text("Ignore"),
              titleTextStyle: TextStyle(
                fontWeight: FontWeight.normal,
                color: context.colors.primary,
              ),
            ),
          ),
        PopupMenuItem(
          onTap: onReport,
          child: ListTile(
            leading: Icon(Icons.flag, color: context.colors.primary),
            title: Text("Report"),
            titleTextStyle: TextStyle(
              fontWeight: FontWeight.normal,
              color: context.colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

void _showIgnoreDialog(BuildContext context, VoidCallback onIgnore) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("Ignore this card?"),
      content: Text(
        "Ignored cards won't appear in future review sessions. "
        "You can restore them later from your settings.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text("Cancel"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text("Ignore"),
        ),
      ],
    ),
  );

  if (confirmed == true) onIgnore();
}
