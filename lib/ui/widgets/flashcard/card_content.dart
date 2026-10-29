import 'package:flashcards/domain/models/flashcards/card_markup/card_markup.dart';
import 'package:flashcards/ui/widgets/notebook/highlightable_text.dart';
import 'package:flutter/material.dart';

/// A card's question or answer. Formatted cards (bold, underline, sizes,
/// tables, several images) are laid out block by block; plain cards are
/// shown exactly as before.
class CardContent extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final HighlightTarget? target;

  const CardContent(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.target,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasCardMarkup(text)) {
      return HighlightableText(
        text,
        style: style,
        textAlign: textAlign,
        target: target,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        for (final block in parseCardMarkup(text))
          switch (block) {
            TextBlock(:final text, style: final line) => _StyledParagraph(
              line: line,
              child: HighlightableText(
                text.plainText,
                runs: text.runs,
                style: switch (line) {
                  LineStyle.h1 => (style ?? const TextStyle()).copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                  LineStyle.h2 => (style ?? const TextStyle()).copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                  LineStyle.h3 => (style ?? const TextStyle()).copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                  LineStyle.quote => (style ?? const TextStyle()).copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                  _ => style,
                },
                textAlign: switch (line) {
                  LineStyle.center => TextAlign.center,
                  LineStyle.right => TextAlign.right,
                  LineStyle.justify => TextAlign.justify,
                  _ => textAlign,
                },
                target: target,
              ),
            ),
            DividerBlock() => const Divider(height: 8),
            ImageBlock(:final url) => _CardImage(url: url),
            OcclusionBlock() => OcclusionImage(block: block),
            TableBlock() => _CardTable(
              table: block,
              style: style,
              target: target,
            ),
          },
      ],
    );
  }
}

class _CardImage extends StatelessWidget {
  final String url;

  const _CardImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(url, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, error, stack) =>
                  const Icon(Icons.broken_image_outlined, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardTable extends StatelessWidget {
  final TableBlock table;
  final TextStyle? style;
  final HighlightTarget? target;

  const _CardTable({required this.table, this.style, this.target});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final columns = table.rows.first.length;
    final border = BorderSide(color: colors.outline.withValues(alpha: 0.6));
    final cellStyle = (style ?? const TextStyle()).copyWith(
      fontSize: (style?.fontSize ?? 16) - 1,
    );

    final widget = Table(
      border: TableBorder(
        top: border,
        bottom: border,
        left: border,
        right: border,
        horizontalInside: border,
        verticalInside: border,
        borderRadius: BorderRadius.circular(8),
      ),
      defaultColumnWidth: columns > 3
          ? const IntrinsicColumnWidth()
          : const FlexColumnWidth(),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        for (var r = 0; r < table.rows.length; r++)
          TableRow(
            decoration: table.hasHeader && r == 0
                ? BoxDecoration(color: colors.primary.withValues(alpha: 0.10))
                : null,
            children: [
              for (final cell in table.rows[r])
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: HighlightableText(
                    cell.plainText,
                    runs: table.hasHeader && r == 0
                        ? [
                            for (final run in cell.runs)
                              run.copyWith(bold: true),
                          ]
                        : cell.runs,
                    style: cellStyle,
                    target: target,
                  ),
                ),
            ],
          ),
      ],
    );

    // Wide tables scroll sideways instead of squeezing the text.
    if (columns <= 3) return widget;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width * 0.5,
        ),
        child: widget,
      ),
    );
  }
}

/// An image-occlusion image with its boxes drawn over it. Tap to see it
/// larger.
class OcclusionImage extends StatelessWidget {
  final OcclusionBlock block;

  /// Widest it is shown on the card.
  final double maxWidth;

  const OcclusionImage({super.key, required this.block, this.maxWidth = 640});

  Widget _picture({double? width}) => Stack(
    children: [
      Image.network(
        block.url,
        width: width,
        fit: BoxFit.fitWidth,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
        errorBuilder: (context, error, stack) =>
            const Icon(Icons.broken_image_outlined, size: 48),
      ),
      Positioned.fill(child: CustomPaint(painter: OcclusionPainter(block))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0, maxWidth).toDouble()
            : maxWidth;
        return Center(
          child: GestureDetector(
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                insetPadding: const EdgeInsets.all(12),
                child: Stack(
                  children: [
                    InteractiveViewer(maxScale: 5, child: _picture()),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton.filledTonal(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _picture(width: width),
            ),
          ),
        );
      },
    );
  }
}

/// Draws the boxes of an image-occlusion card: the asked one orange with a
/// "?", the others grey; on the answer the asked one is only outlined.
class OcclusionPainter extends CustomPainter {
  final OcclusionBlock block;

  OcclusionPainter(this.block);

  static const asked = Color(0xFFFF9800);
  static const other = Color(0xFF90A4AE);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    for (var i = 0; i < block.masks.length; i++) {
      final m = block.masks[i];
      final rect = Rect.fromLTWH(
        m.x * size.width,
        m.y * size.height,
        m.w * size.width,
        m.h * size.height,
      );
      final box = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      final isTarget = i == block.target;
      if (isTarget && block.revealed) {
        canvas.drawRRect(
          box,
          Paint()
            ..color = asked
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        continue;
      }
      canvas.drawRRect(box, Paint()..color = isTarget ? asked : other);
      canvas.drawRRect(
        box,
        Paint()
          ..color = const Color(0x55000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      if (isTarget) {
        final painter = TextPainter(
          text: TextSpan(
            text: '?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: (rect.shortestSide * 0.6).clamp(10, 40),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          rect.center - Offset(painter.width / 2, painter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(OcclusionPainter old) => old.block != block;
}

/// A paragraph's frame: a bar beside quotes, full width when aligned.
class _StyledParagraph extends StatelessWidget {
  final LineStyle line;
  final Widget child;

  const _StyledParagraph({required this.line, required this.child});

  @override
  Widget build(BuildContext context) {
    return switch (line) {
      LineStyle.quote => Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        child: child,
      ),
      LineStyle.center ||
      LineStyle.right ||
      LineStyle.justify => SizedBox(width: double.infinity, child: child),
      _ => child,
    };
  }
}
