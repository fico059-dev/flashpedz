import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/flashcards/update_flashcard/update_flashcard_cubit.dart';
import 'package:flashcards/bloc/flashcards/update_flashcard/update_flashcard_state.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/tag_repository.dart';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/widgets/core/bloc_buttons/bloc_button.dart';
import 'package:flashcards/ui/widgets/core/custom_drag_handle.dart';
import 'package:flashcards/ui/widgets/core/images/image_picker_button.dart';
import 'package:flashcards/ui/widgets/core/loading_overlay_listener.dart';
import 'package:flashcards/ui/widgets/profile/admin_dashboard/flashcard_builder/tag_input.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/ui/pages/profile/admin_dashboard/flashcard_builder/image_occlusion_page.dart';
import 'package:flashcards/ui/widgets/editor/rich_card_editor_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<bool?> showUpdateFlashcardBottomSheet(
  BuildContext context,
  Flashcard flashcard,
) async {
  return await showModalBottomSheet(
    isScrollControlled: true,
    context: context,
    shape: bottomSheetShape,
    builder: (context) {
      return BlocProvider(
        create: (context) => UpdateFlashcardCubit(
          flashcardRepo: context.read<FlashcardRepository>(),
          tagRepo: context.read<TagRepository>(),
          initialFlashcard: flashcard,
        ),
        child: _UpdateForm(flashcard: flashcard),
      );
    },
  );
}

class _UpdateForm extends StatefulWidget {
  final Flashcard flashcard;

  const _UpdateForm({super.key, required this.flashcard});

  @override
  State<_UpdateForm> createState() => _UpdateFormState();
}

class _UpdateFormState extends State<_UpdateForm> {
  late final TextEditingController _questionCont;
  late final TextEditingController _answerCont;

  @override
  void initState() {
    super.initState();
    context.read<UpdateFlashcardCubit>().getAllAvailableTags(
      widget.flashcard.tags,
    );
    _questionCont = TextEditingController(text: widget.flashcard.question);
    _answerCont = TextEditingController(text: widget.flashcard.answer);
  }

  void _onImageError(Exception error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(extractErrorMessage(error))));
  }

  @override
  void dispose() {
    _questionCont.dispose();
    _answerCont.dispose();
    super.dispose();
  }

  /// Image occlusion for this card: edits its boxes, or turns it into an
  /// image-occlusion card with a new image.
  Future<void> _editOcclusion() async {
    final existing = [
      ...parseCardMarkup(_questionCont.text),
    ].whereType<OcclusionBlock>().firstOrNull;
    final result = await openOcclusionForCard(context, existing: existing);
    if (result == null || !mounted) return;
    String put(String text, String line, {required bool first}) {
      final lines = text.split('\n');
      final at = lines.indexWhere(
        (l) => parseCardMarkup(l).firstOrNull is OcclusionBlock,
      );
      if (at >= 0) {
        lines[at] = line;
        return lines.join('\n');
      }
      if (text.trim().isEmpty) return line;
      return first ? '$line\n$text' : '$text\n$line';
    }

    _questionCont.text = put(
      _questionCont.text,
      occlusionLine(
        url: result.url,
        masks: result.masks,
        target: result.target,
      ),
      first: false,
    );
    _answerCont.text = put(
      _answerCont.text,
      occlusionLine(
        url: result.url,
        masks: result.masks,
        target: result.target,
        revealed: true,
      ),
      first: true,
    );
  }

  void _onFcPreview() {
    final fc = context.read<UpdateFlashcardCubit>().generateFlashcardObject(
      _questionCont.text,
      _answerCont.text,
      widget.flashcard.packId,
    );
    if (fc == null) return;

    final state = context.read<UpdateFlashcardCubit>().state;
    context.router.push(
      FlashcardPreviewRoute(
        flashcard: fc,
        questionImageData: state.questionImageData,
        answerImageData: state.answerImageData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlayListener<UpdateFlashcardCubit, UpdateFlashcardState>(
      isLoading: (state) => state.status.isLoading,
      child: BlocListener<UpdateFlashcardCubit, UpdateFlashcardState>(
        listener: (context, state) {
          switch (state.status) {
            case UpdateFlashcardStatus.successful:
              context.router.pop(true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Successfully updated the flashcard")),
              );
              break;
            case UpdateFlashcardStatus.error:
              context.router.pop(false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(extractErrorMessage(state.error!))),
              );
              break;
            case UpdateFlashcardStatus.tagInputError:
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Max 10 tags")));
              break;
            default:
          }
        },
        child: Padding(
          padding: bottomSheetPaddingNoBot.copyWith(
            bottom:
                bottomSheetPaddingNoBot.bottom +
                MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            minChildSize: 0.3,
            builder: (context, scrollController) {
              return Column(
                children: [
                  CustomDragHandle(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Change Flashcard",
                        style: TextTheme.of(context).titleLarge?.merge(
                          TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),

                      IconButton(
                        onPressed: _onFcPreview,
                        icon: Icon(Icons.remove_red_eye),
                      ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        Column(
                          children: [
                            Column(
                              spacing: 7,
                              children: [
                                Row(
                                  children: [
                                    Text("Question Image: "),
                                    BlocBuilder<
                                      UpdateFlashcardCubit,
                                      UpdateFlashcardState
                                    >(
                                      builder: (context, state) {
                                        return ImagePickerButton(
                                          onError: _onImageError,
                                          label: "Question",
                                          imageData: state.questionImageData,
                                          onImageChanged: (pickedImage) =>
                                              context
                                                  .read<UpdateFlashcardCubit>()
                                                  .questionImageChanged(
                                                    pickedImage,
                                                  ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                BlocSelector<
                                  UpdateFlashcardCubit,
                                  UpdateFlashcardState,
                                  String?
                                >(
                                  selector: (state) =>
                                      state.status.isFormInvalid
                                      ? state.formErrors['question']
                                      : null,
                                  builder: (context, error) =>
                                      RichCardEditorLoader(
                                        controller: _questionCont,
                                        label: 'Question',
                                        errorText: error,
                                        extraActions: [
                                          IconButton(
                                            tooltip:
                                                'Image occlusion: hide parts of '
                                                'an image',
                                            visualDensity:
                                                VisualDensity.compact,
                                            iconSize: 20,
                                            onPressed: _editOcclusion,
                                            icon: const Icon(
                                              Icons.layers_outlined,
                                            ),
                                          ),
                                        ],
                                      ),
                                ),

                                SizedBox(),

                                Row(
                                  children: [
                                    Text("Answer Image: "),
                                    BlocBuilder<
                                      UpdateFlashcardCubit,
                                      UpdateFlashcardState
                                    >(
                                      builder: (context, state) {
                                        return ImagePickerButton(
                                          onError: _onImageError,
                                          label: "Answer",
                                          imageData: state.answerImageData,
                                          onImageChanged: (pickedImage) =>
                                              context
                                                  .read<UpdateFlashcardCubit>()
                                                  .answerImageChanged(
                                                    pickedImage,
                                                  ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                BlocSelector<
                                  UpdateFlashcardCubit,
                                  UpdateFlashcardState,
                                  String?
                                >(
                                  selector: (state) =>
                                      state.status.isFormInvalid
                                      ? state.formErrors['answer']
                                      : null,
                                  builder: (context, error) =>
                                      RichCardEditorLoader(
                                        controller: _answerCont,
                                        label: 'Answer',
                                        errorText: error,
                                      ),
                                ),
                                SizedBox(),

                                BlocBuilder<
                                  UpdateFlashcardCubit,
                                  UpdateFlashcardState
                                >(
                                  builder: (context, state) {
                                    if (state.status.isTagsLoading ||
                                        state.allAvailableTags == null) {
                                      return Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    }

                                    return TagInput(
                                      suggestedTags: state.allAvailableTags!,
                                      selectedTags: state.selectedTags,
                                      onTagAdded: context
                                          .read<UpdateFlashcardCubit>()
                                          .addTag,
                                      onTagRemoved: context
                                          .read<UpdateFlashcardCubit>()
                                          .removeTag,
                                    );
                                  },
                                ),

                                SizedBox(height: 30),
                                BlocButton<
                                  UpdateFlashcardCubit,
                                  UpdateFlashcardState
                                >(
                                  textString: 'Update',
                                  onPressed: (blocContext) {
                                    blocContext
                                        .read<UpdateFlashcardCubit>()
                                        .updateFlashcard(
                                          flashcardId: widget.flashcard.id,
                                          question: _questionCont.text,
                                          answer: _answerCont.text,
                                          packId: widget.flashcard.packId,
                                        );
                                  },
                                  isLoadingState: (state) =>
                                      state.status.isLoading,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // child: Padding(
        //   padding: bottomSheetPadding,
        //   child: Wrap(
        //     children: [
        //
        //     ],
        //   ),
        // ),
      ),
    );
  }
}
