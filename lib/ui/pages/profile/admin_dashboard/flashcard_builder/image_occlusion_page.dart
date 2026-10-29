import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flashcards/bloc/flashcards/create_flashcard/create_flashcard_cubit.dart';
import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/data/utils/image_compression.dart';
import 'package:flashcards/domain/models/flashcards/admin_pack/admin_pack.dart';
import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/ui/widgets/flashcard/card_content.dart';
import 'package:flashcards/utils/firebase_error_mapper.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the image-occlusion editor for [pack]. Returns how many cards were
/// made.
Future<int?> openImageOcclusionEditor(BuildContext context, AdminPack pack) {
  final cubit = context.read<CreateFlashcardCubit>();
  return Navigator.of(context).push<int>(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: ImageOcclusionPage(pack: pack),
      ),
    ),
  );
}

/// Opens the image-occlusion editor for one card being edited: its image
/// and boxes ([existing]), or a new image. Returns the image, the boxes and
/// the box this card asks about.
Future<OcclusionBlock?> openOcclusionForCard(
  BuildContext context, {
  OcclusionBlock? existing,
}) {
  return Navigator.of(context).push<OcclusionBlock>(
    MaterialPageRoute(builder: (_) => ImageOcclusionPage(editing: existing)),
  );
}

/// Image occlusion, like in Anki: pick an image, draw boxes over the parts
/// to learn, and a card is made for each box.
///
/// With [pack] the cards are made in that pack. Without one it edits a
/// single card: the selected box is the one the card asks about, and the
/// page returns the result instead.
class ImageOcclusionPage extends StatefulWidget {
  final AdminPack? pack;

  /// The card's image and boxes, when editing a card.
  final OcclusionBlock? editing;

  /// An image to start with (tests and screenshots).
  @visibleForTesting
  final (Uint8List, Size)? initialImage;

  const ImageOcclusionPage({
    super.key,
    this.pack,
    this.editing,
    this.initialImage,
  });

  @override
  State<ImageOcclusionPage> createState() => _ImageOcclusionPageState();
}

class _ImageOcclusionPageState extends State<ImageOcclusionPage> {
  Uint8List? _image;

  /// The card's image online, when editing a card and no new image was
  /// picked.
  String? _imageUrl;
  Size? _imageSize;
  ImageStream? _sizeStream;
  ImageStreamListener? _sizeListener;

  bool get _editingCard => widget.pack == null;
  final _masks = <OcclusionMask>[];
  int? _selected;
  OcclusionMask? _drawing;
  Offset? _drawStart;
  bool _saving = false;
  bool _picking = false;
  final _prompt = TextEditingController(text: 'What is hidden?');
  final _extra = TextEditingController();

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage?.$1;
    _imageSize = widget.initialImage?.$2;
    final editing = widget.editing;
    if (editing != null && _image == null) {
      _imageUrl = editing.url;
      _masks.addAll(editing.masks);
      _selected = editing.masks.isEmpty
          ? null
          : editing.target.clamp(0, editing.masks.length - 1);
      _loadSize(editing.url);
    }
  }

  /// The online image's size, to draw its boxes in the right places.
  void _loadSize(String url) {
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        setState(
          () => _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          ),
        );
      },
      onError: (error, _) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("The card's image couldn't be loaded.")),
        );
      },
    );
    stream.addListener(listener);
    _sizeStream = stream;
    _sizeListener = listener;
  }

  @override
  void dispose() {
    if (_sizeListener != null) _sizeStream?.removeListener(_sizeListener!);
    _prompt.dispose();
    _extra.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _picking = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final bytes = picked?.files.single.bytes;
      if (bytes == null) return;
      final jpeg = await prepareJpeg(bytes, maxSide: 2000);
      if (jpeg == null) throw Exception("This image couldn't be read.");
      final codec = await ui.instantiateImageCodec(jpeg);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _image = jpeg;
        _imageUrl = null;
        _imageSize = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
        _masks.clear();
        _selected = null;
      });
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Image not added: ${extractErrorMessage(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Offset _fraction(Offset local, Size shown) => Offset(
    (local.dx / shown.width).clamp(0.0, 1.0),
    (local.dy / shown.height).clamp(0.0, 1.0),
  );

  int? _maskAt(Offset point) {
    for (var i = _masks.length - 1; i >= 0; i--) {
      final m = _masks[i];
      if (point.dx >= m.x &&
          point.dx <= m.x + m.w &&
          point.dy >= m.y &&
          point.dy <= m.y + m.h) {
        return i;
      }
    }
    return null;
  }

  void _startDrawing(Offset local, Size shown) {
    _drawStart = _fraction(local, shown);
  }

  void _updateDrawing(Offset local, Size shown) {
    final start = _drawStart;
    if (start == null) return;
    final end = _fraction(local, shown);
    setState(() {
      _drawing = OcclusionMask(
        min(start.dx, end.dx),
        min(start.dy, end.dy),
        (start.dx - end.dx).abs(),
        (start.dy - end.dy).abs(),
      );
    });
  }

  void _endDrawing() {
    final mask = _drawing;
    setState(() {
      // Tiny boxes are slips, not boxes.
      if (mask != null && mask.w > 0.015 && mask.h > 0.015) {
        _masks.add(mask);
        _selected = _masks.length - 1;
      }
      _drawing = null;
      _drawStart = null;
    });
  }

  /// Editing a card: gives back the image, the boxes and the asked box.
  Future<void> _useForCard() async {
    final target = _selected;
    if (_masks.isEmpty || target == null) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final image = _image;
      final url = image != null
          ? await CloudFunctionService().uploadCardImage(base64Encode(image))
          : _imageUrl!;
      navigator.pop(
        OcclusionBlock(
          url: url,
          masks: List.of(_masks),
          target: target,
          revealed: false,
        ),
      );
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Image not saved: ${extractErrorMessage(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _create() async {
    if (_editingCard) return _useForCard();
    final image = _image;
    if (image == null || _masks.isEmpty) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final url = await CloudFunctionService().uploadCardImage(
        base64Encode(image),
      );
      if (!mounted) return;
      final result = await context
          .read<CreateFlashcardCubit>()
          .createOcclusionCards(
            packId: widget.pack!.packId,
            imageUrl: url,
            masks: List.of(_masks),
            prompt: _prompt.text,
            extra: _extra.text,
          );
      switch (result) {
        case Ok<int>(:final value):
          navigator.pop(value);
        case Error<int>(:final error):
          messenger.showSnackBar(
            SnackBar(content: Text(extractErrorMessage(error))),
          );
      }
    } on Exception catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Cards not made: ${extractErrorMessage(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _canvas(BoxConstraints constraints) {
    final size = _imageSize!;
    final scale = min(
      constraints.maxWidth / size.width,
      constraints.maxHeight / size.height,
    );
    final shown = Size(size.width * scale, size.height * scale);
    return Center(
      child: SizedBox.fromSize(
        size: shown,
        child: GestureDetector(
          // The box starts where the finger first touched.
          dragStartBehavior: DragStartBehavior.down,
          onTapUp: (d) => setState(
            () => _selected = _maskAt(_fraction(d.localPosition, shown)),
          ),
          onPanStart: (d) => _startDrawing(d.localPosition, shown),
          onPanUpdate: (d) => _updateDrawing(d.localPosition, shown),
          onPanEnd: (_) => _endDrawing(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _image != null
                  ? Image.memory(_image!, fit: BoxFit.fill)
                  : Image.network(_imageUrl!, fit: BoxFit.fill),
              CustomPaint(
                painter: _EditorPainter(
                  masks: _masks,
                  selected: _selected,
                  drawing: _drawing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _image != null || _imageUrl != null;
    if (hasImage && _imageSize == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Image occlusion')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final count = _masks.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image occlusion'),
        actions: [
          if (hasImage)
            IconButton(
              tooltip: 'Another image',
              onPressed: _saving ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: !hasImage
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers_outlined, size: 56),
                      const SizedBox(height: 12),
                      const Text(
                        'Pick an image (a diagram, an X-ray, a chart), then '
                        'draw boxes over the parts to learn. A card is made '
                        'for every box: it hides that part (orange) and the '
                        'answer shows it.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _picking ? null : _pickImage,
                        icon: _picking
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Pick an image'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Drag on the image to draw a box. Tap a box to select '
                      'it.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: LayoutBuilder(builder: (_, c) => _canvas(c)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('$count box${count == 1 ? '' : 'es'}'),
                        TextButton.icon(
                          onPressed: _selected == null
                              ? null
                              : () => setState(() {
                                  _masks.removeAt(_selected!);
                                  _selected = null;
                                }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete box'),
                        ),
                        TextButton.icon(
                          onPressed: _masks.isEmpty
                              ? null
                              : () => setState(() {
                                  _masks.removeLast();
                                  _selected = null;
                                }),
                          icon: const Icon(Icons.undo),
                          label: const Text('Undo'),
                        ),
                      ],
                    ),
                  ),
                  if (_editingCard)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(
                        _selected == null
                            ? 'Tap the box this card should ask about.'
                            : 'This card asks about box ${_selected! + 1} '
                                  '(orange); the others stay hidden.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _prompt,
                              decoration: const InputDecoration(
                                labelText: 'Question text (optional)',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _extra,
                              decoration: const InputDecoration(
                                labelText: 'Extra on the answer (optional)',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed:
                          count == 0 ||
                              _saving ||
                              (_editingCard && _selected == null)
                          ? null
                          : _create,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        count == 0
                            ? 'Draw at least one box'
                            : _editingCard
                            ? 'Use for this card'
                            : 'Make $count card${count == 1 ? '' : 's'}',
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The boxes while editing: numbered, the selected one outlined.
class _EditorPainter extends CustomPainter {
  final List<OcclusionMask> masks;
  final int? selected;
  final OcclusionMask? drawing;

  _EditorPainter({required this.masks, this.selected, this.drawing});

  Rect _rect(OcclusionMask m, Size size) => Rect.fromLTWH(
    m.x * size.width,
    m.y * size.height,
    m.w * size.width,
    m.h * size.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < masks.length; i++) {
      final rect = _rect(masks[i], size);
      canvas.drawRect(
        rect,
        Paint()
          ..color = i == selected
              ? OcclusionPainter.asked
              : OcclusionPainter.other.withValues(alpha: 0.9),
      );
      final painter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: (rect.shortestSide * 0.5).clamp(10, 28),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        rect.center - Offset(painter.width / 2, painter.height / 2),
      );
    }
    final draft = drawing;
    if (draft != null) {
      canvas.drawRect(
        _rect(draft, size),
        Paint()
          ..color = OcclusionPainter.asked
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_EditorPainter old) => true;
}
