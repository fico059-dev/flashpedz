import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/core/subs_status_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flashcards/bloc/custom_session/pack_picker/pack_picker_bloc.dart';
import 'package:flashcards/bloc/custom_session/pack_picker/pack_picker_event.dart';
import 'package:flashcards/domain/models/flashcards/simple_pack/simple_pack.dart';

class PackSelectionCard extends StatelessWidget {
  final SimplePack pack;
  final bool selected;
  final bool? hasCards;

  const PackSelectionCard({
    super.key,
    required this.pack,
    required this.selected,
    required this.hasCards,
  });

  @override
  Widget build(BuildContext context) {
    void onTapHandler() {
      context.read<PackPickerBloc>().add(PackPickerPackToggled(pack: pack));
    }

    final Color borderColor = selected
        ? context.colors.primary
        : Colors.transparent;

    final Color bgColor = selected
        ? context.colors.primaryContainer.withAlpha(60)
        : context.colors.surfaceContainerHigh;

    return GestureDetector(
      onTap: onTapHandler,
      child: AnimatedContainer(
        margin: EdgeInsets.only(bottom: 12),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: EdgeInsetsDirectional.only(
          start: 16.0,
          end: 24.0,
          top: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                pack.packName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: selected
                      ? context.colors.primary
                      : context.colors.onSurface,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Row(
              children: [
                SubsStatusIcon(
                  isPaid: pack.isPaid,
                  hasAccess: hasCards,
                  disableFreeIcon: true,
                ),
                const SizedBox(width: 6),
                Text(
                  "${pack.flashcardsCount}",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: context.colors.primary,
                      size: 20,
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
