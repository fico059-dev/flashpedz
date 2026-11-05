import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/domain/models/algolia/algolia_flashcard/algolia_flashcard.dart';
import 'package:flashcards/utils/result.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// A card's question and answer pictures.
typedef CardImages = ({String? question, String? answer});

/// The searchable cards, the version they belong to, and the pictures of
/// the cards that have any.
typedef SearchCards = ({
  String version,
  List<AlgoliaFlashcard> cards,
  Map<String, CardImages> images,
});

/// Loads the flashcards that flashcard search runs over. Search used to go
/// through Algolia, whose app no longer exists, so flashcards are read from
/// Firestore and searched on the device.
///
/// The list comes compressed and is kept on the device, so search works
/// straight away next time and is only downloaded again when cards change.
class FlashcardsSearcherService {
  final CloudFunctionService _functions;
  SharedPreferencesAsync? _prefsInstance;

  /// Larger lists aren't kept on the device.
  static const _maxSavedLength = 4000000;

  SharedPreferencesAsync get _prefs =>
      _prefsInstance ??= SharedPreferencesAsync();

  FlashcardsSearcherService({required CloudFunctionService functions})
    : _functions = functions;

  String? get _key {
    // A browser's storage holds only a few MB, which the rest of the app
    // needs: the website keeps the list in memory only.
    if (kIsWeb) return null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : 'search_cards_$uid';
  }

  /// Cards the user may search. The server leaves out premium cards without
  /// a subscription and packs limited to other users. Ok(null) when
  /// [version] is still current.
  Future<Result<SearchCards?>> getAllFlashcards({String? version}) async {
    try {
      final download = await _functions.listSearchableFlashcards(
        version: version,
      );
      if (download == null) return Result.ok(null);
      final images = <String, CardImages>{};
      final cards = decodeSearchCards(download.gzip, images: images);
      final key = _key;
      if (key != null && download.gzip.length < _maxSavedLength) {
        try {
          await _prefs.setString(key, '${download.version}\n${download.gzip}');
        } catch (_) {
          // Downloaded again next time.
        }
      }
      return Result.ok((
        version: download.version,
        cards: cards,
        images: images,
      ));
    } on Exception catch (error) {
      return Result.error(error);
    } catch (error) {
      return Result.error(Exception(error.toString()));
    }
  }

  /// Removes the copy earlier versions of the website kept in the browser.
  Future<void> forgetSavedOnWeb() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (!kIsWeb || uid == null) return;
    try {
      await _prefs.remove('search_cards_$uid');
    } catch (_) {
      // Nothing saved.
    }
  }

  /// The cards kept on this device from last time, if any.
  Future<SearchCards?> readSaved() async {
    final key = _key;
    if (key == null) return null;
    try {
      final saved = await _prefs.getString(key);
      if (saved == null) return null;
      final split = saved.indexOf('\n');
      if (split <= 0) return null;
      final images = <String, CardImages>{};
      return (
        version: saved.substring(0, split),
        cards: decodeSearchCards(saved.substring(split + 1), images: images),
        images: images,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Unpacks the gzipped (base64) card list sent by the server, sorted by
/// question. The cards' pictures are put in [images].
List<AlgoliaFlashcard> decodeSearchCards(
  String gzipBase64, {
  Map<String, CardImages>? images,
}) {
  final json = utf8.decode(GZipDecoder().decodeBytes(base64Decode(gzipBase64)));
  final list = jsonDecode(json) as List<dynamic>;
  if (images != null) {
    for (final data in list) {
      final question = data['questionImageUrl'] as String?;
      final answer = data['answerImageUrl'] as String?;
      if (question != null || answer != null) {
        images[data['id'] as String] = (question: question, answer: answer);
      }
    }
  }
  final cards = [
    for (final data in list)
      AlgoliaFlashcard(
        objectID: data['id'] as String,
        question: data['question'] as String? ?? '',
        answer: data['answer'] as String? ?? '',
        isPaid: data['isPaid'] as bool? ?? false,
        tags: List<String>.from(data['tags'] as List? ?? const []),
        packId: data['packId'] as String? ?? '',
      ),
  ];
  cards.sort((a, b) => a.question.compareTo(b.question));
  return cards;
}
