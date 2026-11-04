import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flashcards/ui/widgets/core/tag_chip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class TagInput extends StatefulWidget {
  final List<Tag> suggestedTags;
  final List<Tag> selectedTags;
  final void Function(Tag tag)? onTagAdded;
  final void Function(Tag tag)? onTagRemoved;

  const TagInput({
    super.key,
    required this.suggestedTags,
    required this.selectedTags,
    this.onTagAdded,
    this.onTagRemoved,
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final TextEditingController _textController = TextEditingController();
  String? _errorText;
  static const int _maxTagLength = 15;

  void _addTag(String rawTag) {
    final tag = Tag.fromName(rawTag);
    if (tag.id.isEmpty) return;

    if (tag.id.length > _maxTagLength) {
      setState(() {
        _errorText = 'Tag too long (max $_maxTagLength characters)';
      });
      return;
    }

    final alreadySelected = widget.selectedTags.any((t) => t == tag);
    if (!alreadySelected) {
      setState(() {
        _errorText = null;
      });
      widget.onTagAdded?.call(tag);
    }

    _textController.clear();
  }

  void _removeTag(Tag tag) {
    widget.onTagRemoved?.call(tag);
  }

  /// A card has one topic: choosing one replaces the previous.
  void _setTopic(String name) {
    for (final old in widget.selectedTags.where((t) => t.isTopic).toList()) {
      widget.onTagRemoved?.call(old);
    }
    if (name.trim().isNotEmpty) widget.onTagAdded?.call(Tag.topic(name));
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.selectedTags.where((t) => t.isTopic).firstOrNull;
    return Column(
      children: [
        _TopicField(
          topic: topic,
          suggestions: widget.suggestedTags.where((t) => t.isTopic).toList(),
          onChanged: _setTopic,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 5,
          children: widget.selectedTags
              .where((tag) => !tag.isTopic)
              .map(
                (tag) =>
                    TagChip(label: tag.name, onDeleted: () => _removeTag(tag)),
                // (tag) => Chip(
                //   backgroundColor: Colors.indigo[50],
                //   label: Text(tag.name),
                //   onDeleted: () => _removeTag(tag),
                // ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        RawAutocomplete<Tag>(
          textEditingController: _textController,
          focusNode: FocusNode(),
          optionsBuilder: (TextEditingValue textEditingValue) {
            final input = textEditingValue.text.trim().toLowerCase();
            if (input.isEmpty) return const Iterable<Tag>.empty();

            return widget.suggestedTags.where(
              (tag) => !tag.isTopic && tag.name.toLowerCase().contains(input),
            );
          },
          displayStringForOption: (Tag tag) => tag.name,
          onSelected: (Tag selection) {
            _addTag(selection.name);
          },
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      CupertinoIcons.tag,
                      color: Colors.grey,
                      size: 22,
                    ),
                    labelText: 'Enter tags (optional)',
                    border: const OutlineInputBorder(),
                    errorText: _errorText,
                  ),
                  onSubmitted: _addTag,
                  onChanged: (value) {
                    if (_errorText != null && value.length <= _maxTagLength) {
                      setState(() {
                        _errorText = null;
                      });
                    }
                  },
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    shrinkWrap: true,
                    itemBuilder: (BuildContext context, int index) {
                      final Tag option = options.elementAt(index);
                      return ListTile(
                        title: Text(option.name),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The card's topic (e.g. Cardiology), used to make custom sessions by
/// topic. Existing topics are suggested while typing.
class _TopicField extends StatefulWidget {
  final Tag? topic;
  final List<Tag> suggestions;
  final ValueChanged<String> onChanged;

  const _TopicField({
    required this.topic,
    required this.suggestions,
    required this.onChanged,
  });

  @override
  State<_TopicField> createState() => _TopicFieldState();
}

class _TopicFieldState extends State<_TopicField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  static const _maxLength = 30;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _choose(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    widget.onChanged(
      trimmed.length > _maxLength ? trimmed.substring(0, _maxLength) : trimmed,
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final topic = widget.topic;
    if (topic != null) {
      return Row(
        children: [
          const Icon(Icons.category_outlined, color: Colors.grey, size: 22),
          const SizedBox(width: 10),
          Text('Topic', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 10),
          Flexible(
            child: InputChip(
              label: Text(topic.topicName),
              onDeleted: () => widget.onChanged(''),
            ),
          ),
        ],
      );
    }
    return RawAutocomplete<Tag>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final input = value.text.trim().toLowerCase();
        return widget.suggestions.where(
          (tag) => input.isEmpty || tag.topicName.toLowerCase().contains(input),
        );
      },
      displayStringForOption: (tag) => tag.topicName,
      onSelected: (tag) => _choose(tag.topicName),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          maxLength: _maxLength,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            prefixIcon: Icon(
              Icons.category_outlined,
              color: Colors.grey,
              size: 22,
            ),
            labelText: 'Topic (optional), e.g. Cardiology',
            helperText: 'Students can examine themselves on one topic.',
            border: OutlineInputBorder(),
            counterText: '',
          ),
          onSubmitted: _choose,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 400),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      title: Text(option.topicName),
                      onTap: () => onSelected(option),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
