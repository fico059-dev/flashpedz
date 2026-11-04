import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flutter/material.dart';

final _markupImage = RegExp(
  r'(?:!\[[^\]\n]*\]|\[occlusion\])\((https?://[^\s)]+)\)',
);

/// The pictures a card shows below the top of the card: in the question's
/// text, and on the answer side once [answerShown]. (The question's own
/// picture is at the top, in view.)
List<String> cardPictureUrls(Flashcard card, {required bool answerShown}) => [
  for (final m in _markupImage.allMatches(card.question)) m.group(1)!,
  if (answerShown) ...[
    if (card.answerImageUrl case final url? when url.isNotEmpty) url,
    for (final m in _markupImage.allMatches(card.answer)) m.group(1)!,
  ],
];

/// Wraps the scrolling card. When the card has a picture further down than
/// the screen shows, a "Picture below" button floats at the bottom (with a
/// spinner while the picture downloads); tapping it scrolls down.
class PictureHint extends StatefulWidget {
  final List<String> pictureUrls;
  final ScrollController controller;

  /// The scroll view, using [controller].
  final Widget child;

  const PictureHint({
    super.key,
    required this.pictureUrls,
    required this.controller,
    required this.child,
  });

  @override
  State<PictureHint> createState() => _PictureHintState();
}

class _PictureHintState extends State<PictureHint> {
  var _loading = false;
  var _below = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(PictureHint old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_update);
      widget.controller.addListener(_update);
    }
    if (old.pictureUrls.join() != widget.pictureUrls.join()) _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  /// Starts downloading the pictures (the card shows them from the same
  /// cache) and notes when they are ready.
  void _load() {
    final urls = widget.pictureUrls;
    if (urls.isEmpty) {
      _loading = false;
      return;
    }
    _loading = true;
    Future.wait([
      for (final url in urls)
        precacheImage(NetworkImage(url), context, onError: (_, _) {}),
    ]).whenComplete(() {
      if (mounted && widget.pictureUrls.join() == urls.join()) {
        setState(() => _loading = false);
      }
    });
  }

  void _update() {
    final controller = widget.controller;
    final below =
        widget.pictureUrls.isNotEmpty &&
        controller.hasClients &&
        controller.position.maxScrollExtent > 24 &&
        controller.position.pixels < controller.position.maxScrollExtent - 24;
    if (below != _below && mounted) setState(() => _below = below);
  }

  void _scrollDown() {
    final position = widget.controller.position;
    widget.controller.animateTo(
      position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _update());
        return false;
      },
      child: Stack(
        // Full width, so the button is centred and can be tapped.
        fit: StackFit.passthrough,
        children: [
          SizedBox(width: double.infinity, child: widget.child),
          if (_below)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: Material(
                  color: colors.inverseSurface,
                  elevation: 4,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _scrollDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _loading
                              ? SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.onInverseSurface,
                                  ),
                                )
                              : Icon(
                                  Icons.image_outlined,
                                  size: 18,
                                  color: colors.onInverseSurface,
                                ),
                          const SizedBox(width: 8),
                          Text(
                            _loading ? 'Loading picture…' : 'Picture below',
                            style: TextStyle(color: colors.onInverseSurface),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_downward,
                            size: 16,
                            color: colors.onInverseSurface,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
