import 'dart:typed_data';

import 'package:flashcards/bloc/flashcards/anki_import/anki_import_state.dart';
import 'package:flashcards/data/repositories/flashcards/flashcard_repository.dart';
import 'package:flashcards/data/services/anki/anki_import_service.dart';
import 'package:flashcards/domain/models/flashcards/tag/tag.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AnkiImportCubit extends Cubit<AnkiImportState> {
  final FlashcardRepository _flashcardRepo;
  final AnkiImportService _ankiImportService;

  AnkiImportCubit({
    required FlashcardRepository flashcardRepo,
    required AnkiImportService ankiImportService,
  }) : _flashcardRepo = flashcardRepo,
       _ankiImportService = ankiImportService,
       super(const AnkiImportInitial());

  Future<void> readFile({
    required String fileName,
    String? path,
    Uint8List? bytes,
  }) async {
    emit(AnkiImportReading(fileName: fileName));
    try {
      final result = await _ankiImportService.parseFile(
        fileName: fileName,
        path: path,
        bytes: bytes,
      );
      emit(AnkiImportPreview(fileName: fileName, result: result));
    } on Object catch (error) {
      emit(AnkiImportError(error: error));
    }
  }

  Future<void> importCards({
    required String packId,
    required bool importTags,
    String topic = '',
  }) async {
    final current = state;
    if (current is! AnkiImportPreview) return;

    emit(AnkiImportImporting(processed: 0, total: current.result.cards.length));
    final summary = await _flashcardRepo.importFlashcardsToPack(
      packId: packId,
      cards: current.result.cards,
      importTags: importTags,
      topic: topic.trim().isEmpty ? null : Tag.topic(topic),
      onProgress: (processed, total) {
        if (isClosed) return;
        emit(AnkiImportImporting(processed: processed, total: total));
      },
    );
    if (isClosed) return;
    emit(AnkiImportDone(summary: summary));
  }

  void reset() => emit(const AnkiImportInitial());
}
