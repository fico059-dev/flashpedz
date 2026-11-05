import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/custom_session/session_limit/session_limit_cubit.dart';
import 'package:flashcards/bloc/custom_session/session_limit/session_limit_state.dart';
import 'package:flashcards/bloc/custom_session/session_tag_picker/session_tag_picker_cubit.dart';
import 'package:flashcards/bloc/custom_session/session_tag_picker/session_tag_picker_state.dart';
import 'package:flashcards/domain/enums/pack_selected_filter.dart';
import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/domain/models/flashcards/simple_pack/simple_pack.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/core/bloc_buttons/bloc_button.dart';
import 'package:flashcards/ui/widgets/core/bloc_text_field.dart';
import 'package:flashcards/ui/widgets/core/card_factory.dart';
import 'package:flashcards/ui/widgets/core/loading_overlay_listener.dart';
import 'package:flashcards/ui/widgets/core/tag_chip.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flutter/material.dart';
import 'package:flashcards/bloc/custom_session/studied_filter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class FlashcardLimitPage extends StatefulWidget {
  final List<SimplePack> selectedPacks;
  final PackSelectedFilter filter;
  final int packFilterCount;
  final List<Tag> selectedTags;
  final bool isCountExact;

  const FlashcardLimitPage({
    super.key,
    required this.selectedPacks,
    required this.filter,
    required this.selectedTags,
    required this.packFilterCount,
    required this.isCountExact,
  });

  @override
  State<FlashcardLimitPage> createState() => _FlashcardLimitPageState();
}

class _FlashcardLimitPageState extends State<FlashcardLimitPage> {
  late final TextEditingController _countCont;
  final _nameCont = TextEditingController();

  /// The exact number of matching cards from the server (null while
  /// counting, or if it couldn't count).
  ({int allTags, int anyTag})? _exact;
  var _counting = true;
  var _matchAnyTag = false;

  /// The number the app put in the box; once the student types another,
  /// it is left alone.
  String? _autoCount;

  int? get _matching =>
      _exact == null ? null : (_matchAnyTag ? _exact!.anyTag : _exact!.allTags);

  StudiedCardsFilter get _studied => widget.filter == PackSelectedFilter.seen
      ? context.read<StudiedFilterNotifier>().value
      : StudiedCardsFilter.all;

  Future<void> _countExact() async {
    final picked = context.read<SessionTagPickerCubit>().state;
    final exact = await context.read<SessionLimitCubit>().countMatching(
      filter: widget.filter,
      selectedTags: widget.selectedTags.toIdList(),
      packIds: widget.selectedPacks.packIds,
      topics: picked.selectedTopics,
      excludeTags: picked.excludedTags,
      studied: _studied.requestValue,
    );
    if (!mounted) return;
    setState(() {
      _exact = exact;
      _counting = false;
    });
    _fillAll();
  }

  /// Puts every matching card in the box, unless the student typed a number.
  void _fillAll({bool force = false}) {
    final matching = _matching;
    if (matching == null) return;
    if (!force && _autoCount != null && _countCont.text != _autoCount) return;
    _autoCount = '${matching.clamp(0, maxExamCards)}';
    _countCont.text = _autoCount!;
  }

  void _countFlashcards() {
    context.read<SessionLimitCubit>().loadData(
      packFilterCount: widget.packFilterCount,
      isCountExact: widget.isCountExact,
      selectedTags: widget.selectedTags,
      filter: widget.filter,
      selectedPackNames: widget.selectedPacks.packNames,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _countFlashcards();
      _countExact();
    });
    _countCont = TextEditingController(text: widget.packFilterCount.toString());
    _autoCount = _countCont.text;
  }

  @override
  void dispose() {
    _countCont.dispose();
    _nameCont.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlayListener<SessionLimitCubit, SessionLimitState>(
      isLoading: (state) =>
          state is SessionLimitLoaded && state.status.isLoading,
      loadingText:
          "Creating your exam. This might take a while depending on "
          "how many cards it has",
      child: BlocListener<SessionLimitCubit, SessionLimitState>(
        listenWhen: (previous, current) =>
            current is SessionLimitLoaded && current.status.isSuccess ||
            current is SessionLimitLoaded && current.status.isError,
        listener: (context, state) {
          if (state is! SessionLimitLoaded) return;
          switch (state.status) {
            case SessionLimitStatus.error:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(extractErrorMessage(state.error!))),
              );
              return;
            case SessionLimitStatus.success:
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Exam created")));
              context.router.parent()?.pop();
              return;
            default:
          }
        },
        child: Scaffold(
          body: ReadableWidth(
            maxWidth: 820,
            child: SingleChildScrollView(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalScreenPadding,
                ),
                child: BlocBuilder<SessionLimitCubit, SessionLimitState>(
                  builder: (context, state) {
                    switch (state) {
                      case SessionLimitLoaded(
                        :final flashcardsCount,
                        :final isEstimatePrecise,
                      ):
                        return _LoadedContent(
                          flashcardsCount: flashcardsCount,
                          isEstimatePrecise: isEstimatePrecise,
                          filter: widget.filter,
                          selectedPacks: widget.selectedPacks,
                          selectedTags: widget.selectedTags,
                          countCont: _countCont,
                          nameCont: _nameCont,
                          packFilterCount: _matching ?? widget.packFilterCount,
                          counting: _counting,
                          matching: _matching,
                          exact: _exact,
                          matchAnyTag: _matchAnyTag,
                          onMatchAnyTag: (value) {
                            setState(() => _matchAnyTag = value);
                            _fillAll();
                          },
                          onUseAll: () => _fillAll(force: true),
                        );
                      default:
                        return SizedBox.shrink();
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadedContent extends StatelessWidget {
  final List<SimplePack> selectedPacks;
  final PackSelectedFilter filter;
  final List<Tag> selectedTags;
  final int flashcardsCount;
  final bool isEstimatePrecise;
  final TextEditingController countCont;
  final TextEditingController nameCont;
  final int packFilterCount;
  final bool counting;
  final int? matching;
  final ({int allTags, int anyTag})? exact;
  final bool matchAnyTag;
  final ValueChanged<bool> onMatchAnyTag;
  final VoidCallback onUseAll;

  const _LoadedContent({
    super.key,
    required this.counting,
    required this.matching,
    required this.exact,
    required this.matchAnyTag,
    required this.onMatchAnyTag,
    required this.onUseAll,
    required this.flashcardsCount,
    required this.isEstimatePrecise,
    required this.filter,
    required this.selectedTags,
    required this.selectedPacks,
    required this.countCont,
    required this.nameCont,
    required this.packFilterCount,
  });

  @override
  Widget build(BuildContext context) {
    final picked = context.read<SessionTagPickerCubit>().state;
    final studied = filter == PackSelectedFilter.seen
        ? context.read<StudiedFilterNotifier>().value
        : StudiedCardsFilter.all;
    final topics = picked.selectedTopics;
    final excluded = picked.excludedTags;
    final defaultName = defaultSessionName(
      topicNames: topics.map((id) => Tag.fromId(id).topicName).toList(),
      tagNames: selectedTags.map((tag) => tag.name).toList(),
      packNames: selectedPacks.packNames,
    );

    void onSubmit() {
      final typedName = nameCont.text.trim();
      context.read<SessionLimitCubit>().submitCustomSession(
        flashcardsCount: countCont.text,
        packFilterCount: packFilterCount,
        filter: filter,
        packIds: selectedPacks.packIds,
        selectedTags: selectedTags.toIdList(),
        topics: topics,
        excludeTags: excluded,
        studied: studied.requestValue,
        name: typedName.isEmpty ? defaultName : typedName,
        matchAnyTag: matchAnyTag,
      );
    }

    final matching = this.matching;
    final countText = matching != null
        ? "$matching flashcards match your choices. How many would you "
              "like in your exam?"
        : isEstimatePrecise
        ? "$flashcardsCount flashcards are available. How many "
              "would you like in your exam?"
        : "Up to $flashcardsCount flashcards are available. How many "
              "would you like in your exam?";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 15,
      children: [
        if (counting)
          Row(
            children: [
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text("Counting the cards that match…")),
            ],
          )
        else
          Text(
            countText,
            style: matching != null
                ? Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)
                : null,
          ),
        if (exact != null && selectedTags.length > 1)
          _TagMatchChoice(
            tagNames: selectedTags.map((tag) => tag.name).toList(),
            exact: exact!,
            matchAnyTag: matchAnyTag,
            onChanged: onMatchAnyTag,
          ),
        if (matching == 0)
          CardFactory.warning(
            isThreeLine: true,
            title: Text("No cards match."),
            subtitle: Text(
              selectedTags.length > 1 && !matchAnyTag
                  ? "No card has all of these tags. Choose \"Any of these "
                        "tags\", or go back and pick fewer tags."
                  : "Go back and choose other tags, topics or cards.",
            ),
          ),
        if (matching != null && matching > maxExamCards)
          Text(
            "An exam can have up to $maxExamCards cards, so it will have "
            "$maxExamCards of them, picked at random.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (!counting && matching == null && !isEstimatePrecise)
          CardFactory.warning(
            isThreeLine: true,
            title: Text("This number is an estimate."),
            subtitle: Text(
              "Fewer cards may match your topics and tags. The session will "
              "contain all the matching cards, up to your number.",
            ),
          ),

        TextField(
          controller: nameCont,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: "Exam name (optional)",
            hintText: defaultName,
            helperText: "Leave empty to use \"$defaultName\"",
            helperMaxLines: 2,
            border: OutlineInputBorder(),
          ),
        ),

        BlocTextField<SessionLimitCubit, SessionLimitState>(
          errorSelector: (state) =>
              state is SessionLimitLoaded && state.status.isFormInvalid
              ? state.formErrors['flashcardsCount']
              : null,
          labelText: "Number of flashcards for session",
          textEditingController: countCont,
        ),
        if (matching != null && matching > 0)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onUseAll,
              icon: const Icon(Icons.select_all),
              label: Text(
                "Use all ${matching > maxExamCards ? maxExamCards : matching}",
              ),
            ),
          ),

        _buildSectionTitle('Selected Packs'),
        Wrap(
          spacing: 3,
          runSpacing: 3,
          children: selectedPacks
              .map((pack) => TagChip(label: pack.packName))
              .toList(),
        ),
        SizedBox(),
        _buildSectionTitle('Pack Filter'),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            studied == StudiedCardsFilter.all
                ? filter.label
                : '${filter.label}: ${studied.label}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        SizedBox(),
        _buildSectionTitle('Selected Tags'),
        selectedTags.isEmpty
            ? Text(
                'No tags selected',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            : Wrap(
                spacing: 3,
                runSpacing: 3,
                children: selectedTags
                    .map((tag) => TagChip(label: tag.name))
                    .toList(),
              ),

        if (topics.isNotEmpty) ...[
          SizedBox(),
          _buildSectionTitle('Topic'),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              for (final id in topics) TagChip(label: Tag.fromId(id).topicName),
            ],
          ),
        ],
        if (excluded.isNotEmpty) ...[
          SizedBox(),
          _buildSectionTitle('Left Out'),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              for (final id in excluded) TagChip(label: Tag.fromId(id).name),
            ],
          ),
        ],

        SizedBox(height: 5),
        Center(
          child: BlocButton<SessionLimitCubit, SessionLimitState>(
            showSpinner: false,
            textString: "Create exam",
            onPressed: (context) => onSubmit(),
            isLoadingState: (state) =>
                state is SessionLimitLoaded && state.status.isLoading,
          ),
        ),
      ],
    );
  }
}

Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}

/// All of the chosen tags, or any of them, with how many cards each gives.
class _TagMatchChoice extends StatelessWidget {
  final List<String> tagNames;
  final ({int allTags, int anyTag}) exact;
  final bool matchAnyTag;
  final ValueChanged<bool> onChanged;

  const _TagMatchChoice({
    required this.tagNames,
    required this.exact,
    required this.matchAnyTag,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = tagNames.length > 3
        ? '${tagNames.take(3).join(', ')}…'
        : tagNames.join(matchAnyTag ? ' or ' : ' and ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: false,
              label: Text('All these tags (${exact.allTags})'),
            ),
            ButtonSegment(
              value: true,
              label: Text('Any of these tags (${exact.anyTag})'),
            ),
          ],
          selected: {matchAnyTag},
          onSelectionChanged: (value) => onChanged(value.first),
        ),
        Text(
          matchAnyTag
              ? 'Cards with at least one tag: $names.'
              : 'Only cards that have every tag: $names.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
