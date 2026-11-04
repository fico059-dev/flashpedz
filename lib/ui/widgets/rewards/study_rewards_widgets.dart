import 'dart:async';
import 'dart:math';

import 'package:flashcards/data/services/local/study_rewards.dart';
import 'package:flashcards/domain/models/progress/level.dart';
import 'package:flashcards/domain/models/progress/study_log.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/rewards/bird_badge.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Picture and words for each goal milestone.
class MilestoneStyle {
  final String image;
  final String title;
  final List<String> affirmations;

  const MilestoneStyle(this.image, this.title, this.affirmations);
}

const milestoneStyles = {
  25: MilestoneStyle(
    'assets/images/parrot_fire_eyes.png',
    "A quarter done, you're on fire!",
    [
      'Every card you learn today is one less to worry about on exam day.',
      'Strong start. Consistency beats cramming, and you are proving it.',
      'You showed up and did the work. Keep that fire going!',
    ],
  ),
  50: MilestoneStyle('assets/images/parrot_chest.png', 'Halfway there!', [
    "Half of your goal is in the treasure chest. That's real knowledge you own now.",
    'The hardest part is behind you. The second half builds on everything you know.',
    'Halfway! Future you on exam day is already grateful.',
  ]),
  75: MilestoneStyle(
    'assets/images/parrot_weights.png',
    'Three quarters, so strong!',
    [
      'Your memory is getting stronger with every review. Keep lifting!',
      'Only a quarter left. You have built serious clinical knowledge.',
      'Look how far you have come. Finish strong!',
    ],
  ),
  100: MilestoneStyle('assets/images/parrot_fire.png', 'Goal complete!', [
    'You did it! Every card of your goal studied. Be proud of this work.',
    'Explorer of every card! Now keep them fresh with your daily reviews.',
    'Goal reached. That took discipline, and it will show on exam day.',
  ]),
};

String _pick(List<String> options) => options[Random().nextInt(options.length)];

/// Starts a study session and celebrates milestones and new levels with a
/// dialog while the student studies.
class StudyRewardsListener extends StatefulWidget {
  final Widget child;

  const StudyRewardsListener({super.key, required this.child});

  @override
  State<StudyRewardsListener> createState() => _StudyRewardsListenerState();
}

class _StudyRewardsListenerState extends State<StudyRewardsListener> {
  StreamSubscription<StudyReward>? _subscription;
  final _queue = <StudyReward>[];
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    StudyRewards? rewards;
    try {
      rewards = context.read<StudyRewards>();
    } on ProviderNotFoundException {
      rewards = null;
    }
    if (rewards == null) return;
    rewards.startSession();
    _subscription = rewards.rewards.listen((reward) {
      _queue.add(reward);
      _showNext();
    });
  }

  Future<void> _showNext() async {
    if (_showing || _queue.isEmpty || !mounted) return;
    _showing = true;
    final reward = _queue.removeAt(0);
    await showDialog<void>(
      context: context,
      builder: (context) => switch (reward) {
        MilestoneReward() => MilestoneDialog(reward: reward),
        LevelUpReward(:final level) => LevelUpDialog(level: level),
      },
    );
    _showing = false;
    _showNext();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MilestoneDialog extends StatelessWidget {
  final MilestoneReward reward;

  const MilestoneDialog({super.key, required this.reward});

  @override
  Widget build(BuildContext context) {
    final style = milestoneStyles[reward.percent] ?? milestoneStyles[25]!;
    final progress = reward.target == 0
        ? 0.0
        : min(1.0, reward.studied / reward.target);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(style.image, height: 170),
            const SizedBox(height: 8),
            Text(
              '${reward.percent}% of your goal',
              style: context.text.labelLarge?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              style.title,
              textAlign: TextAlign.center,
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _pick(style.affirmations),
              textAlign: TextAlign.center,
              style: context.text.bodyLarge,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress, minHeight: 10),
            ),
            const SizedBox(height: 6),
            Text(
              '${reward.studied} of ${reward.target} cards studied',
              style: context.text.bodySmall,
            ),
            if (reward.bonusXp > 0) ...[
              const SizedBox(height: 10),
              _XpChip(xp: reward.bonusXp, label: 'milestone bonus'),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(reward.percent == 100 ? 'Celebrate!' : 'Keep going'),
        ),
      ],
    );
  }
}

class LevelUpDialog extends StatelessWidget {
  final LevelInfo level;

  const LevelUpDialog({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/parrot_like.png', height: 150),
          const SizedBox(height: 8),
          Text(
            'New badge!',
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LevelBadge(level: level.level, size: 96),
          const SizedBox(height: 10),
          Text(
            'You earned the ${level.title}',
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${level.badge.rarity.label} badge',
            style: context.text.labelLarge?.copyWith(
              color: rarityColors(level.badge.rarity).$2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${level.xpToNextLevel} XP to the ${level.nextTitle}',
            style: context.text.bodySmall,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Awesome'),
        ),
      ],
    );
  }
}

/// The level's bird badge.
class LevelBadge extends StatelessWidget {
  final int level;
  final double size;

  const LevelBadge({super.key, required this.level, this.size = 36});

  @override
  Widget build(BuildContext context) => BirdBadgeIcon(level: level, size: size);
}

/// Level, title and a bar towards the next level.
class LevelProgressBar extends StatelessWidget {
  final LevelInfo level;

  const LevelProgressBar({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Tap to see every badge.
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showBirdBadgeCollection(context, level.level),
          child: LevelBadge(level: level.level, size: 44),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: level.title,
                        children: [
                          TextSpan(
                            text: '  ${level.badge.rarity.label}',
                            style: context.text.labelMedium?.copyWith(
                              color: rarityColors(level.badge.rarity).$2,
                            ),
                          ),
                        ],
                      ),
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text('${level.xp} XP', style: context.text.labelMedium),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: level.progress,
                  minHeight: 8,
                  color: const Color(0xFFFF8F00),
                  backgroundColor: const Color(
                    0xFFFF8F00,
                  ).withValues(alpha: 0.18),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${level.xpToNextLevel} XP to the ${level.nextTitle}',
                style: context.text.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _XpChip extends StatelessWidget {
  final int xp;
  final String label;

  const _XpChip({required this.xp, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8F00).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.isEmpty ? '+$xp XP' : '+$xp XP $label',
        style: context.text.labelLarge?.copyWith(
          color: const Color(0xFFB45309),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// How the session went: cards, recall, time, XP and goal progress.
class SessionSummaryCard extends StatelessWidget {
  final SessionSummary summary;

  const SessionSummaryCard({super.key, required this.summary});

  /// The summary of the session that just ended, or nothing when no card
  /// was rated.
  static Widget current(BuildContext context) {
    StudyRewards? rewards;
    try {
      rewards = context.read<StudyRewards>();
    } on ProviderNotFoundException {
      rewards = null;
    }
    if (rewards == null) return const SizedBox.shrink();
    return ValueListenableBuilder<SessionSummary?>(
      valueListenable: rewards.sessionListenable,
      builder: (context, summary, _) {
        if (summary == null || summary.reviewed == 0) {
          return const SizedBox.shrink();
        }
        return SessionSummaryCard(summary: summary);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final recall = s.recall;
    final minutes = s.duration.inMinutes;
    final goal = s.goal;
    final tiles = <(String, String, IconData)>[
      ('${s.reviewed}', 'cards', Icons.style_outlined),
      ('${s.newCards}', 'new', Icons.fiber_new_outlined),
      (
        recall == null ? '–' : '${(recall * 100).round()}%',
        'recalled',
        Icons.psychology_outlined,
      ),
      (
        minutes < 1 ? '<1' : '$minutes',
        minutes == 1 ? 'minute' : 'minutes',
        Icons.timer_outlined,
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: context.colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Session summary',
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _XpChip(xp: s.xpEarned, label: ''),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final (value, label, icon) in tiles)
                  Expanded(
                    child: Column(
                      children: [
                        Icon(icon, size: 20, color: context.colors.primary),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(label, style: context.text.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
            if (s.again + s.hard + s.good + s.easy > 0) ...[
              const SizedBox(height: 14),
              _RatingBar(summary: s),
            ],
            const SizedBox(height: 16),
            LevelProgressBar(level: s.level),
            if (s.levelsGained > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'You went up ${s.levelsGained == 1 ? 'a level' : '${s.levelsGained} levels'} this session!',
                  style: context.text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (goal != null && goal.target > 0) ...[
              const SizedBox(height: 16),
              Text(
                'Exam goal: ${goal.percent}% · '
                '${min(goal.estimate, goal.target)} of ${goal.target} cards',
                style: context.text.labelLarge,
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: goal.percent / 100,
                  minHeight: 8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final SessionSummary summary;

  const _RatingBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final parts = [
      (summary.again, 'Again', const Color(0xFFE53935)),
      (summary.hard, 'Hard', const Color(0xFFFB8C00)),
      (summary.good, 'Good', const Color(0xFF43A047)),
      (summary.easy, 'Easy', const Color(0xFF1E88E5)),
    ].where((p) => p.$1 > 0).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (count, _, color) in parts)
                  Expanded(
                    flex: count,
                    child: ColoredBox(color: color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final (count, label, color) in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('$label $count', style: context.text.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// The student's level and XP, for the profile.
class ProfileLevelCard extends StatefulWidget {
  const ProfileLevelCard({super.key});

  @override
  State<ProfileLevelCard> createState() => _ProfileLevelCardState();
}

class _ProfileLevelCardState extends State<ProfileLevelCard> {
  Future<int>? _xp;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _xp ??= context.read<StudyRewards>().currentXp();
    } on ProviderNotFoundException {
      _xp = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final xp = _xp;
    if (xp == null) return const SizedBox.shrink();
    return FutureBuilder<int>(
      future: xp,
      builder: (context, snapshot) {
        final value = snapshot.data;
        return Card(
          margin: const EdgeInsets.only(top: 16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: value == null
                ? const SizedBox(
                    height: 48,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LevelProgressBar(level: LevelInfo.fromXp(value)),
                      const SizedBox(height: 8),
                      Text(
                        'Earn XP for every card: new cards $newCardXpLabel, '
                        'reviews $reviewXpLabel. OSCEs and goal milestones '
                        'give bonus XP.',
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

const newCardXpLabel = '+$newCardXp';
const reviewXpLabel = '+$reviewXp';
