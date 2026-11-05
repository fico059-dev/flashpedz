import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flashcards/data/mappers/uint8list_converter.dart';
import 'package:flashcards/data/services/api/dto/flashcards/flashcard/flashcard_dto.dart';
import 'package:flashcards/data/services/api/dto/requests/create_custom_session/create_custom_session_request_dto.dart';
import 'package:flashcards/utils/typedefs.dart';
import 'package:flashcards/utils/result.dart' as res;

class CloudFunctionService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// [topics]: cards must have one of these topics. [excludeTags]: cards
  /// with any of these tags are left out.
  Future<HttpsCallableResult> createCustomSession(
    CreateCustomSessionRequestDto request, {
    List<String> topics = const [],
    List<String> excludeTags = const [],
    String? studied,
    bool matchAnyTag = false,
  }) async {
    return await _functions.httpsCallable("createCustomSession").call({
      ...request.toJson(),
      if (topics.isNotEmpty) 'topics': topics,
      if (excludeTags.isNotEmpty) 'excludeTags': excludeTags,
      'studied': ?studied,
      if (matchAnyTag) 'tagMatch': 'any',
    });
  }

  /// How many cards an exam with these choices would have: with every tag
  /// and with any of the tags.
  Future<({int allTags, int anyTag})> countCustomSessionCards(
    CreateCustomSessionRequestDto request, {
    List<String> topics = const [],
    List<String> excludeTags = const [],
    String? studied,
  }) async {
    final result = await _functions
        .httpsCallable("countCustomSessionCards")
        .call({
          ...request.toJson(),
          if (topics.isNotEmpty) 'topics': topics,
          if (excludeTags.isNotEmpty) 'excludeTags': excludeTags,
          'studied': ?studied,
        });
    final data = Map<String, dynamic>.from(result.data as Map);
    return (
      allTags: (data['allTags'] as num).toInt(),
      anyTag: (data['anyTag'] as num).toInt(),
    );
  }

  /// Returns the name that was saved.
  Future<String> renameCustomSession({
    required String sessionId,
    required String name,
  }) async {
    final result = await _functions.httpsCallable('renameCustomSession').call(
      <String, dynamic>{'sessionId': sessionId, 'name': name},
    );
    return (result.data as Map)['name'] as String;
  }

  Future<String> saveHighlight(Map<String, dynamic> highlight) async {
    final result = await _functions
        .httpsCallable('saveHighlight')
        .call<Map<String, dynamic>>(highlight);
    return result.data['id'] as String;
  }

  Future<void> deleteHighlight(String id) async {
    await _functions.httpsCallable('deleteHighlight').call(<String, dynamic>{
      'id': id,
    });
  }

  Future<List<Map<String, dynamic>>> listHighlights() async {
    final result = await _functions.httpsCallable('listHighlights').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return [
      for (final item in data['highlights'] as List)
        Map<String, dynamic>.from(item as Map),
    ];
  }

  /// The student's sets ("My Sets").
  Future<List<Map<String, dynamic>>> listCardSets() async {
    final data = await _call('listCardSets', {});
    return [
      for (final item in data['sets'] as List? ?? const [])
        Map<String, dynamic>.from(item as Map),
    ];
  }

  /// Creates a set (no [id], with [flashcardIds] if given) or renames one.
  /// Returns its id.
  Future<String> saveCardSet({
    String? id,
    required String name,
    List<String>? flashcardIds,
  }) async {
    final data = await _call('saveCardSet', {
      'id': ?id,
      'name': name,
      'flashcardIds': ?flashcardIds,
    });
    return data['id'] as String;
  }

  Future<void> deleteCardSet(String id) => _call('deleteCardSet', {'id': id});

  Future<void> setCardInSet({
    required String setId,
    required String flashcardId,
    required bool inSet,
  }) => _call('setCardInSet', {
    'setId': setId,
    'flashcardId': flashcardId,
    'inSet': inSet,
  });

  /// Makes the set's study session; returns it.
  Future<Map<String, dynamic>> studyCardSet(String setId) =>
      _call('studyCardSet', {'setId': setId});

  /// Limits a pack to [emails] (empty: everyone). Returns the saved list.
  Future<List<String>> setPackAccess(String packId, List<String> emails) async {
    final data = await _call('setPackAccess', {
      'packId': packId,
      'emails': emails,
    });
    return List<String>.from(data['allowedEmails'] as List? ?? const []);
  }

  /// Stores an image shown inside a card's text and returns its address.
  Future<String> uploadCardImage(String imageBase64) async {
    final data = await _call('uploadCardImage', {'imageBase64': imageBase64});
    return data['url'] as String;
  }

  /// Sets the user's profile photo (JPEG), or removes it when null.
  /// Returns the photo's address.
  Future<String?> setProfilePhoto(String? imageBase64) async {
    final data = await _call('setProfilePhoto', {
      'imageBase64': imageBase64 ?? '',
    });
    return data['url'] as String?;
  }

  /// The emails a pack is limited to (empty: everyone). Admins only.
  Future<List<String>> getPackAccess(String packId) async {
    final data = await _call('getPackAccess', {'packId': packId});
    return List<String>.from(data['allowedEmails'] as List? ?? const []);
  }

  /// Every card the user may search (premium and limited packs filtered
  /// on the server).
  /// The cards the user may search, gzipped. Null when the [version] the
  /// device already has is still current.
  Future<({String version, String gzip})?> listSearchableFlashcards({
    String? version,
  }) async {
    final data = await _call('listSearchableFlashcards', {
      'compressed': true,
      'version': ?version,
    });
    if (data['unchanged'] == true) return null;
    final gzip = data['gzip'];
    if (gzip is String) {
      return (version: data['version'] as String? ?? '', gzip: gzip);
    }
    // A server not updated yet sends the plain list.
    final plain = jsonEncode(data['flashcards'] as List? ?? const []);
    return (
      version: '',
      gzip: base64Encode(GZipEncoder().encodeBytes(utf8.encode(plain))),
    );
  }

  /// Saves this device's study history (and the goal when it changed).
  Future<void> saveStudyLog({
    required String deviceId,
    required String log,
    String? goal,
  }) async {
    await _call('saveStudyLog', {
      'deviceId': deviceId,
      'log': log,
      'goal': ?goal,
    });
  }

  /// The study history of every device, and the saved goal.
  Future<({Map<String, String> devices, String? goal})> getStudyLog() async {
    final data = await _call('getStudyLog');
    final devices = Map<String, dynamic>.from(data['devices'] as Map? ?? {});
    return (
      devices: devices.map((key, value) => MapEntry(key, value as String)),
      goal: data['goal'] as String?,
    );
  }

  /// Numbers about users and study for the admin dashboard.
  Future<Map<String, dynamic>> getAppAnalytics() => _call('getAppAnalytics');

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    final result = await _functions.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(result.data as Map? ?? const {});
  }

  Future<List<Map<String, dynamic>>> listOsceFolders() async {
    final data = await _call('listOsceFolders');
    return [
      for (final item in data['folders'] as List)
        Map<String, dynamic>.from(item as Map),
    ];
  }

  /// Creates a folder (no [id]) or renames / moves one. Returns its id.
  Future<String> saveOsceFolder({
    String? id,
    required String name,
    String? parentId,
  }) async {
    final data = await _call('saveOsceFolder', {
      'id': id,
      'name': name,
      'parentId': parentId,
    });
    return data['id'] as String;
  }

  Future<void> deleteOsceFolder(String id) =>
      _call('deleteOsceFolder', {'id': id});

  Future<void> setOsceFolder(String osceId, String? folderId) =>
      _call('setOsceFolder', {'osceId': osceId, 'folderId': folderId});

  Future<void> setOscePremium(String osceId, bool isPaid) =>
      _call('setOscePremium', {'osceId': osceId, 'isPaid': isPaid});

  /// Uploads a JPEG (or removes the image with null). Returns its URL.
  Future<String?> setOsceScenarioImage(
    String osceId,
    String? jpegBase64,
  ) async {
    final data = await _call('setOsceScenarioImage', {
      'osceId': osceId,
      'imageBase64': jpegBase64,
    });
    return data['url'] as String?;
  }

  Future<void> deleteFlashcardEverywhere(FlashcardDto flashcardDto) async {
    final callable = _functions.httpsCallable('deleteFlashcardEverywhere');
    await callable.call(<String, dynamic>{
      'flashcard': flashcardDto.toJsonWithId(),
    });
  }

  Future<void> updateFlashcardEverywhere({
    required String flashcardId,
    required JsonMap partialJson,
    required bool shouldDeleteQuestion,
    required bool shouldDeleteAnswer,
    required Uint8List? answerImageBytes,
    required Uint8List? questionImageBytes,
  }) async {
    final callable = _functions.httpsCallable("updateFlashcardEverywhere");
    final data = <String, dynamic>{
      "flashcardId": flashcardId,
      "updateFlashcardDto": partialJson,
      "shouldDeleteAnswer": shouldDeleteAnswer,
      "shouldDeleteQuestion": shouldDeleteQuestion,
    };

    if (answerImageBytes != null) {
      data["answerImageBase64"] = answerImageBytes.toJson();
    }

    if (questionImageBytes != null) {
      data["questionImageBase64"] = questionImageBytes.toJson();
    }

    //print(data);
    await callable.call(data);
  }

  Future<void> renamePackEverywhere(String packId, String packName) async {
    final callable = _functions.httpsCallable('renamePackEverywhere');
    await callable.call(<String, dynamic>{
      'packId': packId,
      'packName': packName,
    });
  }

  Future<void> setPackPremium(String packId, bool isPaid) async {
    final callable = _functions.httpsCallable('setPackPremium');
    await callable.call(<String, dynamic>{'packId': packId, 'isPaid': isPaid});
  }

  Future<void> deletePackWithCards(String packId) async {
    final callable = _functions.httpsCallable(
      'deletePackWithCards',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
    );
    await callable.call(<String, dynamic>{'packId': packId});
  }

  Future<void> deletePackEverywhereIfEmpty(String packId) async {
    final callable = _functions.httpsCallable("deletePackEverywhereIfEmpty");
    await callable.call(<String, dynamic>{"packId": packId});
  }

  Future<void> deletePackProgress(String packId) async {
    final callable = _functions.httpsCallable('deletePackProgress');
    await callable.call(<String, dynamic>{'packId': packId});
  }

  Future<void> setAdminRole(String email) async {
    final callable = _functions.httpsCallable('addAdminRole');
    await callable.call(<String, dynamic>{'email': email});
  }

  Future<List<JsonMap>> listAdmins() async {
    final result = await _functions.httpsCallable('listAdmins').call();
    final admins = (result.data as Map)['admins'] as List;
    return admins.map((admin) => JsonMap.from(admin as Map)).toList();
  }

  Future<void> removeAdminRole(String uid) async {
    final callable = _functions.httpsCallable('removeAdminRole');
    await callable.call(<String, dynamic>{'uid': uid});
  }

  Future<res.Result<void>> deleteUserAndUserData() async {
    try {
      final callable = _functions.httpsCallable("deleteUserAndUserData");
      await callable.call();
      return res.Result.ok(null);
    } on Exception catch (error) {
      return res.Result.error(error);
    }
  }

  Future<void> devGrant({
    required String scope,
    int minutes = 120,
    String? targetUid,
  }) async {
    final uid = targetUid ?? FirebaseAuth.instance.currentUser!.uid;
    await _functions.httpsCallable('devGrant').call({
      'targetUid': uid,
      'scope': scope,
      'minutes': minutes,
    });
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
  }

  Future<void> verifyPurchase({
    required String source,
    required String productId,
    required String verificationData,
  }) async {
    await _functions.httpsCallable('verifyPurchase').call({
      'source': source,
      'productId': productId,
      'verificationData': verificationData,
    });
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
  }
}
