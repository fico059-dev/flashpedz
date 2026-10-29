import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/flashcards/create_flashcard/create_flashcard_cubit.dart';
import 'package:flashcards/bloc/flashcards/create_flashcard/create_flashcard_state.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/repositories/flashcards/tag_repository.dart';
import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/ui/constants/styles.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/core/bloc_text_field.dart';
import 'package:flashcards/ui/widgets/core/card_factory.dart';
import 'package:flashcards/ui/widgets/core/images/image_picker_button.dart';
import 'package:flashcards/ui/widgets/core/loading_overlay_listener.dart';
import 'package:flashcards/ui/widgets/profile/admin_dashboard/cloze_context_menu_builder.dart';
import 'package:flashcards/ui/widgets/profile/admin_dashboard/flashcard_builder/tag_input.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/ui/widgets/core/desktop_layout.dart';
import 'package:flashcards/ui/pages/profile/admin_dashboard/flashcard_builder/image_occlusion_page.dart';
import 'package:flashcards/ui/widgets/profile/admin_dashboard/flashcard_builder/card_format_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class CreateFlashcardPage extends StatelessWidget {
  final AdminPack pack;

  const CreateFlashcardPage({super.key, required this.pack});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CreateFlashcardCubit(
        flashcardRepo: context.read<FlashcardRepository>(),
        tagRepo: context.read<TagRepository>(),
      ),
      child: _View(pack: pack),
    );
  }
}

class _View extends StatefulWidget {
  final AdminPack pack;

  const _View({super.key, required this.pack});

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  late final TextEditingController _questionCont;
  late final TextEditingController _answerCont;

  @override
  void initState() {
    super.initState();
    context.read<CreateFlashcardCubit>().getAllAvailableTags();
    _questionCont = TextEditingController();
    _answerCont = TextEditingController();
  }

  @override
  void dispose() {
    _questionCont.dispose();
    _answerCont.dispose();
    super.dispose();
  }

  void _onSubmit(String buttonType) {
    context.read<CreateFlashcardCubit>().createFlashcardAndAssignToPack(
      question: _questionCont.text,
      answer: _answerCont.text,
      packId: widget.pack.packId,
      buttonType: buttonType,
    );
  }

  void _onImageError(Exception error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(extractErrorMessage(error))));
  }

  void _onFcPreview() {
    final fc = context.read<CreateFlashcardCubit>().generateFlashcardObject(
      _questionCont.text,
      _answerCont.text,
      widget.pack.packId,
    );
    if (fc == null) return;

    final state = context.read<CreateFlashcardCubit>().state;
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
    return LoadingOverlayListener<CreateFlashcardCubit, CreateFlashcardState>(
      isLoading: (state) => state.status.isLoading,
      child: BlocListener<CreateFlashcardCubit, CreateFlashcardState>(
        listenWhen: (previous, current) =>
            current.status.isSuccess || current.status.isError,
        listener: (context, state) {
          switch (state.status) {
            case CreateFlashcardStatus.success:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: RichText(
                    text: TextSpan(
                      style: TextStyle(color: context.colors.onInverseSurface),
                      children: [
                        TextSpan(text: "Successfully added flashcard to pack."),
                        TextSpan(
                          text: widget.pack.packName,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              if (state.shouldExit) {
                context.router.pop();
              }
              _questionCont.clear();
              _answerCont.clear();
              break;
            case CreateFlashcardStatus.error:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(extractErrorMessage(state.error!))),
              );
              break;
            default:
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text("Create Flashcard"),
            leading: IconButton(
              onPressed: () => context.router.pop(),
              icon: Icon(Icons.arrow_back),
            ),
            actions: [
              IconButton(
                tooltip: "Image occlusion cards",
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final made = await openImageOcclusionEditor(
                    context,
                    widget.pack,
                  );
                  if (made == null) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        "Made $made image occlusion card${made == 1 ? '' : 's'} "
                        "in ${widget.pack.packName}.",
                      ),
                    ),
                  );
                },
                icon: Icon(Icons.layers_outlined),
              ),
              IconButton(
                onPressed: _onFcPreview,
                icon: Icon(Icons.remove_red_eye),
              ),
            ],
          ),
          body: ReadableWidth(
            maxWidth: 820,
            child: SingleChildScrollView(
              child: Container(
                margin: EdgeInsets.only(top: 20),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalScreenPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 10,
                  children: [
                    CardFactory.info(
                      title: Text("Cloze deletion"),
                      subtitle: Text(
                        'Select text then click "cloze deletion" in order to make it a cloze.',
                      ),
                      closable: true,
                    ),
                    Text("Currently adding to pack"),
                    Text(
                      widget.pack.packName,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(),
                    Row(
                      children: [
                        Text("Question Image: "),
                        BlocBuilder<CreateFlashcardCubit, CreateFlashcardState>(
                          builder: (context, state) {
                            return ImagePickerButton(
                              onError: _onImageError,
                              label: "Question",
                              imageData: state.questionImageData,
                              onImageChanged: (pickedImage) => context
                                  .read<CreateFlashcardCubit>()
                                  .questionImageChanged(pickedImage),
                            );
                          },
                        ),
                      ],
                    ),

                    CardFormatToolbar(controller: _questionCont),
                    BlocTextField<CreateFlashcardCubit, CreateFlashcardState>(
                      contextMenuBuilder: (context, editableTextState) =>
                          clozeContextMenuBuilder(
                            context,
                            editableTextState,
                            _questionCont,
                          ),
                      textEditingController: _questionCont,
                      minLines: 3,
                      maxLines: 10,
                      errorSelector: (state) => state.status.isFromInvalid
                          ? state.formErrors['question']
                          : null,
                      labelText: "Question",
                    ),
                    CardMarkupPreview(controller: _questionCont),

                    SizedBox(),

                    Row(
                      children: [
                        Text("Answer Image: "),
                        BlocBuilder<CreateFlashcardCubit, CreateFlashcardState>(
                          builder: (context, state) {
                            return ImagePickerButton(
                              onError: _onImageError,
                              label: "Answer",
                              imageData: state.answerImageData,
                              onImageChanged: (pickedImage) => context
                                  .read<CreateFlashcardCubit>()
                                  .answerImageChanged(pickedImage),
                            );
                          },
                        ),
                      ],
                    ),
                    CardFormatToolbar(controller: _answerCont),
                    BlocTextField<CreateFlashcardCubit, CreateFlashcardState>(
                      textEditingController: _answerCont,
                      minLines: 3,
                      maxLines: 10,
                      errorSelector: (state) => state.status.isFromInvalid
                          ? state.formErrors['answer']
                          : null,
                      labelText: "Answer",
                    ),
                    CardMarkupPreview(controller: _answerCont),

                    SizedBox(height: 10),
                    BlocBuilder<CreateFlashcardCubit, CreateFlashcardState>(
                      builder: (context, state) {
                        if (state.status.isTagsLoading ||
                            state.allAvailableTags == null) {
                          return Center(child: CircularProgressIndicator());
                        }

                        return TagInput(
                          suggestedTags: state.allAvailableTags!,
                          selectedTags: state.selectedTags,
                          onTagAdded: context
                              .read<CreateFlashcardCubit>()
                              .addTag,
                          onTagRemoved: context
                              .read<CreateFlashcardCubit>()
                              .removeTag,
                        );
                      },
                    ),

                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 10,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _onSubmit('secondary'),
                            child: Text("Add and Return"),
                          ),
                        ),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _onSubmit('main'),
                            child: Text("Add Flashcard"),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
