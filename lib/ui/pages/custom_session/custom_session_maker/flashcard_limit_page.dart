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
    WidgetsBinding.instance.addPostFrameCallback((_) => _countFlashcards());
    _countCont = TextEditingController(text: widget.packFilterCount.toString());
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
                          packFilterCount: widget.packFilterCount,
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

  const _LoadedContent({
    super.key,
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
      );
    }

    final countText = isEstimatePrecise
        ? "$flashcardsCount flashcards are available. How many "
              "would you like in your exam?"
        : "Up to $flashcardsCount flashcards are available. How many "
              "would you like in your exam?";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 15,
      children: [
        Text(countText),
        if (!isEstimatePrecise)
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
