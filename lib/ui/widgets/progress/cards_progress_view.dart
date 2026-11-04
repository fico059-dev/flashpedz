import 'package:auto_route/auto_route.dart';
import 'package:flashcards/bloc/progress/progress_cubit.dart';
import 'package:flashcards/config/router/router.dart';
import 'package:flashcards/domain/models/progress/card_progress.dart';
import 'package:flashcards/ui/dialogs/progress/study_goal_sheet.dart';
import 'package:flashcards/ui/theme/theme_extensions.dart';
import 'package:flashcards/ui/widgets/progress/progress_charts.dart';
import 'package:flashcards/ui/widgets/progress/progress_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class CardsProgressView extends StatelessWidget {
  final CardProgressStats stats;

  const CardsProgressView({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final retention = stats.retention;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GoalSection(stats: stats),
        StatGrid(
          tiles: [
            StatTileData(
              label: 'Studied',
              value: '${stats.studied}',
              caption: 'of ${stats.totalAvailable} cards',
              icon: Icons.style_outlined,
            ),
            StatTileData(
              label: 'Mastered',
              value: '${stats.mastered}',
              caption: 'remembered for 3+ weeks',
              icon: Icons.verified_outlined,
              color: masteredColor(context),
            ),
            StatTileData(
              label: 'Due now',
              value: '${stats.dueNow}',
              caption: stats.dueNow == 0 ? 'all caught up' : 'review today',
              icon: Icons.schedule,
              color: stats.dueNow > 0 ? learningColor(context) : null,
            ),
            StatTileData(
              label: 'Memory',
              value: retention == null ? '–' : '${(retention * 100).round()}%',
              caption: 'chance to recall now',
              icon: Icons.psychology_outlined,
              color: Colors.purple,
            ),
            StatTileData(
              label: 'Streak',
              value: '${stats.streak} ${stats.streak == 1 ? 'day' : 'days'}',
              caption: 'studied in a row',
              icon: Icons.local_fire_department_outlined,
              color: Colors.deepOrange,
            ),
            StatTileData(
              label: 'This week',
              value: '${stats.reviewsThisWeek}',
              caption: 'reviews in 7 days',
              icon: Icons.bar_chart,
              color: Colors.teal,
            ),
          ],
        ),
        const SizedBox(height: 14),
        ProgressSectionCard(
          title: 'What to study next',
          icon: Icons.lightbulb_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdviceList(advice: stats.advice),
              if (stats.weakTopics.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () =>
                      context.router.push(CustomSessionWrapperRoute()),
                  icon: const Icon(Icons.tune),
                  label: const Text('Examine yourself'),
                ),
            ],
          ),
        ),
        ProgressSectionCard(
          title: 'Card status',
          subtitle: 'Where every card you can study stands',
          icon: Icons.donut_large,
          child: CardStatusDonut(stats: stats),
        ),
        ProgressSectionCard(
          title: 'Daily activity',
          subtitle: 'Reviews in the last 14 days (green = new cards)',
          icon: Icons.calendar_month_outlined,
          child: stats.activity.every((d) => d.reviews == 0)
              ? const _Hint(
                  'Your daily reviews will appear here from today on, as you '
                  'study on this device.',
                )
              : DailyBarChart(
                  values: [for (final d in stats.activity) d.reviews],
                  highlighted: [for (final d in stats.activity) d.newCards],
                ),
        ),
        ProgressSectionCard(
          title: 'Upcoming reviews',
          subtitle: 'Cards coming due in the next 14 days',
          icon: Icons.event_repeat,
          child: stats.studied == 0
              ? const _Hint('Study some cards to see your review schedule.')
              : DailyBarChart(
                  values: stats.forecast,
                  isFuture: true,
                  color: learningColor(context),
                ),
        ),
        if (stats.weakTopics.isNotEmpty)
          ProgressSectionCard(
            title: 'Gaps and weak topics',
            subtitle: 'Topics you forget most or rate hardest',
            icon: Icons.track_changes,
            child: Column(
              children: [
                for (final topic in stats.weakTopics)
                  ProgressBarRow(
                    title: topic.name,
                    trailing: '${(topic.forgetRate * 100).round()}% forgotten',
                    subtitle:
                        '${topic.studied} studied · difficulty '
                        '${topic.averageDifficulty.toStringAsFixed(1)}/10 · '
                        '${topic.mastered} mastered',
                    segments: [(topic.weakness, Colors.deepOrange)],
                  ),
              ],
            ),
          ),
        if (stats.hardestCards.isNotEmpty)
          ProgressSectionCard(
            title: 'Hardest cards',
            subtitle: 'Cards you forgot most often',
            icon: Icons.warning_amber_rounded,
            child: Column(
              children: [
                for (final card in stats.hardestCards)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      card.question.replaceAll(RegExp(r'[{}]'), ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Forgotten ${card.card.lapses}× · difficulty '
                      '${card.card.difficulty.toStringAsFixed(1)}/10',
                    ),
                  ),
              ],
            ),
          ),
        ProgressSectionCard(
          title: 'Packs',
          subtitle: 'Mastered, reviewing and learning per pack',
          icon: Icons.folder_open,
          child: Column(
            children: [
              for (final pack in [
                ...stats.packs,
              ]..sort((a, b) => b.coverage.compareTo(a.coverage)))
                ProgressBarRow(
                  title: pack.name,
                  trailing: '${(pack.coverage * 100).round()}%',
                  subtitle:
                      '${pack.studied}/${pack.total} studied · '
                      '${pack.mastered} mastered'
                      '${pack.due > 0 ? ' · ${pack.due} due' : ''}',
                  segments: pack.total == 0
                      ? []
                      : [
                          (pack.mastered / pack.total, masteredColor(context)),
                          (
                            (pack.studied - pack.mastered - pack.learning) /
                                pack.total,
                            reviewingColor(context),
                          ),
                          (pack.learning / pack.total, learningColor(context)),
                        ],
                ),
            ],
          ),
        ),
        ProgressSectionCard(
          title: 'More',
          icon: Icons.more_horiz,
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_open),
                title: const Text('Started packs'),
                subtitle: const Text('Reset progress for each pack'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.router.push(const StartedPacksRoute()),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.question_answer_outlined),
                title: const Text('Flashcards progress'),
                subtitle: const Text('Browse cards and see each one'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.router.push(const FlashcardsSearcherRoute()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalSection extends StatelessWidget {
  final CardProgressStats stats;

  const _GoalSection({required this.stats});

  Future<void> _editGoal(BuildContext context) async {
    final cubit = context.read<ProgressCubit>();
    final goal = await showStudyGoalSheet(
      context,
      goal: cubit.state.goal,
      totalCards: stats.totalAvailable,
      loadPacks: cubit.packs,
    );
    if (goal != null) cubit.saveGoal(goal);
  }

  @override
  Widget build(BuildContext context) {
    final t = stats.trajectory;
    final (statusText, statusColor, statusIcon) = switch (t.status) {
      TrajectoryStatus.onTrack => (
        'On track',
        Colors.green.shade700,
        Icons.trending_up,
      ),
      TrajectoryStatus.behind => (
        'Behind',
        Colors.deepOrange,
        Icons.trending_down,
      ),
      TrajectoryStatus.reached => (
        'Goal reached',
        Colors.green.shade700,
        Icons.emoji_events_outlined,
      ),
      TrajectoryStatus.notStarted => (
        'Not started',
        context.colors.outline,
        Icons.hourglass_empty,
      ),
      TrajectoryStatus.examPassed => (
        'Exam date passed',
        context.colors.outline,
        Icons.event_busy,
      ),
      TrajectoryStatus.noGoal => (
        'No goal yet',
        context.colors.outline,
        Icons.flag_outlined,
      ),
    };

    final lines = <String>[
      if (t.packNames.isNotEmpty)
        'For: ${t.packNames.take(4).join(', ')}'
            '${t.packNames.length > 4 ? ' +${t.packNames.length - 4} more' : ''}',
      if (t.examDate != null)
        'Exam ${DateFormat('d MMM yyyy').format(t.examDate!)}'
            '${(t.daysLeft ?? 0) > 0 ? ' · ${t.daysLeft} days left' : ''}',
      '${t.studied} of ${t.target} cards studied · ${t.remaining} to go',
      if (t.requiredPerDay != null && t.remaining > 0)
        'Needed: ${t.requiredPerDay} new cards/day',
      if (t.pace > 0)
        'Your pace: ${t.pace.toStringAsFixed(1)} new cards/day'
            '${t.projectedFinish != null && t.remaining > 0 ? ' · done by ${DateFormat('d MMM').format(t.projectedFinish!)}' : ''}',
    ];

    return ProgressSectionCard(
      title: 'Goal & trajectory',
      icon: Icons.flag_outlined,
      trailing: TextButton(
        onPressed: () => _editGoal(context),
        child: Text(t.status == TrajectoryStatus.noGoal ? 'Set goal' : 'Edit'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                avatar: Icon(statusIcon, size: 18, color: statusColor),
                label: Text(statusText),
                labelStyle: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(color: statusColor.withValues(alpha: 0.4)),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              Text(
                '${(t.completion * 100).round()}%',
                style: context.text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line, style: context.text.bodySmall),
            ),
          const SizedBox(height: 12),
          if (t.status == TrajectoryStatus.noGoal)
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _editGoal(context),
                icon: const Icon(Icons.event),
                label: const Text('Set exam date and target'),
              ),
            )
          else
            TrajectoryChart(trajectory: t),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;

  const _Hint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.text.bodySmall?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
