import 'package:flutter/foundation.dart';

/// How many cards were answered right and wrong (Again) in this session,
/// shown at the top while studying. Undo takes an answer back.
class SessionScore extends ChangeNotifier {
  int _correct = 0;
  int _wrong = 0;

  int get correct => _correct;
  int get wrong => _wrong;

  void add({required bool correct}) {
    correct ? _correct++ : _wrong++;
    notifyListeners();
  }

  void remove({required bool correct}) {
    if (correct && _correct > 0) _correct--;
    if (!correct && _wrong > 0) _wrong--;
    notifyListeners();
  }
}
