import 'package:auto_route/auto_route.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/domain/enums/score_status.dart';
import 'package:flashcards/ui/widgets/rewards/study_rewards_widgets.dart';
import 'package:flutter/material.dart';

@RoutePage()
class CustomSessionResultPage extends StatelessWidget {
  final ScoreStatus scoreStatus;
  final int correctCount;
  final int allCount;

  const CustomSessionResultPage({
    super.key,
    required this.scoreStatus,
    required this.correctCount,
    required this.allCount,
  });

  String _getTitle() {
    switch (scoreStatus) {
      case ScoreStatus.low:
        return "Session Complete";
      case ScoreStatus.okay:
        return "Session Complete 🎉";
      case ScoreStatus.max:
        return "Perfect Score! 🌟";
    }
  }

  String _getMessage() {
    switch (scoreStatus) {
      case ScoreStatus.low:
        return "Good effort! You’ve finished your exam.\n"
            "Don’t worry if the score isn’t high this time — every try helps you learn and improve.";
      case ScoreStatus.okay:
        return "Nice work! You stayed focused and made progress.\n"
            "Keep practicing and you’ll get even better next time.";
      case ScoreStatus.max:
        return "Congratulations! You answered everything correctly in this exam.\n"
            "Awesome focus and great job!";
    }
  }

  String _getImagePath() {
    switch (scoreStatus) {
      case ScoreStatus.low:
        return "assets/images/parrot_sad.png";
      case ScoreStatus.okay:
        return "assets/images/parrot_like.png";
      case ScoreStatus.max:
        return "assets/images/parrot_fire.png";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "$correctCount / $allCount",
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Image.asset(_getImagePath(), height: 160),
                const SizedBox(height: 24),
                Text(
                  _getTitle(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _getMessage(),
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SessionSummaryCard.current(context),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () {
                      context.router.pop();
                    },
                    child: const Text("Back to home"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
