import 'dart:async';
import 'dart:typed_data';
import 'package:flashcards/domain/models/flashcards/flashcard/flashcard.dart';
import 'package:flashcards/domain/models/osce/osce.dart';
import 'package:flashcards/domain/models/osce/question/check/check.dart';
import 'package:flashcards/domain/models/osce/question/question.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';

class PdfExportService {
  final pw.ThemeData _theme;

  /// Loads images for the PDF; returns null when one cannot be fetched.
  final Future<pw.ImageProvider?> Function(String url) _loadImage;

  PdfExportService({
    required pw.ThemeData theme,
    Future<pw.ImageProvider?> Function(String url)? loadImage,
  }) : _theme = theme,
       _loadImage = loadImage ?? _networkImageOrNull;

  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _arabic;
  static final _arabicLetters = RegExp(r'[\u0600-\u06FF\u0750-\u077F]');

  /// Uses the Roboto font built into the app (no download, so it is quick).
  /// Only when [text] has Arabic is an Arabic font downloaded (once). Falls
  /// back to the built-in PDF font if the fonts can't be loaded.
  static Future<PdfExportService> create({String? text}) async {
    try {
      _regular ??= pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
      );
      _bold ??= pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
      );
    } catch (_) {
      return PdfExportService(theme: pw.ThemeData.base());
    }
    if (_arabic == null && (text == null || _arabicLetters.hasMatch(text))) {
      try {
        _arabic = await PdfGoogleFonts.notoSansArabicRegular().timeout(
          const Duration(seconds: 8),
        );
      } catch (_) {
        // Without Arabic letters.
      }
    }
    return PdfExportService(
      theme: pw.ThemeData.withFont(
        base: _regular,
        bold: _bold,
        fontFallback: [?_arabic],
      ),
    );
  }

  static Future<pw.ImageProvider?> _networkImageOrNull(String url) async {
    try {
      return await networkImage(url).timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> generateFlashcardsPdf(List<Flashcard> flashcards) async {
    final pdf = pw.Document(theme: _theme);

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.SizedBox(height: 16),
          ...flashcards.map(
            (card) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Question: ${card.question}",
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.Text(
                  "Answer: ${card.answer}",
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 12),
                pw.Divider(),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// A printable copy of an OSCE. With [showResults] every check is marked as
  /// done or missed and the scores are shown, for reading after an attempt.
  Future<Uint8List> generateOscePdf(
    Osce osce, {
    bool showResults = true,
    DateTime? date,
  }) async {
    final urls = <String>{
      if (osce.scenarioImageUrl case final url?) url,
      for (final q in osce.questions)
        if (q.imageDownloadUrl case final url?) url,
    };
    final images = <String, pw.ImageProvider>{};
    await Future.wait(
      urls.map((url) async {
        final image = await _loadImage(url);
        if (image != null) images[url] = image;
      }),
    );

    const done = PdfColor.fromInt(0xFF2E7D32);
    const missed = PdfColor.fromInt(0xFFC62828);
    const muted = PdfColor.fromInt(0xFF616161);
    const panel = PdfColor.fromInt(0xFFF3F4F6);

    final maxScore = osce.getMaxScore();
    final achieved = osce.getAchievedScore();
    final percent = maxScore == 0 ? 0 : (achieved * 100 / maxScore).round();
    final day = date ?? DateTime.now();
    final dateText =
        '${day.day.toString().padLeft(2, '0')}/'
        '${day.month.toString().padLeft(2, '0')}/${day.year}';

    pw.Widget image(String? url) {
      final provider = url == null ? null : images[url];
      if (provider == null) return pw.SizedBox();
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Center(
          child: pw.Image(provider, height: 180, fit: pw.BoxFit.contain),
        ),
      );
    }

    pw.Widget checkRow(Check check) {
      if (check.isTitle) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8, bottom: 3),
          child: pw.Text(
            check.text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        );
      }
      final isChecked = check.isChecked;
      final score = check.score;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 9,
              height: 9,
              margin: const pw.EdgeInsets.only(top: 3, right: 8),
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: showResults ? (isChecked ? done : missed) : null,
                border: showResults
                    ? null
                    : pw.Border.all(color: muted, width: 0.8),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                check.text,
                style: pw.TextStyle(
                  color: showResults && !isChecked ? missed : null,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              showResults ? '${isChecked ? score : 0}/$score' : '$score',
              style: const pw.TextStyle(color: muted),
            ),
          ],
        ),
      );
    }

    pw.Widget question(int index, Question q) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Question $index${q.text.trim().isEmpty ? '' : ': ${q.text}'}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              if (showResults && q.getMaxScore() > 0)
                pw.Text(
                  '${q.getAchievedScore()}/${q.getMaxScore()}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
            ],
          ),
          image(q.imageDownloadUrl),
          pw.SizedBox(height: 4),
          ...q.checks.map(checkRow),
        ],
      );
    }

    final pdf = pw.Document(theme: _theme, title: osce.name);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Row(
          children: [
            pw.Text(
              'FlashPedz · $dateText',
              style: const pw.TextStyle(fontSize: 9, color: muted),
            ),
            pw.Spacer(),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: muted),
            ),
          ],
        ),
        build: (context) => [
          pw.Text(
            osce.name,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          if (showResults) ...[
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: const pw.BoxDecoration(
                color: panel,
                borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    'Score: $achieved / $maxScore  ($percent%)',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Spacer(),
                  _legendDot(done),
                  pw.Text('Done   '),
                  _legendDot(missed),
                  pw.Text('Missed'),
                ],
              ),
            ),
          ],
          if (osce.scenario.trim().isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text(
              'Scenario',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(osce.scenario),
          ],
          image(osce.scenarioImageUrl),
          for (final (i, q) in osce.questions.indexed) question(i + 1, q),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _legendDot(PdfColor color) => pw.Container(
    width: 8,
    height: 8,
    margin: const pw.EdgeInsets.only(right: 4),
    decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: color),
  );

  /// Opens the share sheet on phones and downloads the file on the website.
  /// The student's highlights: one section per pack, each card's question
  /// with the passages highlighted on it.
  Future<Uint8List> generateHighlightsPdf({
    required String filterLabel,
    required List<HighlightPdfSection> sections,
    DateTime? date,
  }) async {
    final pdf = pw.Document(theme: _theme);
    const muted = PdfColor.fromInt(0xFF616161);
    const mark = PdfColor.fromInt(0xFFFFF3B0);
    const markEdge = PdfColor.fromInt(0xFFE0B400);
    final day = date ?? DateTime.now();
    final dateText =
        '${day.day.toString().padLeft(2, '0')}/'
        '${day.month.toString().padLeft(2, '0')}/${day.year}';
    final total = sections.fold<int>(
      0,
      (sum, s) => sum + s.cards.fold<int>(0, (n, c) => n + c.passages.length),
    );

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(36),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'FlashPedz highlights',
                  style: const pw.TextStyle(fontSize: 9, color: muted),
                ),
              ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: muted),
          ),
        ),
        build: (context) => [
          pw.Text(
            'My highlights',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '$filterLabel  ·  $total highlights  ·  $dateText',
            style: const pw.TextStyle(fontSize: 11, color: muted),
          ),
          pw.SizedBox(height: 16),
          for (final section in sections) ...[
            pw.Header(
              level: 1,
              text: section.title,
              textStyle: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            for (final card in section.cards)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      card.question,
                      style: const pw.TextStyle(fontSize: 10, color: muted),
                    ),
                    pw.SizedBox(height: 4),
                    for (final passage in card.passages)
                      pw.Container(
                        width: double.infinity,
                        margin: const pw.EdgeInsets.only(bottom: 4),
                        padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 5),
                        decoration: const pw.BoxDecoration(
                          color: mark,
                          border: pw.Border(
                            left: pw.BorderSide(color: markEdge, width: 3),
                          ),
                        ),
                        child: pw.Text(
                          passage,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: '$filename.pdf');
  }

  Future<void> printPdf(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }
}

/// A safe file name from an OSCE name.
String pdfFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[^\w\s-]', unicode: true), '')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
  return cleaned.isEmpty ? 'OSCE' : cleaned;
}

/// A pack's (or another group's) part of the highlights PDF.
class HighlightPdfSection {
  final String title;
  final List<HighlightPdfCard> cards;

  const HighlightPdfSection(this.title, this.cards);
}

/// A card's question and the passages highlighted on it.
class HighlightPdfCard {
  final String question;
  final List<String> passages;

  const HighlightPdfCard(this.question, this.passages);
}
