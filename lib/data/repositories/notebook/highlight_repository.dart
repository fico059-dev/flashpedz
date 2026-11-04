import 'package:flashcards/data/remote/cloud_function_service.dart';
import 'package:flashcards/data/services/api/users/auth_service.dart';
import 'package:flashcards/domain/models/flashcards/highlight/highlight.dart';
import 'package:flutter/foundation.dart';

/// The student's highlights. They are loaded once and kept in memory, and
/// changes show on screen right away while they are saved in the background.
class HighlightRepository extends ChangeNotifier {
  final CloudFunctionService _functions;
  final AuthService _authService;

  HighlightRepository({
    required CloudFunctionService functions,
    required AuthService authService,
  }) : _functions = functions,
       _authService = authService;

  List<Highlight> _highlights = const [];
  String? _loadedFor;
  Future<void>? _loading;
  Object? loadError;
  int _tempIds = 0;

  /// Newest first, highlights and underlines.
  List<Highlight> get highlights => _highlights;

  /// What the notebook lists: highlights, not underlines.
  List<Highlight> get notebookHighlights =>
      _highlights.where((h) => !h.isUnderline).toList();

  bool get isLoaded => _loadedFor != null && _loadedFor == _uid;

  String? get _uid => _authService.getCurrentUser()?.uid;

  List<Highlight> forCard(String flashcardId, HighlightSide side) => [
    for (final h in _highlights)
      if (h.flashcardId == flashcardId && h.side == side) h,
  ];

  /// Loads the highlights once per signed in user.
  Future<void> load({bool refresh = false}) {
    if (!refresh && isLoaded) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final list = await _functions.listHighlights();
      if (uid != _uid) return;
      // Keep highlights added while loading that aren't saved yet.
      final unsaved = _highlights.where((h) => h.id.startsWith('local-'));
      _highlights = [...unsaved, ...list.map(Highlight.fromJson)];
      _loadedFor = uid;
      loadError = null;
    } catch (error) {
      loadError = error;
    }
    notifyListeners();
  }

  /// Adds a highlight. [onError] is called if it couldn't be saved.
  void add({
    required String flashcardId,
    required String packId,
    required HighlightSide side,
    required String text,
    required int start,
    required String question,
    HighlightKind kind = HighlightKind.highlight,
    void Function(Object error)? onError,
  }) {
    final local = Highlight(
      id: 'local-${_tempIds++}',
      flashcardId: flashcardId,
      packId: packId,
      side: side,
      text: text,
      start: start,
      question: question,
      createdAt: DateTime.now(),
      kind: kind,
    );
    _highlights = [local, ..._highlights];
    notifyListeners();

    _functions
        .saveHighlight(local.toJson())
        .then((id) {
          _highlights = [
            for (final h in _highlights)
              h.id == local.id ? h.copyWith(id: id) : h,
          ];
          notifyListeners();
        })
        .catchError((Object error) {
          _highlights = _highlights.where((h) => h.id != local.id).toList();
          notifyListeners();
          onError?.call(error);
        });
  }

  /// Removes highlights. [onError] is called if they couldn't be deleted.
  void remove(
    Iterable<Highlight> toRemove, {
    void Function(Object error)? onError,
  }) {
    final ids = toRemove.map((h) => h.id).toSet();
    final removed = _highlights.where((h) => ids.contains(h.id)).toList();
    if (removed.isEmpty) return;
    _highlights = _highlights.where((h) => !ids.contains(h.id)).toList();
    notifyListeners();

    for (final highlight in removed) {
      if (highlight.id.startsWith('local-')) continue;
      _functions.deleteHighlight(highlight.id).catchError((Object error) {
        _highlights = [highlight, ..._highlights]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
        onError?.call(error);
      });
    }
  }
}
