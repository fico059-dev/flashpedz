import 'package:flashcards/domain/models/flashcards/custom_session_summary/custom_session_summary.dart';
import 'package:flashcards/ui/constants/placeholders.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/core/subs_status_icon.dart';
import 'package:flashcards/utils/util_functions.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class PreviousSessionCard extends StatelessWidget {
  final CustomSessionSummary session;
  final VoidCallback? onStartPressed;
  final VoidCallback? onDeletePressed;
  final VoidCallback? onResetPressed;
  final VoidCallback? onRenamePressed;
  final VoidCallback? onBrowsePressed;
  final VoidCallback? onSaveAsSetPressed;
  final bool? hasCards;
  final VoidCallback? onTap;

  const PreviousSessionCard({
    super.key,
    required this.session,
    required this.hasCards,
    this.onStartPressed,
    this.onDeletePressed,
    this.onResetPressed,
    this.onRenamePressed,
    this.onBrowsePressed,
    this.onSaveAsSetPressed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = context.colors.surfaceContainerHigh;

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Builder(
        builder: (context) => Card(
          margin: EdgeInsets.all(0),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  // Top-right card count
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Row(
                      spacing: 6,
                      children: [
                        SubsStatusIcon(
                          isPaid: session.isPaid,
                          hasAccess: hasCards,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${session.cardCount} cards',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: context.colors.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _SessionMenu(
                          onStart: onStartPressed,
                          onBrowse: onBrowsePressed,
                          onSaveAsSet: onSaveAsSetPressed,
                          onRename: onRenamePressed,
                          onReset: onResetPressed,
                          onDelete: onDeletePressed,
                        ),
                      ],
                    ),
                  ),

                  // Main content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Leaves room for the card count in the corner.
                      Padding(
                        padding: const EdgeInsets.only(right: 150),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                session.displayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (onRenamePressed != null)
                              IconButton(
                                tooltip: 'Rename session',
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                onPressed: onRenamePressed,
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: context.colors.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: session.isFinished
                                ? context.customColors.success
                                : context.colors.primary,
                          ),
                          const SizedBox(width: 6),
                          if (session.isFinished)
                            Text('Progress: Finished')
                          else
                            Text(
                              'Progress: ${(session.currentIndex + 1)}/${session.cardCount}',
                              style: theme.textTheme.bodyMedium,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Created: ${formatSmartDate(session.createdAt)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _SessionAction { start, browse, saveAsSet, rename, reset, delete }

/// The session's options (instead of swiping the card).
class _SessionMenu extends StatelessWidget {
  final VoidCallback? onStart;
  final VoidCallback? onBrowse;
  final VoidCallback? onSaveAsSet;
  final VoidCallback? onRename;
  final VoidCallback? onReset;
  final VoidCallback? onDelete;

  const _SessionMenu({
    this.onStart,
    this.onBrowse,
    this.onSaveAsSet,
    this.onRename,
    this.onReset,
    this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this session?'),
        content: const Text('Your card progress is kept.'),
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
    if (ok == true) onDelete?.call();
  }

  @override
  Widget build(BuildContext context) {
    PopupMenuItem<_SessionAction> item(
      _SessionAction value,
      IconData icon,
      String label,
      VoidCallback? action,
    ) => PopupMenuItem(
      value: value,
      enabled: action != null,
      child: ListTile(leading: Icon(icon), title: Text(label)),
    );

    return SizedBox(
      width: 32,
      height: 28,
      child: PopupMenuButton<_SessionAction>(
        tooltip: 'Session options',
        padding: EdgeInsets.zero,
        iconSize: 22,
        icon: const Icon(Icons.more_vert),
        onSelected: (action) => switch (action) {
          _SessionAction.start => onStart?.call(),
          _SessionAction.browse => onBrowse?.call(),
          _SessionAction.saveAsSet => onSaveAsSet?.call(),
          _SessionAction.rename => onRename?.call(),
          _SessionAction.reset => onReset?.call(),
          _SessionAction.delete => _confirmDelete(context),
        },
        itemBuilder: (context) => [
          item(_SessionAction.start, Icons.play_arrow, 'Start', onStart),
          item(
            _SessionAction.browse,
            Icons.view_list,
            'Browse cards',
            onBrowse,
          ),
          item(
            _SessionAction.saveAsSet,
            Icons.collections_bookmark_outlined,
            'Save as set',
            onSaveAsSet,
          ),
          item(_SessionAction.rename, Icons.edit_outlined, 'Rename', onRename),
          item(_SessionAction.reset, Icons.refresh, 'Reset progress', onReset),
          item(_SessionAction.delete, Icons.delete_outline, 'Delete', onDelete),
        ],
      ),
    );
  }
}

class PreviousSessionsShimmer extends StatelessWidget {
  const PreviousSessionsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          _Card(),
          _Card(),
          _Card(),
          _Card(),
          _Card(),
          _Card(),
          _Card(),
          _Card(),
          _Card(),
          _Card(),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: context.colors.surfaceContainerHigh,
      child: Shimmer.fromColors(
        baseColor: shimmerBaseColor(context),
        highlightColor: shimmerHighlightColor(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TitlePlaceholder(width: 100, isTwoLine: false),
                  RoundedPlaceholder(fullyRounded: false, width: 40),
                ],
              ),

              const SizedBox(height: 45),

              ContentNoBannerPlaceholder(lineType: ContentLineType.twoLines),
            ],
          ),
        ),
      ),
    );
  }
}
