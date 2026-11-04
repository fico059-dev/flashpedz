import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/data/services/api/users/auth_service.dart';
import 'package:flashcards/domain/models/flashcards/custom_session_summary/custom_session_summary.dart';
import 'package:flutter/foundation.dart';

/// Most sets a student can have (the server checks it too).
const maxCardSets = 5;

/// Most cards in one set (the server checks it too).
const maxCardsInSet = 2000;

/// A named list of cards the student made ("My Sets"), studied like a pack.
class CardSet {
  final String id;
  final String name;
  final List<String> flashcardIds;

  const CardSet({
    required this.id,
    required this.name,
    this.flashcardIds = const [],
  });

  int get cardCount => flashcardIds.length;

  bool contains(String flashcardId) => flashcardIds.contains(flashcardId);

  CardSet copyWith({String? name, List<String>? flashcardIds}) => CardSet(
    id: id,
    name: name ?? this.name,
    flashcardIds: flashcardIds ?? this.flashcardIds,
  );

  factory CardSet.fromJson(Map<String, dynamic> json) => CardSet(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'My set',
    flashcardIds: List<String>.from(json['flashcardIds'] as List? ?? const []),
  );
}

/// The student's sets, loaded once and kept in memory. Changes show on
/// screen right away and are undone if they couldn't be saved.
class CardSetRepository extends ChangeNotifier {
  final CloudFunctionService _functions;
  final AuthService _authService;

  CardSetRepository({
    required CloudFunctionService functions,
    required AuthService authService,
  }) : _functions = functions,
       _authService = authService;

  List<CardSet> _sets = const [];
  String? _loadedFor;
  Future<void>? _loading;
  Object? loadError;

  List<CardSet> get sets => _sets;

  bool get isLoaded => _loadedFor != null && _loadedFor == _uid;

  bool get canAddSet => _sets.length < maxCardSets;

  String? get _uid => _authService.getCurrentUser()?.uid;

  CardSet? byId(String id) => _sets.where((s) => s.id == id).firstOrNull;

  Future<void> load({bool refresh = false}) {
    if (!refresh && isLoaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final list = await _functions.listCardSets();
      if (uid != _uid) return;
      _sets = list.map(CardSet.fromJson).toList();
      _loadedFor = uid;
      loadError = null;
    } catch (error) {
      loadError = error;
    }
    notifyListeners();
  }

  /// Makes a new set (with [flashcardIds] in it) and returns it.
  Future<CardSet> create(
    String name, {
    List<String> flashcardIds = const [],
  }) async {
    final ids = flashcardIds.toSet().take(maxCardsInSet).toList();
    final id = await _functions.saveCardSet(
      name: name.trim(),
      flashcardIds: ids.isEmpty ? null : ids,
    );
    final set = CardSet(id: id, name: name.trim(), flashcardIds: ids);
    _sets = [..._sets, set];
    notifyListeners();
    return set;
  }

  Future<void> rename(String id, String name) async {
    await _functions.saveCardSet(id: id, name: name.trim());
    _replace(id, (set) => set.copyWith(name: name.trim()));
  }

  Future<void> delete(String id) async {
    await _functions.deleteCardSet(id);
    _sets = _sets.where((s) => s.id != id).toList();
    notifyListeners();
  }

  /// Adds the card to the set, or takes it out.
  Future<void> setCard(String setId, String flashcardId, bool inSet) async {
    List<String> change(List<String> ids) => inSet
        ? (ids.contains(flashcardId) ? ids : [...ids, flashcardId])
        : ids.where((id) => id != flashcardId).toList();
    List<String> undo(List<String> ids) => inSet
        ? ids.where((id) => id != flashcardId).toList()
        : (ids.contains(flashcardId) ? ids : [...ids, flashcardId]);

    _replace(
      setId,
      (set) => set.copyWith(flashcardIds: change(set.flashcardIds)),
    );
    try {
      await _functions.setCardInSet(
        setId: setId,
        flashcardId: flashcardId,
        inSet: inSet,
      );
    } catch (_) {
      _replace(
        setId,
        (set) => set.copyWith(flashcardIds: undo(set.flashcardIds)),
      );
      rethrow;
    }
  }

  /// Makes the set's study session (its cards in a random order).
  Future<CustomSessionSummary> study(String setId) async {
    final data = await _functions.studyCardSet(setId);
    return CustomSessionSummary(
      id: data['id'] as String,
      name: data['name'] as String?,
      cardCount: (data['cardCount'] as num).toInt(),
      isPaid: data['isPaid'] == true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['createdAtMs'] as num).toInt(),
      ),
      correctCount: 0,
      currentIndex: 0,
    );
  }

  void _replace(String id, CardSet Function(CardSet set) change) {
    _sets = [for (final set in _sets) set.id == id ? change(set) : set];
    notifyListeners();
  }
}
