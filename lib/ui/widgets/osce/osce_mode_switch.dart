import 'package:flashcards/bloc/osces/osce/osce_bloc.dart';
import 'package:flashcards/bloc/osces/osce/osce_event.dart';
import 'package:flashcards/bloc/osces/osce/osce_state.dart';
import 'package:flashcards/domain/models/osce/question/question.dart';
import 'package:flashcards/ui/widgets/osce/osce_checklist_review.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

OsceMode? _modeOf(OsceState state) => switch (state) {
  OsceShowcase(:final mode) => mode,
  OsceLoaded(:final mode) => mode,
  _ => null,
};

/// Learning or Exam, at the top of the OSCE screen.
class OsceModeSwitch extends StatelessWidget {
  /// Explains the two modes under the switch.
  final bool showHint;

  const OsceModeSwitch({super.key, this.showHint = false});

  @override
  Widget build(BuildContext context) {
    final mode = context.select<OsceBloc, OsceMode?>(
      (bloc) => _modeOf(bloc.state),
    );
    if (mode == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<OsceMode>(
          segments: const [
            ButtonSegment(
              value: OsceMode.learning,
              icon: Icon(Icons.school_outlined),
              label: Text('Study'),
            ),
            ButtonSegment(
              value: OsceMode.exam,
              icon: Icon(Icons.timer_outlined),
              label: Text('Exam'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (value) =>
              context.read<OsceBloc>().add(OsceModeChanged(value.first)),
        ),
        if (showHint) ...[
          const SizedBox(height: 6),
          Text(
            mode == OsceMode.learning
                ? 'Study: each question shows its answer checklist right away, '
                      'to learn it. The full checklist comes again at the end.'
                : 'Exam: answer every question first; the answers and the '
                      'checklist are shown only at the end.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// In Study mode, the current question's answer checklist, shown right
/// away to learn it (and tick what was covered).
class OsceLearningAnswer extends StatelessWidget {
  const OsceLearningAnswer({super.key});

  @override
  Widget build(BuildContext context) {
    final view = context.select<OsceBloc, (OsceMode, int)?>((bloc) {
      final state = bloc.state;
      if (state is! OsceLoaded) return null;
      return (state.mode, state.currentQuestionIndex);
    });
    if (view == null || view.$1 != OsceMode.learning) {
      return const SizedBox.shrink();
    }
    final index = view.$2;
    final question = context.select<OsceBloc, Question>(
      (bloc) => (bloc.state as OsceLoaded).osce.questions[index],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Answer checklist: tick what you covered',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        OsceQuestionChecklist(
          questionIndex: index,
          question: question,
          showNumber: false,
        ),
      ],
    );
  }
}
