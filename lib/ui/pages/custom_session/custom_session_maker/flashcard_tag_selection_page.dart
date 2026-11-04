import 'package:auto_route/annotations.dart';
import 'package:flashcards/bloc/custom_session/session_tag_picker/session_tag_picker_cubit.dart';
import 'package:flashcards/bloc/custom_session/session_tag_picker/session_tag_picker_state.dart';
import 'package:flashcards/domain/models/flashcards/simple_pack/simple_pack.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/core/card_factory.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class FlashcardTagSelectionPage extends StatefulWidget {
  final List<SimplePack> packs;

  const FlashcardTagSelectionPage({super.key, required this.packs});

  @override
  State<FlashcardTagSelectionPage> createState() =>
      _FlashcardTagSelectionPageState();
}

class _FlashcardTagSelectionPageState extends State<FlashcardTagSelectionPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<SessionTagPickerCubit>().loadAllTags(widget.packs);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ReadableWidth(
        maxWidth: 820,
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: horizontalScreenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardFactory.info(
                  title: Text("Choose topics and tags"),
                  subtitle: Text(
                    "Topic: cards of any topic you choose. Tags: cards that "
                    "have ALL the tags you tick, e.g. Neoreview + 2025. "
                    "Tap ⊘ to leave out the cards with a tag. Choose nothing "
                    "to include every card.",
                  ),
                ),

                SizedBox(height: 16),

                BlocBuilder<SessionTagPickerCubit, SessionTagPickerState>(
                  builder: (context, state) {
                    switch (state) {
                      case SessionTagPickerInitial():
                        return Center(child: CircularProgressIndicator());
                      case SessionTagPickerLoaded(
                        :final allTagCounts,
                        :final selectedTags,
                      ):
                        if (allTagCounts.isEmpty) {
                          return Center(
                            child: Text(
                              "Looks like the packs you selected don't have "
                              "tags in them, you can skip this step.",
                            ),
                          );
                        }

                        final query = _query.trim().toLowerCase();
                        final topics = allTagCounts.entries
                            .where((e) => e.key.isTopic)
                            .toList();
                        final entries = allTagCounts.entries
                            .where(
                              (e) =>
                                  !e.key.isTopic &&
                                  (query.isEmpty ||
                                      e.key.name.toLowerCase().contains(query)),
                            )
                            .toList();
                        final selected = allTagCounts.keys
                            .where(
                              (tag) =>
                                  !tag.isTopic && selectedTags[tag.id] == true,
                            )
                            .toList();
                        final selectedTopics = allTagCounts.keys
                            .where(
                              (tag) =>
                                  tag.isTopic && selectedTags[tag.id] == true,
                            )
                            .toList();
                        final excluded = allTagCounts.keys
                            .where((tag) => selectedTags[tag.id] == false)
                            .toList();
                        final tagCount = allTagCounts.length - topics.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SelectionSummary(
                              selected: selected,
                              topics: selectedTopics,
                              excluded: excluded,
                            ),
                            SizedBox(height: 12),
                            if (topics.isNotEmpty) ...[
                              Text('Topic', style: context.text.titleMedium),
                              SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final topic in topics)
                                    FilterChip(
                                      label: Text(
                                        '${topic.key.topicName} '
                                        '(${topic.value})',
                                      ),
                                      selected:
                                          selectedTags[topic.key.id] == true,
                                      onSelected: (_) => context
                                          .read<SessionTagPickerCubit>()
                                          .toggleTag(topic.key),
                                    ),
                                ],
                              ),
                              SizedBox(height: 20),
                              if (tagCount > 0)
                                Text('Tags', style: context.text.titleMedium),
                              SizedBox(height: 4),
                            ],
                            if (tagCount > 8)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) =>
                                      setState(() => _query = value),
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.search),
                                    hintText: 'Search tags',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    isDense: true,
                                    suffixIcon: _query.isEmpty
                                        ? null
                                        : IconButton(
                                            tooltip: 'Clear search',
                                            icon: Icon(Icons.close),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _query = '');
                                            },
                                          ),
                                  ),
                                ),
                              ),
                            if (entries.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text('No tags match "$_query".'),
                              ),
                            ListView.builder(
                              primary: false,
                              shrinkWrap: true,
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final tagCount = entries[index];
                                return _TagCountItem(
                                  tagCount: tagCount,
                                  isSelected:
                                      selectedTags[tagCount.key.id] == true,
                                  isExcluded:
                                      selectedTags[tagCount.key.id] == false,
                                );
                              },
                            ),
                            SizedBox(height: 16),
                          ],
                        );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionSummary extends StatelessWidget {
  final List<Tag> selected;
  final List<Tag> topics;
  final List<Tag> excluded;

  const _SelectionSummary({
    required this.selected,
    required this.topics,
    required this.excluded,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SessionTagPickerCubit>();
    final others = [
      if (topics.isNotEmpty)
        _ChipLine(
          label: topics.length == 1 ? 'Topic:' : 'Any of these topics:',
          chips: [
            for (final topic in topics)
              InputChip(
                label: Text(topic.topicName),
                onDeleted: () => cubit.toggleTag(topic),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      if (excluded.isNotEmpty)
        _ChipLine(
          label: 'Leaving out cards with:',
          chips: [
            for (final tag in excluded)
              InputChip(
                avatar: Icon(
                  Icons.block,
                  size: 16,
                  color: context.colors.error,
                ),
                label: Text(tag.isTopic ? tag.topicName : tag.name),
                onDeleted: () => cubit.toggleExcluded(tag),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: selected.isEmpty && others.isEmpty
          ? Row(
              children: [
                Icon(Icons.all_inclusive, color: context.colors.primary),
                SizedBox(width: 10),
                Expanded(child: Text("No tags selected: all cards included")),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...others,
                if (selected.isEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: cubit.clearSelection,
                      child: Text("Clear"),
                    ),
                  ),
                if (selected.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selected.length == 1
                              ? "Cards tagged:"
                              : "Cards with all ${selected.length} tags:",
                          style: context.text.labelLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: cubit.clearSelection,
                        child: Text("Clear"),
                      ),
                    ],
                  ),
                if (selected.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < selected.length; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'AND',
                              style: context.text.labelSmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        InputChip(
                          label: Text(selected[i].name),
                          onDeleted: () => cubit.toggleTag(selected[i]),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
    );
  }
}

class _TagCountItem extends StatelessWidget {
  final MapEntry<Tag, int> tagCount;
  final bool isSelected;
  final bool isExcluded;

  const _TagCountItem({
    required this.tagCount,
    required this.isSelected,
    required this.isExcluded,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SessionTagPickerCubit>();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: isSelected,
        onChanged: (_) => cubit.toggleTag(tagCount.key),
      ),
      title: Text(
        tagCount.key.name,
        style: isExcluded
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: context.colors.error,
              )
            : null,
      ),
      subtitle: Text(
        isExcluded
            ? 'Left out · ${tagCount.value} flashcards'
            : '${tagCount.value} flashcards',
      ),
      onTap: () => cubit.toggleTag(tagCount.key),
      trailing: IconButton(
        tooltip: isExcluded ? 'Include these cards again' : 'Leave these out',
        isSelected: isExcluded,
        icon: const Icon(Icons.block),
        color: isExcluded ? context.colors.error : null,
        onPressed: () => cubit.toggleExcluded(tagCount.key),
      ),
    );
  }
}

/// A label with chips under it, in the selection summary.
class _ChipLine extends StatelessWidget {
  final String label;
  final List<Widget> chips;

  const _ChipLine({required this.label, required this.chips});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(label, style: context.text.labelLarge),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      ),
    );
  }
}
